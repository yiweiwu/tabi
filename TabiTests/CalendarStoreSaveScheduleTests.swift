import Testing
import Foundation
@testable import Tabi

// MARK: - Calendar Store Save-Schedule Tests

// Covers CalendarStore.entriesSurviving - which existing DoseEntry records
// get carried over when a medication's schedule is regenerated (add or
// edit). Motivated by a real account: editing a medication's dose time
// after the old time had already passed today left a stale `.skipped`
// entry for the old time sitting alongside the correct fresh `.upcoming`
// entry for the new time, since save(schedule:) only ever stripped
// `.upcoming` entries before this fix. See .claude/rules/dose-tracking.md.
@Suite
struct CalendarStoreSaveScheduleTests {

    private func entry(hour: Int, on day: Date, status: DoseStatus) -> DoseEntry {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return DoseEntry(medicationId: UUID(), medicationName: "Acticlate", dosage: "150mg", scheduledDate: date, status: status)
    }

    @Test("An .upcoming entry never survives a regeneration")
    func testUpcomingNeverSurvives() throws {
        let today = Date()
        let e = entry(hour: 9, on: today, status: .upcoming)
        #expect(CalendarStore.entriesSurviving([e], regeneratingOn: today).isEmpty)
    }

    @Test("A stale .skipped entry from earlier today (e.g. an old dose time) does not survive")
    func testStaleSkippedFromTodayDoesNotSurvive() throws {
        let today = Date()
        // The old 8pm slot, seeded skipped by an earlier edit today.
        let staleSkipped = entry(hour: 20, on: today, status: .skipped(today))
        #expect(CalendarStore.entriesSurviving([staleSkipped], regeneratingOn: today).isEmpty)
    }

    @Test(".taken and .missed always survive, even on the regeneration day")
    func testTakenAndMissedAlwaysSurvive() throws {
        let today = Date()
        let taken = entry(hour: 8, on: today, status: .taken(today))
        let missed = entry(hour: 12, on: today, status: .missed)

        let result = CalendarStore.entriesSurviving([taken, missed], regeneratingOn: today)

        #expect(Set(result.map(\.id)) == Set([taken.id, missed.id]))
    }

    @Test("A .skipped entry from a past day is untouched - it's settled history from that day's own mid-day add")
    func testSkippedFromPastDayIsUntouched() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let pastSkipped = entry(hour: 8, on: yesterday, status: .skipped(yesterday))

        let result = CalendarStore.entriesSurviving([pastSkipped], regeneratingOn: today)

        #expect(result.map(\.id) == [pastSkipped.id])
    }

    @Test("Real-world mix: only the stale same-day skipped entry is dropped, everything else survives")
    func testRealWorldMix() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let takenYesterday = entry(hour: 8, on: yesterday, status: .taken(yesterday))
        let staleSkippedToday = entry(hour: 20, on: today, status: .skipped(today))  // old 8pm slot
        let upcomingToday = entry(hour: 21, on: today, status: .upcoming)            // to be replaced anyway
        let missedEarlierToday = entry(hour: 8, on: today, status: .missed)

        let result = CalendarStore.entriesSurviving(
            [takenYesterday, staleSkippedToday, upcomingToday, missedEarlierToday],
            regeneratingOn: today
        )

        #expect(Set(result.map(\.id)) == Set([takenYesterday.id, missedEarlierToday.id]))
    }
}
