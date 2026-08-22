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
