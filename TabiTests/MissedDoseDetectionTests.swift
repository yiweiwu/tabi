import Testing
import Foundation
@testable import Tabi

// MARK: - Missed Dose Detection Tests

// Covers the pure logic behind the caretaker SMS "bridge": which dose
// entries should flip to `.missed` and trigger an alert. Firestore writes
// and the Cloud Function itself are out of scope here - this only verifies
// `applyingMissedStatus` makes the right call given a set of entries and a
// reference time.
@Suite
struct MissedDoseDetectionTests {

    private func entry(medicationName: String = "Lisinopril", scheduledDate: Date, status: DoseStatus) -> DoseEntry {
        DoseEntry(medicationId: UUID(), medicationName: medicationName, dosage: "10mg", scheduledDate: scheduledDate, status: status)
    }

    @Test("An upcoming dose whose scheduled time has passed is marked missed")
    func testOverdueUpcomingDoseIsMarkedMissed() throws {
        let now = Date()
        let overdue = entry(scheduledDate: now.addingTimeInterval(-3600), status: .upcoming)

        let (updated, newlyMissed) = [overdue].applyingMissedStatus(now: now)

        #expect(updated.count == 1)
        #expect(updated[0].status == .missed)
        #expect(newlyMissed.count == 1)
        #expect(newlyMissed[0].id == overdue.id)
    }

    @Test("An upcoming dose still in the future is left alone")
    func testFutureUpcomingDoseIsNotMissed() throws {
        let now = Date()
        let future = entry(scheduledDate: now.addingTimeInterval(3600), status: .upcoming)

        let (updated, newlyMissed) = [future].applyingMissedStatus(now: now)

        #expect(updated[0].status == .upcoming)
        #expect(newlyMissed.isEmpty)
    }

    @Test("A dose already marked missed is not re-reported (no duplicate alerts)")
    func testAlreadyMissedDoseIsNotReReported() throws {
        let now = Date()
        let alreadyMissed = entry(scheduledDate: now.addingTimeInterval(-3600), status: .missed)

        let (updated, newlyMissed) = [alreadyMissed].applyingMissedStatus(now: now)

        #expect(updated[0].status == .missed)
        #expect(newlyMissed.isEmpty, "A dose that was already missed should not fire a second alert")
    }

    @Test("Taken and skipped doses are never marked missed, even if overdue")
    func testTakenAndSkippedDosesAreIgnored() throws {
        let now = Date()
        let taken = entry(scheduledDate: now.addingTimeInterval(-3600), status: .taken(now.addingTimeInterval(-3500)))
        let skipped = entry(scheduledDate: now.addingTimeInterval(-3600), status: .skipped(now.addingTimeInterval(-3500)))

        let (updated, newlyMissed) = [taken, skipped].applyingMissedStatus(now: now)

        #expect(updated.map(\.status) == [taken.status, skipped.status])
        #expect(newlyMissed.isEmpty)
    }

    @Test("Only the overdue entries in a mixed batch are reported, one alert per entry")
    func testMixedBatchOnlyReportsOverdueUpcomingEntries() throws {
        let now = Date()
        let overdueA = entry(medicationName: "Lisinopril", scheduledDate: now.addingTimeInterval(-7200), status: .upcoming)
        let overdueB = entry(medicationName: "Metformin", scheduledDate: now.addingTimeInterval(-60), status: .upcoming)
        let future = entry(medicationName: "Lisinopril", scheduledDate: now.addingTimeInterval(60), status: .upcoming)
        let taken = entry(medicationName: "Metformin", scheduledDate: now.addingTimeInterval(-7200), status: .taken(now))

        let (updated, newlyMissed) = [overdueA, overdueB, future, taken].applyingMissedStatus(now: now)

        #expect(updated.count == 4)
        #expect(Set(newlyMissed.map(\.id)) == Set([overdueA.id, overdueB.id]))
        #expect(newlyMissed.map(\.medicationName).sorted() == ["Lisinopril", "Metformin"])
    }
}

// MARK: - Mid-Day Add Seeding Tests

// A medication added mid-day pre-seeds Medication.takenToday for slots
// that already passed today (see NewMedicationCameraView). DoseSchedule's
// entries must agree, or the missed-dose check fires a false alert for a
// dose that predates the medication being added at all.
@Suite
struct DoseScheduleBuildEntriesTests {

    private func time(_ hour: Int, on date: Date = Date()) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    private func schedule(scheduledTimes: [Date], startDate: Date) -> DoseSchedule {
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        return DoseSchedule(
            medicationId: UUID(), medicationName: "Lisinopril", medicationEmoji: "💊",
            dosage: "10mg", colorIndex: 0, scheduledTimes: scheduledTimes,
            startDate: startDate, endDate: endDate
        )
    }

    @Test("A dose whose time already passed today, on the day it was added, is seeded as skipped")
    func testAlreadyPassedTimeOnAddDayIsSeededSkipped() throws {
        let addedAt = time(14) // added at 2pm
        let s = schedule(scheduledTimes: [time(8), time(20)], startDate: addedAt) // 8am, 8pm

        let entries = s.buildEntries()
        let today = Calendar.current.startOfDay(for: addedAt)
        let todaysEntries = entries.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: today) }

        let morning = todaysEntries.first { Calendar.current.component(.hour, from: $0.scheduledDate) == 8 }
        let evening = todaysEntries.first { Calendar.current.component(.hour, from: $0.scheduledDate) == 20 }

        // Not .taken - the user never tapped Taken. Not .upcoming either - that
        // would let the missed-dose checker later flip it to .missed and fire a
        // false caretaker alert for a dose that predates the medication even
        // being added. .skipped is the deliberate middle ground (see
        // .claude/rules/dose-tracking.md's Mid-day medication add section).
        #expect(morning?.status == .skipped(addedAt), "8am already passed by the 2pm add time, so it should be pre-seeded skipped")
        #expect(evening?.status == .upcoming, "8pm hasn't happened yet, so it should stay upcoming")
    }

    @Test("Future days keep the same time-of-day as upcoming, even though the add day's version was seeded skipped")
    func testFutureDaysStayUpcomingDespiteSameTimeBeingPastOnAddDay() throws {
        let addedAt = time(14) // added at 2pm, so 8am today already passed
        let s = schedule(scheduledTimes: [time(8)], startDate: addedAt)

        let entries = s.buildEntries()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: addedAt))!
        let tomorrowEntry = entries.first { Calendar.current.isDate($0.scheduledDate, inSameDayAs: tomorrow) }

        #expect(tomorrowEntry?.status == .upcoming, "8am tomorrow hasn't happened yet - only today's 8am was pre-seeded")
    }

    @Test("A mid-day add never produces a false missed-dose alert for the pre-seeded doses")
    func testMidDayAddDoesNotTriggerFalseMissedAlert() throws {
        let addedAt = time(14) // added at 2pm
        let s = schedule(scheduledTimes: [time(8), time(20)], startDate: addedAt)

        let entries = s.buildEntries()
        let (_, newlyMissed) = entries.applyingMissedStatus(now: addedAt)

        #expect(newlyMissed.isEmpty, "The 8am dose predates the medication being added - it must not be reported as missed")
    }

    @Test("Adding before any scheduled time today leaves everything upcoming")
    func testAddBeforeAnyScheduledTimeTodayLeavesEverythingUpcoming() throws {
        let addedAt = time(7) // added at 7am, before either dose time
        let s = schedule(scheduledTimes: [time(8), time(20)], startDate: addedAt)

        let entries = s.buildEntries()
        let today = Calendar.current.startOfDay(for: addedAt)
        let todaysEntries = entries.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: today) }

        #expect(todaysEntries.allSatisfy { $0.status == .upcoming })
    }
}

// MARK: - Caretaker Opt-In Eligibility Tests

// A caretaker only receives missed-dose alerts once they've confirmed via
// the confirmCaretakerOptIn link - having a phone number entered by the
// patient is not itself consent. See SharedPerson.isEligibleForMissedDoseAlerts.
@Suite
struct SharedPersonOptInEligibilityTests {

    @Test("A confirmed caretaker with a phone number is eligible")
    func testConfirmedWithPhoneIsEligible() throws {
        let person = SharedPerson(name: "Jane", phoneNumber: "+15551234567", optInStatus: .confirmed)
        #expect(person.isEligibleForMissedDoseAlerts)
    }

    @Test("A pending caretaker is not eligible")
    func testPendingIsNotEligible() throws {
        let person = SharedPerson(name: "Jane", phoneNumber: "+15551234567", optInStatus: .pending)
        #expect(!person.isEligibleForMissedDoseAlerts)
    }

    @Test("A legacy doc decoded with no optInStatus field is not eligible")
    func testLegacyDecodeIsNotEligible() throws {
        let dict: [String: Any] = ["id": UUID().uuidString, "name": "Jane", "phoneNumber": "+15551234567", "dateAdded": 0]
        let person = try #require(SharedPerson.decoded(from: dict))
        #expect(person.optInStatus == nil)
        #expect(!person.isEligibleForMissedDoseAlerts)
    }

    @Test("An email-only caretaker is never eligible regardless of optInStatus")
    func testEmailOnlyNeverEligible() throws {
        let person = SharedPerson(name: "Jane", email: "jane@example.com", optInStatus: .confirmed)
        #expect(!person.isEligibleForMissedDoseAlerts)
    }
}
