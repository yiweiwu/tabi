import Foundation

// MARK: - Medication Schedule Parser

class MedicationScheduleParser {
    static func parse(info: DetectedMedicationInfo, medication: Medication) -> DoseSchedule {
        schedule(for: medication, dosage: info.dosage)
    }

    // Builds a DoseSchedule from a medication's own dose times, so an edited
    // schedule (via EditMedicationView) and a freshly-added one go through
    // the same path and stay in sync with `medication.doseTimeMinutes`.
    static func schedule(for medication: Medication, dosage: String) -> DoseSchedule {
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return DoseSchedule(
            medicationId: medication.id, medicationName: medication.name,
            medicationEmoji: medication.emoji, dosage: dosage,
            colorIndex: medication.colorIndex, scheduledTimes: times(for: medication.resolvedDoseTimeMinutes),
            startDate: Date(), endDate: endDate
        )
    }

    // Default time-of-day (minutes since midnight) for each dose in a given
    // daily frequency - the starting point offered when a medication is
    // first added, and the fallback for medications saved before per-dose
    // custom times existed.
    static func defaultDoseTimeMinutes(for frequency: Int) -> [Int] {
        switch frequency {
        case 2: return [8 * 60, 20 * 60]
        case 3: return [8 * 60, 14 * 60, 20 * 60]
        case 4: return [8 * 60, 12 * 60, 16 * 60, 20 * 60]
        default: return [9 * 60]
        }
    }

    static func scheduledTimes(for frequency: Int) -> [Date] {
        times(for: defaultDoseTimeMinutes(for: frequency))
    }

    // Converts minutes-since-midnight into actual `Date`s on the given day
    // (today by default).
    static func times(for minutes: [Int], on day: Date = Date()) -> [Date] {
        let cal = Calendar.current
        return minutes.map { cal.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: day) ?? day }
    }
}
