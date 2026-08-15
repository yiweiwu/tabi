import SwiftUI

// MARK: - Dose Calendar Models

enum DoseStatus: Codable, Equatable {
    case upcoming, taken(Date), skipped(Date), missed

    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .taken:    return "Taken"
        case .skipped:  return "Skipped"
        case .missed:   return "Missed"
        }
    }
    var color: Color {
        switch self {
        case .upcoming: return .tabiBlue
        case .taken:    return .tabiGreen
        case .skipped:  return .tabiAmber
        case .missed:   return .tabiRed
        }
    }
    var icon: String {
        switch self {
        case .upcoming: return "circle"
        case .taken:    return "checkmark.circle.fill"
        case .skipped:  return "forward.circle.fill"
        case .missed:   return "xmark.circle.fill"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, date }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .upcoming:       try c.encode("upcoming", forKey: .type)
        case .taken(let d):   try c.encode("taken",    forKey: .type); try c.encode(d, forKey: .date)
        case .skipped(let d): try c.encode("skipped",  forKey: .type); try c.encode(d, forKey: .date)
        case .missed:         try c.encode("missed",   forKey: .type)
        }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "taken":   self = .taken(try c.decode(Date.self, forKey: .date))
        case "skipped": self = .skipped(try c.decode(Date.self, forKey: .date))
        case "missed":  self = .missed
        default:        self = .upcoming
        }
    }
}

struct DoseEntry: Identifiable, Codable {
    var id = UUID()
    var medicationId: UUID
    var medicationName: String
    var dosage: String
    var scheduledDate: Date
    var status: DoseStatus

    var isActionable: Bool { if case .upcoming = status { return true }; return false }
}

extension Array where Element == DoseEntry {
    // Flips overdue `.upcoming` entries to `.missed`. Only entries still
    // `.upcoming` at the time of the check are eligible, so calling this
    // again on an already-updated array returns an empty `newlyMissed` -
    // that's what keeps missed-dose alerts from firing more than once
    // per entry.
    func applyingMissedStatus(now: Date = Date()) -> (updated: [DoseEntry], newlyMissed: [DoseEntry]) {
        var updated = self
        var newlyMissed: [DoseEntry] = []
        for i in updated.indices {
            if case .upcoming = updated[i].status, updated[i].scheduledDate < now {
                updated[i].status = .missed
                newlyMissed.append(updated[i])
            }
        }
        return (updated, newlyMissed)
    }
}

struct DoseSchedule {
    let medicationId: UUID
    let medicationName: String
    let medicationEmoji: String
    let dosage: String
    let colorIndex: Int
    let scheduledTimes: [Date]
    let startDate: Date
    let endDate: Date

    // Times that already passed on the add day are seeded as `.skipped`
    // (not `.taken` - the user never actually took them, only the
    // scheduled time predates when the medication was added) and not left
    // `.upcoming` either, since the missed-dose check would otherwise flip
    // them to `.missed` and fire a caretaker alert for a dose that predates
    // when the medication was even added.
    func buildEntries() -> [DoseEntry] {
        let cal = Calendar.current
        let addDay = cal.startOfDay(for: startDate)
        var current = addDay
        let end = cal.startOfDay(for: endDate)
        var entries: [DoseEntry] = []
        while current <= end {
            for t in scheduledTimes {
                let c = cal.dateComponents([.hour, .minute], from: t)
                guard let d = cal.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: current) else { continue }
                let alreadyPassedOnAddDay = current == addDay && d < startDate
                let status: DoseStatus = alreadyPassedOnAddDay ? .skipped(startDate) : .upcoming
                entries.append(DoseEntry(medicationId: medicationId, medicationName: medicationName, dosage: dosage, scheduledDate: d, status: status))
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return entries
    }
}

// MARK: - Detected Medication Info (from camera scan)

struct DetectedMedicationInfo {
    var brandName: String
    var genericName: String
    var schedule: String
    var dosage: String
    var frequencyPerDay: Int
    var allDetectedText: [String]
}
