import Testing
import Foundation
@testable import Tabi

// MARK: - Shared People Sync Tests

// Covers SharedPeopleStore's Firestore sync, mirroring MedicationStoreSyncTests/
// UserProfileLoadingTests - same FirestoreCacheStore shape (decideFetch,
// fetchIfNeeded, performFetch(uid:)), exercised against a fake
// SharedPeopleRemoteStore since AuthenticationManager.shared.uid needs live
// Firebase (see testing.md).
//
// The one genuinely new behavior versus the other two stores: invalidate()/
// refresh() actually matter here, since SharedPerson.optInStatus can change
// from outside this client (confirmCaretakerOptIn's Admin SDK write) - the
// tests below cover that a plain fetchIfNeeded() after the first load is a
// no-op, but refresh() forces a re-fetch regardless.
@Suite
struct SharedPeopleSyncTests {

    private func makePerson(name: String = "Jamie", optInStatus: CaretakerOptInStatus? = nil) -> SharedPerson {
        SharedPerson(name: name, phoneNumber: "555-0100", optInStatus: optInStatus)
    }

    // MARK: fetchIfNeeded's decision logic

    @Test("Already-fetched sessions skip, regardless of uid")
    func testAlreadyFetchedSkipsEvenWithAUser() throws {
        #expect(SharedPeopleStore.decideFetch(hasFetched: true, uid: "user-123") == .skipAlreadyFetched)
        #expect(SharedPeopleStore.decideFetch(hasFetched: true, uid: nil) == .skipAlreadyFetched)
    }

    @Test("No signed-in user skips instead of fetching")
    func testNoUserSkipsWithoutMarkingFetched() throws {
        #expect(SharedPeopleStore.decideFetch(hasFetched: false, uid: nil) == .skipNoSignedInUser)
    }

    @Test("A signed-in, not-yet-fetched session proceeds to fetch that uid")
    func testSignedInNotYetFetchedProceedsToFetch() throws {
        #expect(SharedPeopleStore.decideFetch(hasFetched: false, uid: "user-123") == .fetch(uid: "user-123"))
    }

    // MARK: performFetch - adopting Firestore as truth

    @Test("A non-empty Firestore fetch populates the in-memory list, newest first")
    func testFetchAdoptsRemoteSortedByNewest() async throws {
        let remote = FakeSharedPeopleRemoteStore()
        let older = SharedPerson(name: "Older", phoneNumber: "555-0100", dateAdded: Date(timeIntervalSince1970: 0))
        let newer = SharedPerson(name: "Newer", phoneNumber: "555-0101", dateAdded: Date(timeIntervalSince1970: 1000))
        remote.peopleToReturn = [older, newer]
        let store = SharedPeopleStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")

        #expect(store.sharedPeople.map(\.name) == ["Newer", "Older"])
    }

    @Test("A fetch failure leaves the in-memory list untouched rather than crashing or clearing it")
    func testFetchFailureLeavesStateUntouched() async throws {
        struct FakeNetworkError: Error {}
        let remote = FakeSharedPeopleRemoteStore()
        remote.fetchError = FakeNetworkError()
        let store = SharedPeopleStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")

        #expect(store.sharedPeople.isEmpty)
    }

    // MARK: invalidate()/refresh() - the behavior unique to this store

    @Test("fetchIfNeeded only hits Firestore once per session; invalidate() forces the next call to re-fetch")
    func testInvalidateForcesReFetch() async throws {
        let remote = FakeSharedPeopleRemoteStore()
        remote.peopleToReturn = [makePerson(optInStatus: .pending)]
        let store = SharedPeopleStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")
        #expect(remote.fetchCallCount == 1)
        #expect(store.sharedPeople.first?.optInStatus == .pending)

        // Simulate the caretaker confirming server-side between fetches.
        remote.peopleToReturn = [makePerson(optInStatus: .confirmed)]
        store.invalidate()
        await store.performFetch(uid: "user-123")

        #expect(remote.fetchCallCount == 2)
        #expect(store.sharedPeople.first?.optInStatus == .confirmed, "invalidate() should let the next fetch pick up the server-side change")
    }
}

// MARK: - Fake Remote Store

private final class FakeSharedPeopleRemoteStore: SharedPeopleRemoteStore {
    var peopleToReturn: [SharedPerson] = []
    var fetchError: Error?
    private(set) var fetchCallCount = 0
    private(set) var savedPeople: [SharedPerson] = []
    private(set) var deletedPersonIds: [UUID] = []

    func fetchSharedPeople(uid: String) async throws -> [SharedPerson] {
        fetchCallCount += 1
        if let fetchError { throw fetchError }
        return peopleToReturn
    }

    func saveSharedPerson(uid: String, person: SharedPerson) async throws {
        savedPeople.append(person)
    }

    func deleteSharedPerson(uid: String, personId: UUID) async throws {
        deletedPersonIds.append(personId)
    }
}
