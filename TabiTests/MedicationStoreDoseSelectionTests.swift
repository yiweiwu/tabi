import Testing
import Foundation
@testable import Tabi

// MARK: - Medication Store Dose Selection Tests

// Covers MedicationStore.earliestUnresolvedEntry - which DoseEntry a Today
// "Taken"/"Skip" tap acts on. Critically, `.missed` counts as unresolved
// (not just `.upcoming`): the server-side checkMissedDoses Cloud Function
// writes `.missed` on its own hourly schedule, and a user tapping Taken/Skip
// after that happened - a late-but-real action - must still be able to
// override it, not be silently ignored because the entry is no longer
// `.upcoming`. See .claude/rules/dose-tracking.md.
@Suite
struct MedicationStoreDoseSelectionTests {

    private func entry(hour: Int, on day: Date = Date(), status: DoseStatus) -> DoseEntry {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return DoseEntry(medicationId: UUID(), medicationName: "Lisinopril", dosage: "10mg", scheduledDate: date, status: status)
    }

    @Test("An .upcoming entry is selected")
    func testUpcomingIsSelected() throws {
        let e = entry(hour: 8, status: .upcoming)
        #expect(MedicationStore.earliestUnresolvedEntry(in: [e])?.id == e.id)
    }

    @Test("A .missed entry is selected - a late Taken/Skip tap must override it")
    func testMissedIsSelected() throws {
        let e = entry(hour: 8, status: .missed)
        #expect(MedicationStore.earliestUnresolvedEntry(in: [e])?.id == e.id)
    }

    @Test(".taken and .skipped are final - never re-selected")
    func testTakenAndSkippedAreNotSelected() throws {
        let taken = entry(hour: 8, status: .taken(Date()))
        let skipped = entry(hour: 14, status: .skipped(Date()))
        #expect(MedicationStore.earliestUnresolvedEntry(in: [taken, skipped]) == nil)
    }

    @Test("The earliest unresolved entry wins, regardless of status mix")
    func testEarliestUnresolvedWins() throws {
        let morning = entry(hour: 8, status: .taken(Date()))     // resolved, skip
        let afternoon = entry(hour: 14, status: .missed)          // unresolved, earliest of the rest
        let evening = entry(hour: 20, status: .upcoming)          // unresolved, later

        #expect(MedicationStore.earliestUnresolvedEntry(in: [evening, afternoon, morning])?.id == afternoon.id)
    }

    @Test("Only entries on the given day are considered")
    func testOnlyTodaysEntriesConsidered() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let yesterdaysMissed = entry(hour: 8, on: yesterday, status: .missed)
        let todaysUpcoming = entry(hour: 8, on: today, status: .upcoming)

        #expect(MedicationStore.earliestUnresolvedEntry(in: [yesterdaysMissed, todaysUpcoming], on: today)?.id == todaysUpcoming.id)
    }

    @Test("No entries at all returns nil")
    func testEmptyReturnsNil() throws {
        #expect(MedicationStore.earliestUnresolvedEntry(in: []) == nil)
    }
}
