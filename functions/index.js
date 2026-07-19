const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {SNSClient, PublishCommand} = require("@aws-sdk/client-sns");

const snsClient = new SNSClient({
  region: "us-east-1",
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

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
      await sendSms(data.phone, data.message);
    },
);
