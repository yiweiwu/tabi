import Testing
import Foundation
@testable import Tabi

// MARK: - Medication Sync Tests

// Covers MedicationManager's Firestore sync, mirroring UserProfileLoadingTests
// for UserProfileStore - in-memory cache + Firestore, no ongoing local
// cache. AuthenticationManager.shared.uid needs live Firebase (no
// FirebaseApp is configured in TabiTests - see testing.md), so
// fetchIfNeeded() itself can't run here; decideFetch and performFetch(uid:)
// can, exercised directly against a fake MedicationRemoteStore and an
// isolated UserDefaults suite (never UserDefaults.standard, so tests can't
// read or pollute a real device's saved medications).
//
// The one genuinely new risk here versus UserProfileStore: medications used
// to be stored in UserDefaults before Firestore-backed sync existed, so an
// existing install's data has to be migrated up exactly once rather than
// silently going dark. The legacy-migration tests below are what protect
// against that.
@Suite
struct MedicationSyncTests {

    private func makeMedication(name: String = "Lisinopril") -> Medication {
        Medication(name: name, type: "Tablet", emoji: "💊", dosage: "10mg", scheduleLabel: "Once Daily", points: 10)
    }

    private func freshDefaults() -> UserDefaults {
        let suiteName = "MedicationSyncTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func seedLegacyLocalMedications(_ medications: [Medication], in defaults: UserDefaults) throws {
        let encoded = try JSONEncoder().encode(medications)
        defaults.set(encoded, forKey: MedicationManager.legacyMedicationsKey)
    }

    // MARK: fetchIfNeeded's decision logic

    @Test("Already-fetched sessions skip, regardless of uid")
    func testAlreadyFetchedSkipsEvenWithAUser() throws {
        #expect(MedicationManager.decideFetch(hasFetched: true, uid: "user-123") == .skipAlreadyFetched)
        #expect(MedicationManager.decideFetch(hasFetched: true, uid: nil) == .skipAlreadyFetched)
    }

    @Test("No signed-in user skips instead of fetching")
    func testNoUserSkipsWithoutMarkingFetched() throws {
        #expect(MedicationManager.decideFetch(hasFetched: false, uid: nil) == .skipNoSignedInUser)
    }

    @Test("A signed-in, not-yet-fetched session proceeds to fetch that uid")
    func testSignedInNotYetFetchedProceedsToFetch() throws {
        #expect(MedicationManager.decideFetch(hasFetched: false, uid: "user-123") == .fetch(uid: "user-123"))
    }

    // MARK: performFetch - adopting Firestore as truth

    @Test("A non-empty Firestore fetch populates the in-memory medication list")
    func testFetchAdoptsNonEmptyRemote() async throws {
        let remote = FakeMedicationRemoteStore()
        let remoteMed = makeMedication(name: "Lisinopril")
        remote.medicationsToReturn = [remoteMed]
        let manager = MedicationManager(remoteStore: remote, userDefaults: freshDefaults())

        await manager.performFetch(uid: "user-123")

        #expect(manager.medications.map(\.id) == [remoteMed.id])
    }

    @Test("A fetch failure leaves the in-memory list untouched rather than crashing or clearing it")
    func testFetchFailureLeavesStateUntouched() async throws {
        struct FakeNetworkError: Error {}
        let remote = FakeMedicationRemoteStore()
        remote.fetchError = FakeNetworkError()
        let manager = MedicationManager(remoteStore: remote, userDefaults: freshDefaults())

        await manager.performFetch(uid: "user-123")

        #expect(manager.medications.isEmpty)
    }

    // MARK: performFetch - one-time legacy migration

    @Test("Medications saved locally before Firestore sync existed are uploaded once, then shown")
    func testMigratesLegacyLocalMedicationsWhenRemoteEmpty() async throws {
        let remote = FakeMedicationRemoteStore()
        remote.medicationsToReturn = []
        let defaults = freshDefaults()
        let legacy = makeMedication(name: "Metformin")
        try seedLegacyLocalMedications([legacy], in: defaults)
        let manager = MedicationManager(remoteStore: remote, userDefaults: defaults)

        await manager.performFetch(uid: "user-123")

        #expect(remote.savedMedications.map(\.id) == [legacy.id])
        #expect(manager.medications.map(\.id) == [legacy.id])
        #expect(defaults.data(forKey: MedicationManager.legacyMedicationsKey) == nil, "the legacy key should be cleared once every medication has migrated")
    }

    @Test("A partially failed migration leaves the legacy key in place so it retries in full next launch")
    func testPartialMigrationFailureKeepsLegacyKey() async throws {
        let remote = FakeMedicationRemoteStore()
        remote.medicationsToReturn = []
        let willFail = makeMedication(name: "WillFailToUpload")
        remote.failSaveForMedicationId = willFail.id
        let defaults = freshDefaults()
        try seedLegacyLocalMedications([makeMedication(name: "Succeeds"), willFail], in: defaults)
        let manager = MedicationManager(remoteStore: remote, userDefaults: defaults)

        await manager.performFetch(uid: "user-123")

        #expect(
            defaults.data(forKey: MedicationManager.legacyMedicationsKey) != nil,
            "if the legacy key were cleared after a partial failure, the medication that failed to upload would be lost - the next launch wouldn't know to retry it"
        )
    }

    @Test("No legacy local data and an empty Firestore is a no-op, not a crash")
    func testNoLegacyDataAndEmptyRemoteIsANoOp() async throws {
        let remote = FakeMedicationRemoteStore()
        remote.medicationsToReturn = []
        let manager = MedicationManager(remoteStore: remote, userDefaults: freshDefaults())

        await manager.performFetch(uid: "user-123")

        #expect(remote.savedMedications.isEmpty)
        #expect(manager.medications.isEmpty)
    }

    @Test("An empty legacy array in UserDefaults is treated the same as no legacy data at all")
    func testEmptyLegacyArrayIsANoOp() async throws {
        let remote = FakeMedicationRemoteStore()
        remote.medicationsToReturn = []
        let defaults = freshDefaults()
        try seedLegacyLocalMedications([], in: defaults)
        let manager = MedicationManager(remoteStore: remote, userDefaults: defaults)

        await manager.performFetch(uid: "user-123")

        #expect(remote.savedMedications.isEmpty)
        #expect(manager.medications.isEmpty)
    }
}

// MARK: - Fake Remote Store

private final class FakeMedicationRemoteStore: MedicationRemoteStore {
    var medicationsToReturn: [Medication] = []
    var fetchError: Error?
    var failSaveForMedicationId: UUID?
    private(set) var savedMedications: [Medication] = []
    private(set) var deletedMedicationIds: [UUID] = []

    private struct SaveFailed: Error {}

    func fetchMedications(uid: String) async throws -> [Medication] {
        if let fetchError { throw fetchError }
        return medicationsToReturn
    }

    func saveMedication(uid: String, medication: Medication) async throws {
        if medication.id == failSaveForMedicationId { throw SaveFailed() }
        savedMedications.append(medication)
    }

    func deleteMedication(uid: String, medicationId: UUID) async throws {
        deletedMedicationIds.append(medicationId)
    }
}
