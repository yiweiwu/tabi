import Testing
import Foundation
import FirebaseFirestore
@testable import Tabi

// MARK: - Calendar Persistence Sync Tests

// Covers CalendarPersistenceManager's FirestoreCacheStore conformance,
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
struct CalendarPersistenceSyncTests {

    @Test("Already-fetched sessions skip, regardless of uid")
    func testAlreadyFetchedSkipsEvenWithAUser() throws {
        #expect(CalendarPersistenceManager.decideFetch(hasFetched: true, uid: "user-123") == .skipAlreadyFetched)
        #expect(CalendarPersistenceManager.decideFetch(hasFetched: true, uid: nil) == .skipAlreadyFetched)
    }

    @Test("No signed-in user skips instead of fetching")
    func testNoUserSkipsWithoutMarkingFetched() throws {
        #expect(CalendarPersistenceManager.decideFetch(hasFetched: false, uid: nil) == .skipNoSignedInUser)
    }

    @Test("A signed-in, not-yet-fetched session proceeds to fetch that uid")
    func testSignedInNotYetFetchedProceedsToFetch() throws {
        #expect(CalendarPersistenceManager.decideFetch(hasFetched: false, uid: "user-123") == .fetch(uid: "user-123"))
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
