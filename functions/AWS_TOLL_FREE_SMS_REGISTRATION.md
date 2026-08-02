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
