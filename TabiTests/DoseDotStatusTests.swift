import Testing
import Foundation
@testable import Tabi

// MARK: - Dose Dot Status Tests

// Covers the pure logic behind the Calendar tab's week/month dots -
// aggregateDoseStatus, doseDotStatus, and DoseStatus.dotStatus - now that
// they read real DoseEntry data (CalendarStore) instead of the deleted
// ScheduledMedication mock. See .claude/rules/dose-tracking.md.
//
// Deliberately only two dot outcomes (taken/missed) - future/not-yet-
// resolved doses (.upcoming) and pre-add seeded doses (.skipped) are
// excluded from the aggregate entirely rather than shown as a third
// "scheduled" state, since the Calendar only reports on what's already
// resolved.
@Suite
struct DoseDotStatusTests {

    private func entry(medicationId: UUID, scheduledDate: Date, status: DoseStatus) -> DoseEntry {
        DoseEntry(medicationId: medicationId, medicationName: "Lisinopril", dosage: "10mg", scheduledDate: scheduledDate, status: status)
    }

    @Test("DoseStatus.dotStatus: only taken/missed resolve to a dot, upcoming/skipped are excluded")
    func testDotStatusMapping() throws {
        #expect(DoseStatus.taken(Date()).dotStatus == .taken)
        #expect(DoseStatus.missed.dotStatus == .missed)
        #expect(DoseStatus.upcoming.dotStatus == nil)
        #expect(DoseStatus.skipped(Date()).dotStatus == nil)
    }

    @Test("aggregateDoseStatus: any missed status wins over taken")
    func testAggregateMissedWins() throws {
        #expect(aggregateDoseStatus([.taken, .missed]) == .missed)
    }

    @Test("aggregateDoseStatus: taken when nothing is missed")
    func testAggregateAllTaken() throws {
        #expect(aggregateDoseStatus([.taken, .taken]) == .taken)
    }

    @Test("aggregateDoseStatus: empty input has no dot")
    func testAggregateEmptyIsNil() throws {
        #expect(aggregateDoseStatus([]) == nil)
    }

    @Test("doseDotStatus: a day with no entries for the medication has no dot")
    func testNoDotWhenNoEntriesThatDay() throws {
        let medId = UUID()
        let entries = [entry(medicationId: medId, scheduledDate: Date().addingTimeInterval(-86400), status: .taken(Date()))]
        let byMed = [medId: entries]

        #expect(doseDotStatus(for: medId, on: Date(), entriesByMedicationId: byMed) == nil)
    }

    @Test("doseDotStatus: a day where every entry is still upcoming has no dot")
    func testNoDotWhenEverythingStillUpcoming() throws {
        let medId = UUID()
        let day = Date()
        let byMed = [medId: [entry(medicationId: medId, scheduledDate: day, status: .upcoming)]]

        #expect(doseDotStatus(for: medId, on: day, entriesByMedicationId: byMed) == nil)
    }

    @Test("doseDotStatus: a day where every entry was pre-add skipped has no dot")
    func testNoDotWhenEverythingSkipped() throws {
        let medId = UUID()
        let day = Date()
        let byMed = [medId: [entry(medicationId: medId, scheduledDate: day, status: .skipped(day))]]

        #expect(doseDotStatus(for: medId, on: day, entriesByMedicationId: byMed) == nil)
    }

    @Test("doseDotStatus: aggregates multiple same-day entries for one medication (AM + PM)")
    func testAggregatesMultipleEntriesSameDay() throws {
        let medId = UUID()
        let day = Date()
        let am = entry(medicationId: medId, scheduledDate: day, status: .taken(day))
        let pm = entry(medicationId: medId, scheduledDate: day, status: .missed)
        let byMed = [medId: [am, pm]]

        #expect(doseDotStatus(for: medId, on: day, entriesByMedicationId: byMed) == .missed)
    }

    @Test("doseDotStatus: a resolved dose still counts even alongside an unresolved one the same day")
    func testResolvedDoseCountsAlongsideUpcoming() throws {
        let medId = UUID()
        let day = Date()
        let takenEarlier = entry(medicationId: medId, scheduledDate: day, status: .taken(day))
        let laterTonight = entry(medicationId: medId, scheduledDate: day, status: .upcoming)
        let byMed = [medId: [takenEarlier, laterTonight]]

        #expect(doseDotStatus(for: medId, on: day, entriesByMedicationId: byMed) == .taken)
    }

    @Test("doseDotStatus: a medication with no entries key at all has no dot")
    func testNoDotWhenMedicationUnknown() throws {
        #expect(doseDotStatus(for: UUID(), on: Date(), entriesByMedicationId: [:]) == nil)
    }
}

// MARK: - Weekly Adherence Scenario Tests

// End-to-end coverage for the scenario a real medication produces: a 3x/day
// prescription tracked for a full week should yield exactly one dot per day
// (7 total, matching frequencyPerDay entries per day), each correctly
// reflecting that day's mix of taken/missed doses. "Some missed" and "all
// missed" both read as the same .missed dot by design - the Calendar dot
// only distinguishes taken-everything vs missed-something, not degrees of
// missing (see DoseDotStatusTests above and .claude/rules/dose-tracking.md).
@Suite
struct WeeklyAdherenceScenarioTests {

    private let medId = UUID()
    private let doseHours = [8, 14, 20]

    private func entry(on day: Date, hour: Int, status: DoseStatus) -> DoseEntry {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return DoseEntry(medicationId: medId, medicationName: "Amoxicillin", dosage: "500mg", scheduledDate: date, status: status)
    }

    @Test("A week of a 3x/day medication produces exactly 7 days with a dot, each aggregated correctly")
    func testSevenDaysEachCorrectlyAggregated() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = (0..<7).map { cal.date(byAdding: .day, value: -$0, to: today)! }

        // One outcome per day, cycling through all three real-world cases
        // twice+ across the week: all taken, some missed, all missed.
        let dailyStatuses: [[DoseStatus]] = [
            [.taken(days[0]), .taken(days[0]), .taken(days[0])],  // all taken
            [.taken(days[1]), .missed, .taken(days[1])],          // some missed
            [.missed, .missed, .missed],                          // all missed
            [.taken(days[3]), .taken(days[3]), .taken(days[3])],  // all taken
            [.missed, .taken(days[4]), .missed],                  // some missed
            [.missed, .missed, .missed],                          // all missed
            [.taken(days[6]), .taken(days[6]), .taken(days[6])]   // all taken
        ]
        let expected: [DoseDotStatus] = [.taken, .missed, .missed, .taken, .missed, .missed, .taken]

        var allEntries: [DoseEntry] = []
        for (dayIndex, day) in days.enumerated() {
            for (doseIndex, hour) in doseHours.enumerated() {
                allEntries.append(entry(on: day, hour: hour, status: dailyStatuses[dayIndex][doseIndex]))
            }
        }
        #expect(allEntries.count == 21, "3 doses/day x 7 days")
        let byMed = [medId: allEntries]

        let results = days.map { doseDotStatus(for: medId, on: $0, entriesByMedicationId: byMed) }

        #expect(results.allSatisfy { $0 != nil }, "Every day in the week should resolve to a dot")
        #expect(results.compactMap { $0 } == expected)
    }

    @Test("'Some missed' and 'all missed' are both .missed - the dot doesn't distinguish degrees of missing")
    func testPartialAndFullMissBothReadAsMissed() throws {
        let day = Calendar.current.startOfDay(for: Date())
        let someMissed = [medId: [
            entry(on: day, hour: 8, status: .taken(day)),
            entry(on: day, hour: 14, status: .missed),
            entry(on: day, hour: 20, status: .taken(day))
        ]]
        let allMissed = [medId: [
            entry(on: day, hour: 8, status: .missed),
            entry(on: day, hour: 14, status: .missed),
            entry(on: day, hour: 20, status: .missed)
        ]]

        #expect(doseDotStatus(for: medId, on: day, entriesByMedicationId: someMissed) == .missed)
        #expect(doseDotStatus(for: medId, on: day, entriesByMedicationId: allMissed) == .missed)
    }
}
