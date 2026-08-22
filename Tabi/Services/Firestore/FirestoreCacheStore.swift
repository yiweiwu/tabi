import Foundation

// MARK: - Firestore Cache Store

// The shared "memcache in front of Firestore" shape every store singleton
// (UserProfileStore, MedicationStore, SharedPeopleStore) follows: an
// in-memory @Published cache, fetched from Firestore once per sign-in and
// trusted after that - reads never re-hit Firestore on their own. Local
// mutations (add/save/remove) keep the cache correct themselves via
// optimistic writes, the same way any cache-aside client updates its own
// cache after a write instead of re-reading it back.
//
// `invalidate()` is the one escape hatch: it clears the "already fetched"
// guard without clearing already-loaded data, so the *next* fetchIfNeeded()
// call re-fetches instead of trusting the cache. Most stores never need to
// call it - UserProfileStore/MedicationStore are only ever mutated by this
// same client, so their cache can't go stale out from under them. Use it
// where data can change from somewhere other than this client's own writes
// (see SharedPeopleStore, whose optInStatus field is flipped by a Cloud
// Function via the Admin SDK).
protocol FirestoreCacheStore: AnyObject {
    func fetchIfNeeded() async
    func invalidate()
}

extension FirestoreCacheStore {
    // Forces a re-fetch regardless of whether the cache was already loaded.
    // For a caller that genuinely needs the current Firestore state right
    // now (not "whatever was true at first load") - see
    // MissedDoseAlertService and SharingView's use of SharedPeopleStore.
    func refresh() async {
        invalidate()
        await fetchIfNeeded()
    }
}

// MARK: - Fetch Decision

// Pure decision logic shared by every store's fetchIfNeeded(), kept separate
// from the actual Firestore I/O so it's testable without live Firebase
// (AuthenticationManager.shared.uid needs a real FirebaseApp, which TabiTests
// doesn't configure - see testing.md).
enum FirestoreFetchDecision: Equatable {
    case skipAlreadyFetched
    case skipNoSignedInUser
    case fetch(uid: String)
}

func decideFirestoreFetch(hasFetched: Bool, uid: String?) -> FirestoreFetchDecision {
    guard !hasFetched else { return .skipAlreadyFetched }
    guard let uid else { return .skipNoSignedInUser }
    return .fetch(uid: uid)
}
