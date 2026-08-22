import Foundation
import FirebaseFirestore

// MARK: - User Profile Store

// Single owner of profile state: an in-memory cache backed by Firestore.
// Fetches once per session (not a live listener - the caller is already
// signed in and the profile is expected to already be cached by the time any
// screen reads it), and every write goes through here too, so there is never
// more than one copy of the profile floating around the app.
//
// Not @MainActor, matching every other manager in this codebase
// (CalendarStore, MedicationStore, NotificationScheduler) -
// per CLAUDE.md's concurrency convention, UI-affecting mutations are
// dispatched to main manually rather than via compiler-enforced isolation.
final class UserProfileStore: ObservableObject, FirestoreCacheStore {
    static let shared = UserProfileStore()

    @Published var profile = UserProfile() {
        didSet {
            guard !isApplyingFetch else { return }
            persist(profile)
        }
    }

    private var hasFetched = false
    private var isApplyingFetch = false
    private let remoteStore: UserProfileRemoteStore

    // Not private: `.shared` is still the only instance the app itself
    // constructs (always with the real Firestore-backed remoteStore), but
    // tests need to build their own isolated instance with a fake one.
    init(remoteStore: UserProfileRemoteStore = FirestoreUserProfileRemoteStore()) {
        self.remoteStore = remoteStore
    }

    // What fetchIfNeeded should do, given its two inputs, kept as a pure
    // decision separate from the Firestore I/O in fetchIfNeeded() below -
    // that I/O can't run in a unit test (no FirebaseApp configured in
    // TabiTests), but the branching that decides whether it *should* run
    // can be reasoned about and tested on its own.
    static func decideFetch(hasFetched: Bool, uid: String?) -> FirestoreFetchDecision {
        decideFirestoreFetch(hasFetched: hasFetched, uid: uid)
    }

    // One-shot fetch into the in-memory cache. Guarded by `hasFetched` so
    // later calls (e.g. every onboarding page transition) don't re-hit
    // Firestore - callers should call this liberally rather than checking
    // state themselves. No-ops when signed out, matching the "no
    // anonymous/device-ID fallback" pattern already used by
    // CalendarStore for doses.
    func fetchIfNeeded() async {
        switch Self.decideFetch(hasFetched: hasFetched, uid: AuthenticationManager.shared.uid) {
        case .skipAlreadyFetched:
            return
        case .skipNoSignedInUser:
            print("UserProfileStore: skipping fetch - no signed-in user")
        case .fetch(let uid):
            hasFetched = true
            await performFetch(uid: uid)
        }
    }

    // Not private: exercised directly in UserProfileLoadingTests against a
    // fake remoteStore, bypassing fetchIfNeeded()'s AuthenticationManager.uid
    // lookup (which needs live Firebase and can't run in a unit test).
    func performFetch(uid: String) async {
        let data: [String: Any]?
        do {
            data = try await remoteStore.fetchProfileDocument(uid: uid)
        } catch {
            print("UserProfileStore: failed to fetch profile - \(error.localizedDescription)")
            return
        }
        guard let data else { return }
        guard let decoded = UserProfile.decoded(from: data) else {
            print("UserProfileStore: failed to decode profile document")
            return
        }
        await MainActor.run {
            self.isApplyingFetch = true
            self.profile = decoded
            self.isApplyingFetch = false
        }
    }

    // Resets the cache so a subsequent sign-in in the same app session (e.g.
    // right after deleting an account) doesn't show stale data.
    func reset() {
        hasFetched = false
        isApplyingFetch = true
        profile = UserProfile()
        isApplyingFetch = false
    }

    // Required by FirestoreCacheStore, but nothing currently calls it - the
    // profile is only ever mutated by this same client's own writes, so
    // there's no external source of staleness to force a re-check against.
    func invalidate() {
        hasFetched = false
    }

    private func persist(_ profile: UserProfile) {
        guard let uid = AuthenticationManager.shared.uid, let dict = profile.firestoreDict() else { return }
        Firestore.firestore().collection("users").document(uid).setData(dict, merge: true) { error in
            if let error {
                print("UserProfileStore: failed to save profile - \(error.localizedDescription)")
            }
        }
    }
}
