import Foundation
import FirebaseFirestore

// MARK: - Calendar Remote Store

// The Firestore boundary for dose entries, pulled out as a protocol (mirrors
// MedicationRemoteStore/UserProfileRemoteStore/SharedPeopleRemoteStore) so
// CalendarStore's fetch/save/listen logic can run against a
// fake in unit tests. `FirestoreCalendarRemoteStore` is the only conformance
// the app itself uses - production always talks to real Firestore.
//
// One document per medication (`users/{uid}/doses/{medicationId}`), unlike
// the other three remote stores' single collection - hence `medicationId`
// on every method, and `listenToEntries` alongside the usual fetch/save
// (dose entries are kept live via a Firestore listener, not pulled once -
// see CalendarStore/FirestoreCacheStore).
protocol CalendarRemoteStore {
    func fetchEntries(uid: String, medicationId: UUID) async throws -> [DoseEntry]
    func saveEntries(uid: String, medicationId: UUID, entries: [DoseEntry]) async throws
    func listenToEntries(uid: String, medicationId: UUID, onChange: @escaping ([DoseEntry]) -> Void) -> ListenerRegistration
}

// Wraps the `{ entries: [...] }` document shape so encode/decode can go
// through FirestoreHelpers.swift's firestoreDict()/decoded(from:) like every
// other model, instead of hand-rolling JSONEncoder -> JSONSerialization (see
// .claude/rules/firestore.md's gotcha on this).
private struct DoseEntriesDocument: Codable {
    var entries: [DoseEntry]
}

struct FirestoreCalendarRemoteStore: CalendarRemoteStore {
    private func docRef(uid: String, medicationId: UUID) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid).collection("doses").document(medicationId.uuidString)
    }

    func fetchEntries(uid: String, medicationId: UUID) async throws -> [DoseEntry] {
        guard let data = try await docRef(uid: uid, medicationId: medicationId).getDocument().data() else { return [] }
        return DoseEntriesDocument.decoded(from: data)?.entries ?? []
    }

    func saveEntries(uid: String, medicationId: UUID, entries: [DoseEntry]) async throws {
        guard let dict = DoseEntriesDocument(entries: entries).firestoreDict() else { return }
        try await docRef(uid: uid, medicationId: medicationId).setData(dict)
    }

    func listenToEntries(uid: String, medicationId: UUID, onChange: @escaping ([DoseEntry]) -> Void) -> ListenerRegistration {
        docRef(uid: uid, medicationId: medicationId).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data(), let doc = DoseEntriesDocument.decoded(from: data) else { return }
            onChange(doc.entries)
        }
    }
}
