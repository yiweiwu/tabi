import Foundation
import FirebaseFirestore

// MARK: - User Profile Remote Store

// The Firestore boundary for reading a profile document, pulled out as a
// protocol (mirrors MedicationRemoteStore.swift) so UserProfileStore's
// fetch-and-apply logic can run against a fake in unit tests.
// `FirestoreUserProfileRemoteStore` is the only conformance the app itself
// uses - production always talks to real Firestore.
protocol UserProfileRemoteStore {
    func fetchProfileDocument(uid: String) async throws -> [String: Any]?
}

struct FirestoreUserProfileRemoteStore: UserProfileRemoteStore {
    func fetchProfileDocument(uid: String) async throws -> [String: Any]? {
        try await Firestore.firestore().collection("users").document(uid).getDocument().data()
    }
}
