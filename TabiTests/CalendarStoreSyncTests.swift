import Testing
import Foundation
import FirebaseFirestore
@testable import Tabi

// MARK: - Calendar Store Sync Tests

// Covers CalendarStore's FirestoreCacheStore conformance,
// mirroring UserProfileLoadingTests/MedicationStoreSyncTests/SharedPeopleSyncTests.
//
// Narrower than its siblings on purpose: every other public method here
// (save(schedule:), updateStatus, startListening) resolves
// AuthenticationManager.shared.uid synchronously, either directly or inside
// an unstructured Task - and that needs live Firebase, which TabiTests
// doesn't configure (see testing.md). The other three stores' add()/remove()
// have the exact same constraint and aren't exercised in their test suites
// either (only performFetch(uid:)/decideFetch, which take uid as a plain
// argument and never touch AuthenticationManager). decideFetch is the one
// piece of this store's logic that's pure and safe to test without it.
@Suite
struct CalendarStoreSyncTests {

    @Test("Already-fetched sessions skip, regardless of uid")
    func testAlreadyFetchedSkipsEvenWithAUser() throws {
        #expect(CalendarStore.decideFetch(hasFetched: true, uid: "user-123") == .skipAlreadyFetched)
        #expect(CalendarStore.decideFetch(hasFetched: true, uid: nil) == .skipAlreadyFetched)
    }

    @Test("No signed-in user skips instead of fetching")
    func testNoUserSkipsWithoutMarkingFetched() throws {
        #expect(CalendarStore.decideFetch(hasFetched: false, uid: nil) == .skipNoSignedInUser)
    }

    @Test("A signed-in, not-yet-fetched session proceeds to fetch that uid")
    func testSignedInNotYetFetchedProceedsToFetch() throws {
        #expect(CalendarStore.decideFetch(hasFetched: false, uid: "user-123") == .fetch(uid: "user-123"))
    }
}

// MARK: - Rolling Schedule Extension Tests

// Covers decideExtension - the pure logic behind keeping each medication's
// persisted DoseEntry window actually rolling forward, instead of a one-time
// 30-day allocation from whenever the medication was last added/edited (see
// .claude/rules/dose-tracking.md).
@Suite
struct CalendarStoreScheduleExtensionTests {

    @Test("Plenty of runway left: no extension")
    func testNoExtensionWhenRunwayIsLong() throws {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 20, to: now)!
        #expect(CalendarStore.decideExtension(horizon: horizon, now: now) == nil)
    }

    @Test("Runway below the threshold: extends forward from the day after the current horizon")
    func testExtendsWhenRunwayIsShort() throws {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 3, to: now)!

        let decision = try #require(CalendarStore.decideExtension(horizon: horizon, now: now))

        let expectedStart = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: horizon))!
        let expectedEnd = Calendar.current.date(byAdding: .day, value: MedicationScheduleParser.scheduleWindowDays, to: now)!
        #expect(Calendar.current.isDate(decision.startDate, inSameDayAs: expectedStart))
        #expect(Calendar.current.isDate(decision.endDate, inSameDayAs: expectedEnd))
    }

    @Test("Exactly at the threshold boundary still extends (< not <=)")
    func testExtendsRightAtThreshold() throws {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: CalendarStore.scheduleExtensionThresholdDays - 1, to: now)!
        #expect(CalendarStore.decideExtension(horizon: horizon, now: now) != nil)
    }

    @Test("A horizon already in the past still extends forward from tomorrow, not from the stale horizon")
    func testExtendsFromPastHorizon() throws {
        let now = Date()
        let staleHorizon = Calendar.current.date(byAdding: .day, value: -5, to: now)!

        let decision = try #require(CalendarStore.decideExtension(horizon: staleHorizon, now: now))

        #expect(decision.startDate > staleHorizon)
        #expect(decision.endDate > now)
    }
}

// MARK: - Fake Remote Store

// Not exercised by the tests above (see the suite's doc comment), but kept
// here so CalendarRemoteStore's shape itself is verified to compile against
// a fake, matching the other three stores' remote-store protocols.
private final class FakeCalendarRemoteStore: CalendarRemoteStore {
    var entriesToReturn: [DoseEntry] = []
    private(set) var savedEntries: [[DoseEntry]] = []

    func fetchEntries(uid: String, medicationId: UUID) async throws -> [DoseEntry] {
        entriesToReturn
    }

    func saveEntries(uid: String, medicationId: UUID, entries: [DoseEntry]) async throws {
        savedEntries.append(entries)
    }

    func listenToEntries(uid: String, medicationId: UUID, onChange: @escaping ([DoseEntry]) -> Void) -> ListenerRegistration {
        FakeListenerRegistration()
    }
}

private final class FakeListenerRegistration: NSObject, ListenerRegistration {
    func remove() {}
}
