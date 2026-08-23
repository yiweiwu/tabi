const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
// v1 namespace: only used for the Auth onCreate trigger below, since v2's
// equivalent (identity blocking functions) requires enabling Google Cloud
// Identity Platform, a separate project-level upgrade this app doesn't use.
const functionsV1 = require("firebase-functions/v1");
const {SNSClient, PublishCommand} = require("@aws-sdk/client-sns");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Firestore stores every Swift `Date` field (scheduledDate, dateAdded, etc.)
// as `timeIntervalSinceReferenceDate` - seconds since 2001-01-01T00:00:00Z,
// NOT the Unix epoch (see firestore.rules' "Assumed Data Model" comment).
// This is the fixed gap between the two epochs, matching Foundation's own
// NSTimeIntervalSince1970 constant - get this wrong and every date is off
// by 31 years, silently.
const SWIFT_REFERENCE_DATE_OFFSET_SECONDS = 978307200;

/**
 * Converts a Firestore-stored Swift reference-date timestamp to a JS Date.
 * @param {number} referenceSeconds - Seconds since 2001-01-01T00:00:00Z.
 * @return {Date} The equivalent JS Date.
 */
function fromSwiftReferenceDate(referenceSeconds) {
  const unixSeconds = referenceSeconds + SWIFT_REFERENCE_DATE_OFFSET_SECONDS;
  return new Date(unixSeconds * 1000);
}

const snsClient = new SNSClient({
  region: "us-east-1",
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

const CONFIRM_REGION = "us-central1";
const CONFIRM_BASE_URL =
  `https://${CONFIRM_REGION}-tabi-47030.cloudfunctions.net/confirmCaretakerOptIn`;

// Required on every outbound SMS by AWS toll-free/10DLC carrier registration
// (see the account's SNS phone number registration for the matching sample
// messages on file). Appended here - the one function that actually calls
// SNS - so no caller can ship a message that's missing it.
const SMS_COMPLIANCE_FOOTER = " Reply STOP to unsubscribe, HELP for help.";

/**
 * Publishes a transactional SMS to a phone number via AWS SNS. The
 * SMS_COMPLIANCE_FOOTER is appended automatically; callers should not
 * include their own STOP/HELP language.
 * @param {string} phoneNumber - E.164 destination phone number.
 * @param {string} message - SMS body text, without a compliance footer.
 */
async function sendSms(phoneNumber, message) {
  const params = {
    Message: message + SMS_COMPLIANCE_FOOTER,
    PhoneNumber: phoneNumber,
    MessageAttributes: {
      "AWS.SNS.SMS.SMSType": {
        DataType: "String",
        StringValue: "Transactional",
      },
    },
  };

  try {
    const command = new PublishCommand(params);
    await snsClient.send(command);
    console.log("SMS sent successfully to", phoneNumber);
  } catch (err) {
    console.error("Error sending SMS:", err);
  }
}

// Stamps a custom claim on every newly-created email/password account so
// firestore.rules can require email verification before that account's
// first write, without being able to tell "new account" from "existing
// account" any other way (Firebase ID tokens don't expose account creation
// time). Apple/Google sign-ins are skipped - Firebase already reports those
// as emailVerified. Accounts created before this function was deployed
// never receive the claim, which is what grandfathers them in: the rules
// treat a missing claim as "verification not required".
//
// Client must force a token refresh (getIDTokenResult(forcingRefresh: true))
// after this runs for the claim to reach the ID token - see
// AuthenticationManager.reloadAndCheckEmailVerified().
exports.onUserCreate = functionsV1.auth.user().onCreate(async (user) => {
  const isPasswordAccount = user.providerData.some(
      (p) => p.providerId === "password",
  );
  if (!isPasswordAccount) {
    return;
  }
  await admin.auth().setCustomUserClaims(user.uid, {
    emailVerificationRequired: true,
  });
});

exports.sendMissedPillAlert = onDocumentCreated(
    {
      document: "missed_pill_alerts/{alertId}",
      secrets: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"],
    },
    async (event) => {
      const data = event.data.data();
      const message = "Tabi Alert: Patient missed their medication.";
      await sendSms(data.caretakerPhone, message);
    },
);

/**
 * Re-reads one doses doc inside a transaction and flips any entry that's
 * still `.upcoming` and overdue to `.missed`. Re-reading inside the
 * transaction (rather than trusting the outer collectionGroup snapshot
 * checkMissedDoses started from) is what prevents this from clobbering a
 * concurrent client write - a `.taken`/`.skipped` tap landing between the
 * outer scan and this running - since Firestore aborts and retries the
 * transaction if the document changed underneath it. `entries` written by
 * user action (`.taken`/`.skipped`, via MedicationStore.swift) is the only
 * other writer of this field; `.missed` is written exclusively here.
 * @param {FirebaseFirestore.DocumentReference} docRef - The doses doc.
 * @param {Date} now - The current time to compare scheduledDate against.
 * @return {Promise<Array|null>} The newly-missed entries, or null if
 *   nothing needed to change.
 */
async function flipOverdueEntries(docRef, now) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const entries = snap.exists ? snap.data().entries : undefined;
    if (!Array.isArray(entries)) return null;

    const newlyMissed = [];
    const updatedEntries = entries.map((entry) => {
      const isOverdueUpcoming = entry && entry.status &&
        entry.status.type === "upcoming" &&
        typeof entry.scheduledDate === "number" &&
        fromSwiftReferenceDate(entry.scheduledDate) < now;
      if (!isOverdueUpcoming) return entry;
      newlyMissed.push(entry);
      return {...entry, status: {type: "missed"}};
    });

    if (newlyMissed.length === 0) return null;
    tx.update(docRef, {entries: updatedEntries});
    return newlyMissed;
  });
}

/**
 * Writes a missed_pill_alerts doc per (entry, eligible caretaker) pair for
 * one user, using the same deterministic ID scheme as the client's
 * MissedDoseAlertService.alertDocId (Tabi/Services/Firestore/
 * MissedDoseAlertService.swift) - `${entry.id}_${phone}` - so whichever
 * side (this scheduled function, or the client's own fast-path detection)
 * gets there first is the one that actually triggers an SMS. The other's
 * write lands on a doc that already exists - sendMissedPillAlert only
 * fires on document *create*, never update - so it's a harmless no-op, not
 * a duplicate text.
 * @param {string} uid - The owning user's uid.
 * @param {Array} newlyMissed - Entries newly flipped to missed.
 * @return {Promise<number>} How many alert docs were written.
 */
async function alertCaretakers(uid, newlyMissed) {
  const sharedPeopleSnap = await db.collection("users").doc(uid)
      .collection("sharedPeople")
      .where("optInStatus", "==", "confirmed")
      .get();
  // Mirrors SharedPerson.isEligibleForMissedDoseAlerts - confirmed opt-in
  // alone isn't enough, a caretaker needs a phone on file too.
  const phones = sharedPeopleSnap.docs
      .map((d) => d.data().phoneNumber)
      .filter((phone) => typeof phone === "string" && phone.length > 0);
  if (phones.length === 0) return 0;

  let count = 0;
  for (const entry of newlyMissed) {
    for (const phone of phones) {
      const alertId = `${entry.id}_${phone}`;
      await db.collection("missed_pill_alerts").doc(alertId).set({
        caretakerPhone: phone,
        medicationName: entry.medicationName,
        scheduledDate: entry.scheduledDate,
      });
      count++;
    }
  }
  return count;
}

// Server-side backstop for CalendarStore.checkMissed()
// (Tabi/Services/Firestore/CalendarStore.swift) - that client-side check
// only runs while the app process is alive (a 60s Timer, or a live
// Firestore listener callback), so a patient who doesn't open the app for
// days never gets their overdue doses flipped to missed, and their
// caretaker never gets alerted. This scans every user's dose entries
// independently of whether any client is open, and writes the same
// missed_pill_alerts docs the client writes, so sendMissedPillAlert above
// fires unchanged for either source. `.missed` is written exclusively by
// this function - the client detects and alerts on overdue doses too (the
// fast path while the app is open) but never persists the flip, to avoid a
// lost-update race against this function - see checkMissed's doc comment.
//
// Runs at :10 past every hour - medication schedule times are only ever
// set on the hour (see MedicationScheduleParser.defaultDoseTimeMinutes),
// so a 10-minute buffer after the hour is enough to catch every dose
// without running more often than needed.
exports.checkMissedDoses = onSchedule(
    {schedule: "10 * * * *", timeZone: "UTC"},
    async () => {
      const now = new Date();
      const snapshot = await db.collectionGroup("doses").get();

      let flippedCount = 0;
      let alertCount = 0;

      // Each doc is handled independently and wrapped in its own try/catch
      // - one malformed doc, or one transaction that exhausts its retries
      // under contention, must not abort the entire hourly run and skip
      // every other user for this cycle.
      for (const doc of snapshot.docs) {
        try {
          const newlyMissed = await flipOverdueEntries(doc.ref, now);
          if (!newlyMissed || newlyMissed.length === 0) continue;
          flippedCount += newlyMissed.length;

          // doc.ref is users/{uid}/doses/{medicationId}; .parent is the
          // doses collection, .parent.id is the owning user's uid.
          const uid = doc.ref.parent.parent.id;
          alertCount += await alertCaretakers(uid, newlyMissed);
        } catch (err) {
          console.error(`checkMissedDoses: failed on ${doc.ref.path}`, err);
        }
      }

      console.log(
          `checkMissedDoses: flipped ${flippedCount} entries to missed, ` +
          `wrote ${alertCount} alert(s)`,
      );
    },
);

exports.sendConnectionConfirmation = onDocumentCreated(
    {
      document: "connection_confirmations/{confirmationId}",
      secrets: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"],
    },
    async (event) => {
      const data = event.data.data();
      const confirmUrl = `${CONFIRM_BASE_URL}` +
        `?uid=${encodeURIComponent(data.uid)}` +
        `&id=${encodeURIComponent(data.sharedPersonId)}`;
      const message = `Hi ${data.contactName}, it's Tabi from Yi-Wei Wu. ` +
        `${data.patientName} added you to get a text if they miss a dose. ` +
        `Confirm here: ${confirmUrl}`;
      await sendSms(data.phone, message);
    },
);

/**
 * Renders a minimal confirmation-flow landing page.
 * @param {string} title - Page heading.
 * @param {string} message - Body text below the heading.
 * @return {string} A complete HTML document.
 */
function htmlPage(title, message) {
  return `<!DOCTYPE html><html><head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title></head>
    <body style="font-family:-apple-system,sans-serif;text-align:center;` +
    `padding:48px 24px;">
    <h1>${title}</h1><p>${message}</p></body></html>`;
}

// Landing page for the link sent by sendConnectionConfirmation. This is the
// only place a caretaker's optInStatus can become "confirmed" - the Admin
// SDK write here bypasses firestore.rules, which is what makes it the sole
// path a client can never forge (see isValidOptInStatus() in
// firestore.rules).
exports.confirmCaretakerOptIn = onRequest(
    {region: CONFIRM_REGION},
    async (req, res) => {
      const {uid, id} = req.query;
      res.set("Content-Type", "text/html");

      if (typeof uid !== "string" || typeof id !== "string" || !uid || !id) {
        res.status(400).send(htmlPage("Invalid Link",
            "This confirmation link is missing required information."));
        return;
      }

      const docRef = db.collection("users").doc(uid)
          .collection("sharedPeople").doc(id);
      try {
        const snap = await docRef.get();
        if (!snap.exists) {
          res.status(404).send(htmlPage("Link Not Found",
              "This confirmation link is no longer valid."));
          return;
        }
        if (snap.data().optInStatus === "confirmed") {
          res.status(200).send(htmlPage("Already Confirmed",
              "You're already set up to receive Tabi alerts " +
              "for this patient."));
          return;
        }
        await docRef.update({optInStatus: "confirmed"});
        res.status(200).send(htmlPage("You're Confirmed",
            "You'll now receive a text if this patient misses a dose. " +
            "Reply STOP at any time to unsubscribe."));
      } catch (err) {
        console.error("confirmCaretakerOptIn failed", err);
        res.status(500).send(htmlPage("Something Went Wrong",
            "Please try again later."));
      }
    },
);
