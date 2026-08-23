import SwiftUI
import UIKit
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

// MARK: - Authentication Manager

enum AuthenticationError: LocalizedError {
    case missingAppleIdentityToken
    case missingAppleNonce
    case missingGoogleIDToken
    case missingGoogleClientID
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .missingAppleIdentityToken: return "Apple did not return an identity token."
        case .missingAppleNonce: return "Missing sign-in nonce. Please try again."
        case .missingGoogleIDToken: return "Google did not return an ID token."
        case .missingGoogleClientID: return "Google sign-in isn't configured yet. Please try again later."
        case .notSignedIn: return "You're not signed in."
        }
    }
}

// Maps the FirebaseAuth error codes EmailVerificationGateView needs to
// message distinctly from a generic failure.
enum EmailVerificationError: LocalizedError {
    case tooManyRequests
    case alreadyVerified

    var errorDescription: String? {
        switch self {
        case .tooManyRequests: return "Too many attempts. Please wait a bit before trying again."
        case .alreadyVerified: return "This email is already verified."
        }
    }
}

@MainActor
@Observable
class AuthenticationManager {
    static let shared = AuthenticationManager()

    var currentUser: FirebaseAuth.User?

    // nonisolated: Auth.auth().currentUser is a thread-safe, synchronous read
    // in FirebaseAuth, and callers like CalendarStore/SharingView
    // are not MainActor-isolated, so uid must be reachable without a hop.
    nonisolated var uid: String? { Auth.auth().currentUser?.uid }

    // Not removed on deinit: this is a singleton that lives for the app's
    // process lifetime, so the listener is never torn down.
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // Reading `Auth.auth().currentUser` synchronously right at cold launch
    // can race Firebase's async restore of a persisted session from the
    // keychain and return nil even for a signed-in user - this happens in
    // particular right after the app is backgrounded and reaped by iOS,
    // since reopening it is a fresh process launch. The first
    // addStateDidChangeListener callback is the documented, reliable signal
    // that the restore has finished either way, so callers that need to
    // know `uid` before it's available synchronously should await this.
    private var hasReceivedInitialAuthState = false
    private var initialAuthStateWaiters: [CheckedContinuation<Void, Never>] = []

    private init() {
        currentUser = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.handleAuthStateChange(user: user)
        }
    }

    private func handleAuthStateChange(user: FirebaseAuth.User?) {
        currentUser = user
        resolveInitialAuthStateWaitersIfNeeded()
    }

    // Every addStateDidChangeListener callback runs this, but only the
    // first one (the initial restore, whether it found a session or not)
    // should release anything waiting on waitForInitialAuthState().
    private func resolveInitialAuthStateWaitersIfNeeded() {
        guard !hasReceivedInitialAuthState else { return }
        hasReceivedInitialAuthState = true
        let waiters = initialAuthStateWaiters
        initialAuthStateWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitForInitialAuthState() async {
        guard !hasReceivedInitialAuthState else { return }
        await withCheckedContinuation { continuation in
            initialAuthStateWaiters.append(continuation)
        }
    }

    // MARK: Sign in with Apple

    // Firebase requires the raw nonce to be passed back alongside the identity
    // token; only its SHA256 hash is sent to Apple in the request.
    func startSignInWithAppleFlow() -> String {
        randomNonceString()
    }

    func signInWithApple(idTokenString: String, nonce: String, fullName: PersonNameComponents?) async throws -> AuthDataResult {
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: fullName)
        return try await Auth.auth().signIn(with: credential)
    }

    // MARK: Sign in with Google

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AuthDataResult {
        // GIDSignIn.signIn(withPresenting:) raises an uncatchable Objective-C
        // exception (not a Swift error) when no GIDClientID is configured -
        // check up front so a missing CLIENT_ID fails gracefully instead of
        // crashing the app.
        guard GIDSignIn.sharedInstance.configuration != nil else {
            throw AuthenticationError.missingGoogleClientID
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationError.missingGoogleIDToken
        }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        return try await Auth.auth().signIn(with: credential)
    }

    // MARK: Sign in with Email

    // The account is created first and is not rolled back if the
    // verification email fails to send - a send failure is logged, not
    // thrown, so the caller still gets back a valid signed-in account. The
    // "check your inbox" screen's resend button is the recovery path for a
    // failed send.
    func signUp(withEmail email: String, password: String) async throws -> AuthDataResult {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        do {
            try await result.user.sendEmailVerification()
        } catch {
            print("Failed to send initial verification email: \(error)")
        }
        return result
    }

    func signIn(withEmail email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: Email verification

    var isCurrentUserEmailVerified: Bool {
        currentUser?.isEmailVerified ?? false
    }

    // A signed-in-but-unverified user only needs to be sent through the
    // verification gate if their account actually carries the
    // emailVerificationRequired custom claim (set by the onUserCreate
    // Cloud Function for accounts created after this feature shipped) -
    // an existing account from before then is unverified too, but was
    // never asked to be, and Firestore's rules already exempt it. Checking
    // isEmailVerified alone would incorrectly gate that grandfathered
    // account on every sign-in. Fails open (returns false) on a token
    // fetch error, since blocking a user we can't confirm needs gating is
    // worse than letting a rules-enforced write fail later.
    func currentUserRequiresEmailVerificationGate() async -> Bool {
        guard let user = currentUser, !user.isEmailVerified else { return false }
        do {
            let tokenResult = try await user.getIDTokenResult()
            return tokenResult.claims["emailVerificationRequired"] as? Bool == true
        } catch {
            print("Failed to fetch ID token claims: \(error)")
            return false
        }
    }

    func resendVerificationEmail() async throws {
        guard let user = currentUser else { throw AuthenticationError.notSignedIn }
        // Reload first - the cached user.isEmailVerified won't reflect a
        // link the user already clicked in another tab/device.
        try await user.reload()
        if Auth.auth().currentUser?.isEmailVerified == true {
            throw EmailVerificationError.alreadyVerified
        }
        do {
            try await user.sendEmailVerification()
        } catch let error as NSError where AuthErrorCode(rawValue: error.code) == .tooManyRequests {
            throw EmailVerificationError.tooManyRequests
        }
    }

    // Firebase doesn't push isEmailVerified updates to an existing session
    // automatically - reload() re-fetches the account's current state, and
    // forcing a token refresh afterward picks up both that flag and any
    // custom claims (e.g. emailVerificationRequired) a Cloud Function may
    // have changed server-side since sign-in. Call this from an "I've
    // verified, continue" button after the user reports clicking the link.
    @discardableResult
    func reloadAndCheckEmailVerified() async throws -> Bool {
        guard let user = currentUser else { throw AuthenticationError.notSignedIn }
        try await user.reload()
        _ = try await user.getIDTokenResult(forcingRefresh: true)
        return Auth.auth().currentUser?.isEmailVerified ?? false
    }

    // MARK: Sign out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: Delete account & data

    // Wipes the Firestore-backed data this uid owns, then deletes the Auth
    // account itself. Firebase requires a "recent" sign-in for account
    // deletion (Auth.Error.Code.requiresRecentLogin) - callers should surface
    // that error by asking the user to sign in again and retry, not treat it
    // as a generic failure.
    func deleteAccountAndAllData() async throws {
        guard let uid, let user = currentUser else {
            throw AuthenticationError.notSignedIn
        }
        let db = Firestore.firestore()
        try await deleteAllDocuments(in: db.collection("users").document(uid).collection("doses"))
        try await deleteAllDocuments(in: db.collection("users").document(uid).collection("sharedPeople"))
        try await deleteAllDocuments(in: db.collection("users").document(uid).collection("medications"))
        try await db.collection("users").document(uid).delete()
        UserProfileStore.shared.reset()
        MedicationStore.shared.deleteAllLocalData()
        SharedPeopleStore.shared.reset()
        try await user.delete()
    }

    private func deleteAllDocuments(in collection: CollectionReference) async throws {
        let snapshot = try await collection.getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    // MARK: Nonce helpers (standard Firebase Sign in with Apple boilerplate)

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            fatalError("Unable to generate nonce: SecRandomCopyBytes failed with OSStatus \(status)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    nonisolated static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
