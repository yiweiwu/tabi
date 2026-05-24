import Foundation

// MARK: - Medication Schedule Parser

class MedicationScheduleParser {
    static func parse(info: DetectedMedicationInfo, medication: Medication) -> DoseSchedule {
        let times = scheduledTimes(for: info.frequencyPerDay)
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return DoseSchedule(
            medicationId: medication.id, medicationName: medication.name,
            medicationEmoji: medication.emoji, dosage: info.dosage,
            colorIndex: medication.colorIndex, scheduledTimes: times,
            startDate: Date(), endDate: endDate
        )
    }

    private static func scheduledTimes(for frequency: Int) -> [Date] {
        func t(_ h: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date() }
        switch frequency {
        case 2: return [t(8), t(20)]
        case 3: return [t(8), t(14), t(20)]
        case 4: return [t(8), t(12), t(16), t(20)]
        default: return [t(9)]
        }
    }
}
