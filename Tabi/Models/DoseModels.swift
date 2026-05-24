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
    var medicationEmoji: String
    var dosage: String
    var scheduledDate: Date
    var status: DoseStatus
    var colorIndex: Int = 0

    var isActionable: Bool { if case .upcoming = status { return true }; return false }
    var pillColor: Color { pillColors[colorIndex % pillColors.count] }
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
}

// MARK: - Detected Medication Info (from camera scan)

struct DetectedMedicationInfo {
    var brandName: String
    var genericName: String
    var schedule: String
    var dosage: String
    var frequencyPerDay: Int
    var scheduleTime: Date
    var allDetectedText: [String]
}
