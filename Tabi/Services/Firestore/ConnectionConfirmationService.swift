import Foundation
import FirebaseFirestore

// MARK: - Connection Confirmation Service

// Writes a doc to `connection_confirmations` - the Firebase Cloud Function
// `sendConnectionConfirmation` listens on that collection, composes the SMS
// body (including a confirmCaretakerOptIn link) server-side, and sends it
// via AWS SNS. Mirrors MissedDoseAlertService's fan-out pattern so adding a
// caretaker never depends on the device's own Messages app being available
// (MFMessageComposeViewController never works in the Simulator, and isn't
// guaranteed on every real device either).
class ConnectionConfirmationService {
    static let shared = ConnectionConfirmationService()
    private init() {}

    // Sends the caretaker a one-time opt-in confirmation link, not an
    // immediate "you're subscribed" text - carriers require the recipient
    // to actively confirm, not just have their number entered by the
    // patient. `sharedPersonId` and the signed-in uid let the Cloud
    // Function build a link straight to that Firestore doc.
    func sendConfirmationRequest(sharedPersonId: UUID, phone: String, contactName: String, patientName: String) {
        guard !phone.isEmpty, let uid = AuthenticationManager.shared.uid else { return }
        let confirmation = ConnectionConfirmation(
            uid: uid,
            sharedPersonId: sharedPersonId.uuidString,
            phone: phone,
            contactName: contactName.isEmpty ? "there" : contactName,
            patientName: patientName.isEmpty ? "A Tabi user" : patientName
        )
        if let dict = confirmation.firestoreDict() {
            Firestore.firestore().collection("connection_confirmations").addDocument(data: dict)
        }
    }
}

private struct ConnectionConfirmation: Codable {
    var uid: String
    var sharedPersonId: String
    var phone: String
    var contactName: String
    var patientName: String
}
