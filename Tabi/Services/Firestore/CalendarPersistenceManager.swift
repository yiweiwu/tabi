import Foundation
import FirebaseFirestore

// MARK: - Calendar Persistence Manager

class CalendarPersistenceManager {
    static let shared = CalendarPersistenceManager()
    private let db = Firestore.firestore()
    private var cache: [UUID: [DoseEntry]] = [:]
    private var listeners: [UUID: ListenerRegistration] = [:]
    private init() {}

    // Requires a signed-in user - no anonymous/device-ID fallback, since that
    // would reintroduce unscoped access to another installation's data.
    private func docRef(for id: UUID) -> DocumentReference? {
        guard let userId = AuthenticationManager.shared.uid else { return nil }
        return db.collection("users").document(userId).collection("doses").document(id.uuidString)
    }

    func save(schedule: DoseSchedule) {
        var entries = loadAll(forMedicationId: schedule.medicationId)
        entries.removeAll { if case .upcoming = $0.status { return true }; return false }
        entries.append(contentsOf: schedule.buildEntries())
        persist(entries, id: schedule.medicationId)
        startListening(for: schedule.medicationId)
    }

    func loadAll(forMedicationId id: UUID) -> [DoseEntry] {
        cache[id] ?? []
    }

    func loadEntries(forMonth date: Date, medications: [Medication]) -> [DoseEntry] {
        let cal = Calendar.current
        return medications.flatMap { med in loadAll(forMedicationId: med.id).filter { cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .month) } }
    }

    func loadEntries(forDay date: Date, medications: [Medication]) -> [DoseEntry] {
        let cal = Calendar.current
        return medications.flatMap { med in loadAll(forMedicationId: med.id).filter { cal.isDate($0.scheduledDate, inSameDayAs: date) } }.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    func updateStatus(entryId: UUID, medicationId: UUID, status: DoseStatus) {
        var entries = loadAll(forMedicationId: medicationId)
        if let i = entries.firstIndex(where: { $0.id == entryId }) { entries[i].status = status; persist(entries, id: medicationId) }
    }

    func markMissedIfOverdue(medications: [Medication]) {
        for med in medications { checkMissed(for: med.id) }
    }

    // Flips overdue `.upcoming` entries to `.missed` and fires a caretaker
    // alert for each one newly missed. See `applyingMissedStatus` for why a
    // re-run (e.g. the listener re-firing after `persist` below) won't
    // re-alert for a dose already marked missed.
    private func checkMissed(for id: UUID) {
        let (updated, newlyMissed) = loadAll(forMedicationId: id).applyingMissedStatus()
        if !newlyMissed.isEmpty { persist(updated, id: id) }
        for entry in newlyMissed { MissedDoseAlertService.shared.sendAlert(for: entry) }
    }

    // MARK: - Missed Dose Monitoring

    private var missedCheckTimer: Timer?
    private var medicationsProvider: (() -> [Medication])?

    // Starts listening for every medication (so a cold launch picks up doses
    // that went overdue while the app was closed) and re-scans every minute
    // to catch doses that go overdue while the app sits open with no other
    // Firestore writes to trigger the snapshot listener.
    func startMonitoring(medicationsProvider: @escaping () -> [Medication]) {
        self.medicationsProvider = medicationsProvider
        for med in medicationsProvider() { startListening(for: med.id) }
        missedCheckTimer?.invalidate()
        missedCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, let meds = self.medicationsProvider?() else { return }
            self.markMissedIfOverdue(medications: meds)
        }
    }

    func startListening(for id: UUID) {
        guard listeners[id] == nil, let ref = docRef(for: id) else { return }
        listeners[id] = ref.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data(),
                  let entries = Self.decodeEntries(data) else { return }
            self.cache[id] = entries
            self.checkMissed(for: id)
        }
    }

    private func persist(_ entries: [DoseEntry], id: UUID) {
        cache[id] = entries
        guard let dict = Self.encodeEntries(entries), let ref = docRef(for: id) else { return }
        ref.setData(dict)
    }

    private static func encodeEntries(_ entries: [DoseEntry]) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(entries),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return ["entries": arr]
    }

    private static func decodeEntries(_ dict: [String: Any]) -> [DoseEntry]? {
        guard let arr = dict["entries"] as? [[String: Any]],
              let data = try? JSONSerialization.data(withJSONObject: arr),
              let entries = try? JSONDecoder().decode([DoseEntry].self, from: data) else { return nil }
        return entries
    }
}
