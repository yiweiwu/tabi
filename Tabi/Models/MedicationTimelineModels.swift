import SwiftUI

// MARK: - Medication Timeline Models

// Backs the Calendar tab's week/month schedule view. Deliberately separate
// from `Medication` (the real, Firestore-backed model) - this feature runs
// on mock data for now per product decision, with `MedicationTimelineProviding`
// as the seam to swap in a real API later without touching the views.

enum Weekday: Int, CaseIterable, Codable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    // Matches Calendar.component(.weekday, from:), which is also 1-indexed from Sunday.
    init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday)
    }

    var letter: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

// Different medications are often filled at different pharmacies (a
// specialty drug vs. a regular chain prescription), so this is attached
// per-medication rather than assumed to be one pharmacy for the whole app.
struct MedicationPharmacy: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var address: String
    var phone: String
}

struct ScheduledMedication: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dose: String
    var timesOfDay: [String]          // e.g. ["AM"], ["AM", "PM"]
    var scheduleDays: Set<Weekday>    // days of the week this medication is taken
    var daysOfSupplyRemaining: Int
    var colorIndex: Int
    var pharmacy: MedicationPharmacy

    var isLowSupply: Bool { daysOfSupplyRemaining <= 7 }

    // "500mg, AM & PM" / "500mg" if no times are set.
    var subtitleText: String {
        guard !timesOfDay.isEmpty else { return dose }
        return "\(dose), \(timesOfDay.joined(separator: " & "))"
    }

    var pillColor: Color { pillColors[colorIndex % pillColors.count] }
}

// MARK: - Dose Dot Status

// Shared by the week grid (per-medication) and the month grid (aggregated
// across every medication for a day) so both use the same taken/missed/
// scheduled rule and the same colors.
enum DoseDotStatus: Equatable {
    case taken, missed, scheduled

    var color: Color {
        switch self {
        case .taken:     return .tabiGreen
        case .missed:    return .tabiRed
        case .scheduled: return .black
        }
    }
}

extension ScheduledMedication {
    // Deterministic mock status for a given day - real taken/missed history
    // doesn't exist yet since this feature isn't backend-connected, so this
    // stands in with a stable (not random-per-render) past outcome. `today`
    // is threaded through rather than read from `Date()` so previews/tests
    // stay deterministic.
    func doseStatus(on day: Date, today: Date) -> DoseDotStatus? {
        let cal = Calendar.current
        guard let weekday = Weekday(calendarWeekday: cal.component(.weekday, from: day)),
              scheduleDays.contains(weekday) else { return nil }

        let dayStart = cal.startOfDay(for: day)
        let todayStart = cal.startOfDay(for: today)
        if dayStart >= todayStart { return .scheduled }

        let dayNumber = cal.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: dayStart).day ?? 0
        let seed = abs(dayNumber &+ id.hashValue)
        return seed % 6 == 0 ? .missed : .taken
    }
}

// Aggregates entries pooled across multiple medications for the month grid,
// where each day cell shows one dot representing every medication at once.
func aggregateDoseStatus(_ statuses: [DoseDotStatus]) -> DoseDotStatus? {
    guard !statuses.isEmpty else { return nil }
    if statuses.contains(where: { $0 == .missed }) { return .missed }
    if statuses.allSatisfy({ $0 == .taken }) { return .taken }
    return .scheduled
}
