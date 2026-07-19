import Foundation
import FirebaseFirestore

// MARK: - Connection Confirmation Service

// Writes a doc to `connection_confirmations` - the Firebase Cloud Function
// `sendConnectionConfirmation` listens on that collection and sends the SMS
// via AWS SNS. Mirrors MissedDoseAlertService's fan-out pattern so adding a
// caretaker never depends on the device's own Messages app being available
// (MFMessageComposeViewController never works in the Simulator, and isn't
// guaranteed on every real device either).
class ConnectionConfirmationService {
    static let shared = ConnectionConfirmationService()
    private init() {}

    // `message` should NOT include STOP/HELP compliance language - the
    // Cloud Function's sendSms() appends that to every outbound SMS
    // regardless of caller, so it can't be dropped here by accident.
    func sendConfirmation(phone: String, message: String) {
        guard !phone.isEmpty else { return }
        let confirmation = ConnectionConfirmation(phone: phone, message: message)
        if let dict = confirmation.firestoreDict() {
            Firestore.firestore().collection("connection_confirmations").addDocument(data: dict)
        }
    }
}

private struct ConnectionConfirmation: Codable {
    var phone: String
    var message: String
}
