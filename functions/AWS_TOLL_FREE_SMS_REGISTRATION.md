# AWS Toll-Free SMS Registration — Compliant Opt-In Guidelines

Reference notes from AWS End User Messaging's guidance on toll-free registration opt-in forms. Kept here because `sendSms()` in `index.js` is the pipeline this registration governs.

## What makes an opt-in flow compliant

- Phone number field is optional (not required to submit the form)
- SMS consent is a separate, unchecked checkbox
- Consent text identifies the brand and says "promotional/marketing SMS"
- Frequency disclosed ("Message frequency varies")
- Data rates disclosed ("Message and data rates may apply")
- Opt-out instructions ("Reply STOP to opt-out")
- Help instructions ("Reply HELP for help")
- "Consent is not a condition of purchase" disclosed (marketing)
- Terms and Privacy Policy are a separate checkbox

## Common mistakes that cause denial

- Pre-checking the SMS consent checkbox
- Making the phone number a required field
- Bundling SMS consent into the Terms of Service checkbox
- Missing frequency or data rates disclosure in consent text
- Not identifying the brand name in the consent language

## Note on applicability to Tabi

This guidance describes AWS's default suggested workflow: a **marketing** website signup form with a self-service checkbox. Tabi's actual registered use case is **Health Care Messaging** with a **Digital Form** opt-in, and the flow is structurally different:

- There is no website signup form or checkbox — consent is captured through the app and a texted confirmation link.
- The patient (not the caregiver) enters the caregiver's phone number, inside the iOS app.
- The caregiver — the person actually consenting — confirms via a one-time SMS containing a link to a hosted confirmation page (`confirmCaretakerOptIn` in `index.js`). Opening that link is the affirmative action; only then does `optInStatus` become `confirmed` (enforced server-side in `firestore.rules`, not just client-side).
- Messages are transactional missed-dose alerts, not marketing — so "promotional/marketing SMS" and "consent is not a condition of purchase" language don't apply as written.

If AWS's registration review pushes back citing this checklist, the relevant answer is that Tabi's flow is a double opt-in via SMS-link confirmation, not a marketing checkbox form — see the actual submitted "Opt-in workflow description" for the registration record.

## Registered sender identity

The registration's Company Info is filed as an individual sole proprietor, **Yi-Wei Wu** — there's no LLC or DBA for "Tabi" yet. AWS's registration review requires message samples to identify that registrant, not just the app name, so the resubmitted `messageSample2` reads:

> Hi [name], it's Tabi from Yi-Wei Wu. [patient] added you to get a text if they miss a dose. Confirm here: [link] Reply STOP to unsubscribe, HELP for help.

**Follow-ups (not yet done):**
- Update the live message in `index.js`'s `sendConnectionConfirmation` to say "it's Tabi from Yi-Wei Wu" to match the registered sample — right now it just says "it's Tabi." Registered samples and live traffic need to match; carriers check this post-approval, not just at submission time.
- Longer-term, if Tabi files a DBA, the Company Info field can be updated to "Tabi" directly and "from Yi-Wei Wu" can be dropped from messages.
