import Foundation

// MARK: - Shared People Store

// Single owner of caretaker/shared-connection state: an in-memory cache
// backed by Firestore, following FirestoreCacheStore's shape exactly like
// UserProfileStore/MedicationStore - a singleton, passed down as
// @ObservedObject, queried through here rather than any view opening its
// own Firestore connection.
//
// Unlike those two, SharedPerson.optInStatus can flip from "pending" to
// "confirmed" server-side at any time (confirmCaretakerOptIn's Admin SDK
// write, which bypasses this client entirely) - so a caller that needs the
// current state (SharingView appearing, MissedDoseAlertService before
// sending an alert) calls refresh() (from FirestoreCacheStore's extension)
// rather than plain fetchIfNeeded(), forcing a re-fetch instead of trusting
// whatever was true at first load.
final class SharedPeopleStore: ObservableObject, FirestoreCacheStore {
    static let shared = SharedPeopleStore()

    @Published var sharedPeople: [SharedPerson] = []

    private let remoteStore: SharedPeopleRemoteStore
    private var hasFetched = false

    // Not private: `.shared` is still the only instance the app itself
    // constructs (always with the real Firestore-backed remoteStore), but
    // tests need an isolated fake to exercise fetchIfNeeded()/performFetch(uid:)
    // without live Firebase.
    init(remoteStore: SharedPeopleRemoteStore = FirestoreSharedPeopleRemoteStore()) {
        self.remoteStore = remoteStore
    }

    static func decideFetch(hasFetched: Bool, uid: String?) -> FirestoreFetchDecision {
        decideFirestoreFetch(hasFetched: hasFetched, uid: uid)
    }

    func fetchIfNeeded() async {
        switch Self.decideFetch(hasFetched: hasFetched, uid: AuthenticationManager.shared.uid) {
        case .skipAlreadyFetched:
            return
        case .skipNoSignedInUser:
            print("SharedPeopleStore: skipping fetch - no signed-in user")
        case .fetch(let uid):
            hasFetched = true
            await performFetch(uid: uid)
        }
    }

    // Not private: exercised directly in unit tests against a fake
    // remoteStore, bypassing fetchIfNeeded()'s AuthenticationManager.uid
    // lookup (which needs live Firebase).
    func performFetch(uid: String) async {
        do {
            let people = try await remoteStore.fetchSharedPeople(uid: uid)
                .sorted { $0.dateAdded > $1.dateAdded }
            await MainActor.run { self.sharedPeople = people }
        } catch {
            print("SharedPeopleStore: failed to fetch - \(error.localizedDescription)")
        }
    }

    func invalidate() {
        hasFetched = false
    }

    // Optimistic - updates the cache immediately (like MedicationStore.add)
    // so the UI reflects the new connection without waiting on a round trip,
    // then persists in the background.
    func add(_ person: SharedPerson) {
        sharedPeople.insert(person, at: 0)
        Task {
            guard let uid = AuthenticationManager.shared.uid else { return }
            do {
                try await remoteStore.saveSharedPerson(uid: uid, person: person)
            } catch {
                print("SharedPeopleStore: failed to add connection - \(error.localizedDescription)")
            }
        }
    }

    func remove(_ person: SharedPerson) {
        sharedPeople.removeAll { $0.id == person.id }
        Task {
            guard let uid = AuthenticationManager.shared.uid else { return }
            do {
                try await remoteStore.deleteSharedPerson(uid: uid, personId: person.id)
            } catch {
                print("SharedPeopleStore: failed to remove connection - \(error.localizedDescription)")
            }
        }
    }

    // Called on account deletion, matching UserProfileStore.reset()/
    // MedicationStore.deleteAllLocalData() so a subsequent sign-in in the
    // same app session doesn't show a stale cache.
    func reset() {
        hasFetched = false
        sharedPeople = []
    }
}
