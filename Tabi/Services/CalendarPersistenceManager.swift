import Foundation

// MARK: - Calendar Persistence Manager

class CalendarPersistenceManager {
    static let shared = CalendarPersistenceManager()
    private let prefix = "tabi.doses."
    private init() {}

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
                    entries.append(DoseEntry(medicationId: schedule.medicationId, medicationName: schedule.medicationName, medicationEmoji: schedule.medicationEmoji, dosage: schedule.dosage, scheduledDate: d, status: .upcoming, colorIndex: schedule.colorIndex))
                }
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        persist(entries, id: schedule.medicationId)
    }

    func loadAll(forMedicationId id: UUID) -> [DoseEntry] {
        guard let data = UserDefaults.standard.data(forKey: prefix + id.uuidString),
              let entries = try? JSONDecoder().decode([DoseEntry].self, from: data) else { return [] }
        return entries
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

    private func persist(_ entries: [DoseEntry], id: UUID) {
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: prefix + id.uuidString) }
    }
}
