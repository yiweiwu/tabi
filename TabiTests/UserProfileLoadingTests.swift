import Testing
import Foundation
@testable import Tabi

// MARK: - User Profile Loading Edge Cases

// Covers the "profile didn't load" family of bugs: onboarding skipped so
// nothing else re-fetches, the app backgrounded and killed by iOS mid
// restore, a crash/relaunch racing Firebase's session restore. Every one of
// those leaves UserProfileStore.shared.profile at its UserProfile() default
// rather than a visible error, so that default's on-screen appearance is
// tested here too.
//
// AuthenticationManager.shared.uid needs live Firebase (no FirebaseApp is
// configured in TabiTests - see testing.md), so fetchIfNeeded() itself can't
// run here. What can: UserProfileStore.decideFetch, the pure decision
// fetchIfNeeded makes from that uid (this is what used to silently no-op on
// a nil uid); and performFetch(uid:), exercised directly against a fake
// UserProfileRemoteStore to prove the actual "in-memory profile missing ->
// fetch from Firestore -> apply it" path, decode failures included.
@Suite
struct UserProfileLoadingTests {

    // MARK: fetchIfNeeded's decision logic

    @Test("Already-fetched sessions skip, regardless of uid")
    func testAlreadyFetchedSkipsEvenWithAUser() throws {
        #expect(UserProfileStore.decideFetch(hasFetched: true, uid: "user-123") == .skipAlreadyFetched)
        #expect(UserProfileStore.decideFetch(hasFetched: true, uid: nil) == .skipAlreadyFetched)
    }

    @Test("No signed-in user skips instead of fetching - covers both a genuinely signed-out device and the cold-launch race where Firebase hasn't restored the session yet")
    func testNoUserSkipsWithoutMarkingFetched() throws {
        #expect(UserProfileStore.decideFetch(hasFetched: false, uid: nil) == .skipNoSignedInUser)
    }

    @Test("A signed-in, not-yet-fetched session proceeds to fetch that uid")
    func testSignedInNotYetFetchedProceedsToFetch() throws {
        #expect(UserProfileStore.decideFetch(hasFetched: false, uid: "user-123") == .fetch(uid: "user-123"))
    }

    // MARK: Default profile (what the UI shows when nothing has loaded yet)

    @Test("A never-loaded profile displays as the 'Name' placeholder, not blank")
    func testDefaultProfileDisplayName() throws {
        #expect(UserProfile().displayName == "Name")
    }

    @Test("A never-loaded profile displays as the 'Gender, Age' placeholder, not blank")
    func testDefaultProfileDisplayInfo() throws {
        #expect(UserProfile().displayInfo == "Gender, Age")
    }

    @Test("Whitespace-only first/last name still falls back to the placeholder")
    func testWhitespaceOnlyNameFallsBackToPlaceholder() throws {
        var profile = UserProfile()
        profile.firstName = "  "
        profile.lastName = " "
        #expect(profile.displayName == "Name")
    }

    @Test("A real name is trimmed and joined")
    func testRealNameDisplaysTrimmedAndJoined() throws {
        var profile = UserProfile()
        profile.firstName = "Ada"
        profile.lastName = "Lovelace"
        #expect(profile.displayName == "Ada Lovelace")
    }

    @Test("Gender-only and age-only profiles don't show the other placeholder")
    func testDisplayInfoShowsOnlyWhicheverFieldIsSet() throws {
        var genderOnly = UserProfile()
        genderOnly.gender = "Woman"
        #expect(genderOnly.displayInfo == "Woman")

        var ageOnly = UserProfile()
        ageOnly.age = "34"
        #expect(ageOnly.displayInfo == "34")
    }

    // MARK: Firestore round trip (what a fetch/save actually pushes through)

    @Test("A populated profile survives encode -> Firestore dict -> decode unchanged")
    func testProfileRoundTripsThroughFirestoreDict() throws {
        var original = UserProfile()
        original.firstName = "Ada"
        original.lastName = "Lovelace"
        original.gender = "Woman"
        original.age = "36"
        original.settings.emailAddress = "ada@example.com"

        let dict = try #require(original.firestoreDict())
        let decoded = try #require(UserProfile.decoded(from: dict))

        #expect(decoded.displayName == original.displayName)
        #expect(decoded.displayInfo == original.displayInfo)
        #expect(decoded.settings.emailAddress == original.settings.emailAddress)
    }

    @Test("An existing Firestore doc predating a newer field still decodes, using that field's default")
    func testLegacyDocMissingANewerFieldStillDecodes() throws {
        // Simulates a `users/{uid}` document written before `settings` (or
        // any future field) existed - exactly the kind of doc a returning
        // user's account has sitting in Firestore already.
        let legacyDict: [String: Any] = [
            "firstName": "Ada",
            "lastName": "Lovelace",
            "gender": "",
            "age": "",
            "height": "",
            "weight": "",
            "allergies": [],
            "pharmacies": []
            // "settings" intentionally omitted
        ]

        let decoded = try #require(
            UserProfile.decoded(from: legacyDict),
            "A doc missing a field with a default value should still decode - if this starts failing, a fetch against a real legacy doc will silently leave the profile at UserProfile(), which looks identical to the profile never having loaded at all"
        )
        #expect(decoded.displayName == "Ada Lovelace")
        #expect(decoded.settings.unitSystem == UserSettings().unitSystem)
        #expect(decoded.settings.emailAddress == UserSettings().emailAddress)
    }

    @Test("A malformed Firestore doc fails decode rather than producing garbage data")
    func testMalformedDocFailsDecodeCleanly() throws {
        let malformedDict: [String: Any] = [
            "firstName": 12345, // wrong type - should be a String
        ]
        #expect(UserProfile.decoded(from: malformedDict) == nil)
    }

    // MARK: Fetch-and-apply (in-memory profile missing -> go fetch from Firestore)

    // decideFetch above covers *whether* a fetch should happen; these cover
    // what happens once performFetch actually runs, against a fake
    // remoteStore instead of live Firestore.

    @Test("An existing Firestore document is fetched and decoded into profile")
    func testFetchAppliesDocumentWhenItExists() async throws {
        let remote = FakeUserProfileRemoteStore()
        remote.documentToReturn = ["firstName": "Ada", "lastName": "Lovelace"]
        let store = UserProfileStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")

        #expect(remote.fetchCallCount == 1, "the fallback must actually call Firestore, not just assume a default")
        #expect(store.profile.displayName == "Ada Lovelace")
    }

    @Test("No document yet (brand-new user) leaves the profile at its default")
    func testFetchLeavesDefaultWhenNoDocumentExists() async throws {
        let remote = FakeUserProfileRemoteStore()
        remote.documentToReturn = nil
        let store = UserProfileStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")

        #expect(store.profile.displayName == "Name")
    }

    @Test("A network failure leaves the profile at its default instead of crashing")
    func testFetchLeavesDefaultOnNetworkError() async throws {
        struct FakeNetworkError: Error {}
        let remote = FakeUserProfileRemoteStore()
        remote.errorToThrow = FakeNetworkError()
        let store = UserProfileStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")

        #expect(store.profile.displayName == "Name")
    }

    @Test("An undecodable document leaves the profile at its default instead of crashing")
    func testFetchLeavesDefaultOnDecodeFailure() async throws {
        let remote = FakeUserProfileRemoteStore()
        remote.documentToReturn = ["firstName": 12345] // wrong type
        let store = UserProfileStore(remoteStore: remote)

        await store.performFetch(uid: "user-123")

        #expect(store.profile.displayName == "Name")
    }
}

// MARK: - Fake Remote Store

private final class FakeUserProfileRemoteStore: UserProfileRemoteStore {
    var documentToReturn: [String: Any]?
    var errorToThrow: Error?
    private(set) var fetchCallCount = 0

    func fetchProfileDocument(uid: String) async throws -> [String: Any]? {
        fetchCallCount += 1
        if let errorToThrow { throw errorToThrow }
        return documentToReturn
    }
}
