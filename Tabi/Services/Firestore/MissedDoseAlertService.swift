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

    // Calls SharedPeopleStore.refresh() (force re-fetch) rather than
    // fetchIfNeeded() - a caretaker's optInStatus can flip server-side, so
    // whatever the cache held from app launch might be stale by the time a
    // dose actually goes missed.
    func sendAlert(for entry: DoseEntry) {
        Task {
            await SharedPeopleStore.shared.refresh()
            let phones = SharedPeopleStore.shared.sharedPeople
                .filter { $0.isEligibleForMissedDoseAlerts }
                .compactMap { $0.phoneNumber }
            guard !phones.isEmpty else { return }

            let alerts = Firestore.firestore().collection("missed_pill_alerts")
            for phone in phones {
                let alert = MissedPillAlert(caretakerPhone: phone, medicationName: entry.medicationName, scheduledDate: entry.scheduledDate)
                guard let dict = alert.firestoreDict() else { continue }
                do {
                    try await alerts.addDocument(data: dict)
                } catch {
                    print("MissedDoseAlertService: failed to write alert for \(phone) - \(error.localizedDescription)")
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
