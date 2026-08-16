import Foundation
import FirebaseFirestore

// MARK: - Medication Remote Store

// The Firestore boundary for medications, pulled out as a protocol (mirrors
// UserProfileRemoteStore in UserProfileStore.swift) so MedicationManager's
// fetch/save/delete logic can run against a fake in unit tests.
// `FirestoreMedicationRemoteStore` is the only conformance the app itself
// uses - production always talks to real Firestore.
protocol MedicationRemoteStore {
    func fetchMedications(uid: String) async throws -> [Medication]
    func saveMedication(uid: String, medication: Medication) async throws
    func deleteMedication(uid: String, medicationId: UUID) async throws
}

struct FirestoreMedicationRemoteStore: MedicationRemoteStore {
    private func collection(uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("medications")
    }

    func fetchMedications(uid: String) async throws -> [Medication] {
        let snapshot = try await collection(uid: uid).getDocuments()
        return snapshot.documents.compactMap { Medication.decoded(from: $0.data()) }
    }

    // Full overwrite (no merge) - MedicationManager always holds the
    // complete Medication struct in memory before calling this, same as
    // CalendarPersistenceManager.persist() does for dose entries.
    func saveMedication(uid: String, medication: Medication) async throws {
        guard let dict = medication.firestoreDict() else { return }
        try await collection(uid: uid).document(medication.id.uuidString).setData(dict)
    }

    func deleteMedication(uid: String, medicationId: UUID) async throws {
        try await collection(uid: uid).document(medicationId.uuidString).delete()
    }
}
