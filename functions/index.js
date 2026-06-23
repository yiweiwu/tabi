const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {SNSClient, PublishCommand} = require("@aws-sdk/client-sns");

const snsClient = new SNSClient({
  region: "us-east-1",
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

exports.sendMissedPillAlert = onDocumentCreated(
    {
      document: "missed_pill_alerts/{alertId}",
      secrets: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"],
    },
    async (event) => {
      const data = event.data.data();
      const caretakerPhone = data.caretakerPhone;

      const params = {
        Message: `Tabi Alert: Patient missed their medication.`,
        PhoneNumber: caretakerPhone,
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
        console.log("SMS sent successfully to", caretakerPhone);
      } catch (err) {
        console.error("Error sending SMS:", err);
      }
    },
);
