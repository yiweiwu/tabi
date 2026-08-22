import Foundation
import FirebaseFirestore

// MARK: - Shared People Remote Store

// The Firestore boundary for shared connections, pulled out as a protocol
// (mirrors MedicationRemoteStore/UserProfileRemoteStore) so SharedPeopleStore's
// fetch/save/delete logic can run against a fake in unit tests.
// `FirestoreSharedPeopleRemoteStore` is the only conformance the app itself
// uses - production always talks to real Firestore.
protocol SharedPeopleRemoteStore {
    func fetchSharedPeople(uid: String) async throws -> [SharedPerson]
    func saveSharedPerson(uid: String, person: SharedPerson) async throws
    func deleteSharedPerson(uid: String, personId: UUID) async throws
}

struct FirestoreSharedPeopleRemoteStore: SharedPeopleRemoteStore {
    private func collection(uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("sharedPeople")
    }

    func fetchSharedPeople(uid: String) async throws -> [SharedPerson] {
        let snapshot = try await collection(uid: uid).getDocuments()
        return snapshot.documents.compactMap { SharedPerson.decoded(from: $0.data()) }
    }

    func saveSharedPerson(uid: String, person: SharedPerson) async throws {
        guard let dict = person.firestoreDict() else { return }
        try await collection(uid: uid).document(person.id.uuidString).setData(dict)
    }

    func deleteSharedPerson(uid: String, personId: UUID) async throws {
        try await collection(uid: uid).document(personId.uuidString).delete()
    }
}
