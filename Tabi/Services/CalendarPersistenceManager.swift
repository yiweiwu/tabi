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
        let cal = Calendar.current
        var current = cal.startOfDay(for: schedule.startDate)
        let end = cal.startOfDay(for: schedule.endDate)
        while current <= end {
            for t in schedule.scheduledTimes {
                let c = cal.dateComponents([.hour, .minute], from: t)
                if let d = cal.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: current) {
                    entries.append(DoseEntry(medicationId: schedule.medicationId, medicationName: schedule.medicationName, dosage: schedule.dosage, scheduledDate: d, status: .upcoming))
                }
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
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
        let now = Date()
        for med in medications {
            var entries = loadAll(forMedicationId: med.id); var changed = false
            for i in entries.indices { if case .upcoming = entries[i].status, entries[i].scheduledDate < now { entries[i].status = .missed; changed = true } }
            if changed { persist(entries, id: med.id) }
        }
    }

    func startListening(for id: UUID) {
        guard listeners[id] == nil, let ref = docRef(for: id) else { return }
        listeners[id] = ref.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data(),
                  let entries = Self.decodeEntries(data) else { return }
            self.cache[id] = entries
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
