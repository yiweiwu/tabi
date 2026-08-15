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
// (CalendarPersistenceManager, MedicationManager, NotificationScheduler) -
// per CLAUDE.md's concurrency convention, UI-affecting mutations are
// dispatched to main manually rather than via compiler-enforced isolation.
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    @Published var profile = UserProfile() {
        didSet {
            guard !isApplyingFetch else { return }
            persist(profile)
        }
    }

    private var hasFetched = false
    private var isApplyingFetch = false

    private init() {}

    // One-shot fetch into the in-memory cache. Guarded by `hasFetched` so
    // later calls (e.g. every onboarding page transition) don't re-hit
    // Firestore - callers should call this liberally rather than checking
    // state themselves. No-ops when signed out, matching the "no
    // anonymous/device-ID fallback" pattern already used by
    // CalendarPersistenceManager for doses.
    func fetchIfNeeded() async {
        guard !hasFetched, let uid = AuthenticationManager.shared.uid else { return }
        hasFetched = true
        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
              let data = snapshot.data(),
              let decoded = UserProfile.decoded(from: data) else { return }
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

    private func persist(_ profile: UserProfile) {
        guard let uid = AuthenticationManager.shared.uid, let dict = profile.firestoreDict() else { return }
        Firestore.firestore().collection("users").document(uid).setData(dict, merge: true)
    }
}
