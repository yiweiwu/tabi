import Foundation
import FirebaseFirestore

// MARK: - Missed Dose Alert Service

// Writes one document per caretaker to `missed_pill_alerts` - the Firebase
// Cloud Function `sendMissedPillAlert` listens on that collection and sends
// the SMS via AWS SNS. Keeping the alert doc separate from `sharedPeople`
// lets the function fan out per-phone-number without the client needing to
// know anything about SNS/Secret Manager.
class MissedDoseAlertService {
    static let shared = MissedDoseAlertService()
    private init() {}

    func sendAlert(for entry: DoseEntry) {
        guard let userId = AuthenticationManager.shared.uid else { return }
        Firestore.firestore().collection("users").document(userId).collection("sharedPeople")
            .getDocuments { snapshot, _ in
                let phones = (snapshot?.documents ?? [])
                    .compactMap { SharedPerson.decoded(from: $0.data()) }
                    .filter { $0.isEligibleForMissedDoseAlerts }
                    .compactMap { $0.phoneNumber }
                guard !phones.isEmpty else { return }

                let alerts = Firestore.firestore().collection("missed_pill_alerts")
                for phone in phones {
                    let alert = MissedPillAlert(caretakerPhone: phone, medicationName: entry.medicationName, scheduledDate: entry.scheduledDate)
                    if let dict = alert.firestoreDict() {
                        alerts.addDocument(data: dict)
                    }
                }
            }
    }
}

private struct MissedPillAlert: Codable {
    var caretakerPhone: String
    var medicationName: String
    var scheduledDate: Date
}
