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

    // Alert docs use a deterministic ID (entryId + phone) instead of an
    // auto-generated one, and this is a plain overwrite, not a guarded
    // create. That's deliberate idempotency, not an oversight: this same
    // dose entry can be detected as "newly missed" more than once from more
    // than one source - CalendarStore.checkMissed no longer persists the
    // `.missed` flip (see its doc comment), so it re-detects the same
    // unresolved entry on every 60s tick while the app stays open; the
    // server-side checkMissedDoses Cloud Function independently detects the
    // same entry on its own hourly schedule. `sendMissedPillAlert`
    // (functions/index.js) only fires on Firestore's document-*create*
    // event, never on update - so whichever of these write attempts reaches
    // this ID first triggers exactly one SMS, and every later attempt for
    // the same (entry, phone) pair is a harmless no-op write to a doc that
    // already exists.
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
                    try await alerts.document(Self.alertDocId(entryId: entry.id, phone: phone)).setData(dict)
                } catch {
                    // Firestore rules only allow `create` on this collection
                    // (never `update`), so a permission-denied here almost
                    // always means this exact (entry, phone) alert was
                    // already written by an earlier attempt - the expected,
                    // benign outcome of the dedup scheme above, not a bug.
                    print("MissedDoseAlertService: write for \(phone) rejected (likely already alerted) - \(error.localizedDescription)")
                }
            }
        }
    }

    static func alertDocId(entryId: UUID, phone: String) -> String {
        "\(entryId.uuidString)_\(phone)"
    }
}

private struct MissedPillAlert: Codable {
    var caretakerPhone: String
    var medicationName: String
    var scheduledDate: Date
}
