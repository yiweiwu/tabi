const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const {SNSClient, PublishCommand} = require("@aws-sdk/client-sns");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

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
