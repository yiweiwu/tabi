import Foundation

// MARK: - Medication Schedule Parser

class MedicationScheduleParser {
    static func parse(info: DetectedMedicationInfo, medication: Medication) -> DoseSchedule {
        let schedule = info.schedule.lowercased()
        let count = detectFrequency(from: schedule)
        let times = generateTimes(count: count, hint: schedule, baseTime: info.scheduleTime)
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return DoseSchedule(
            medicationId: medication.id, medicationName: medication.name,
            medicationEmoji: medication.emoji, dosage: info.dosage,
            colorIndex: medication.colorIndex, scheduledTimes: times,
            startDate: Date(), endDate: endDate
        )
    }
    private static func detectFrequency(from text: String) -> Int {
        if text.contains("four") || text.contains("qid") || text.contains("every 6") { return 4 }
        if text.contains("three") || text.contains("tid") || text.contains("every 8") { return 3 }
        if text.contains("twice") || text.contains("bid") || text.contains("every 12") { return 2 }
        return 1
    }
    private static func generateTimes(count: Int, hint: String, baseTime: Date) -> [Date] {
        func t(_ h: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date() }
        switch count {
        case 2: return [t(8), t(20)]
        case 3: return [t(8), t(14), t(20)]
        case 4: return [t(8), t(12), t(16), t(20)]
        default:
            if hint.contains("evening") || hint.contains("night") { return [t(20)] }
            return [t(9)]
        }
    }
}
