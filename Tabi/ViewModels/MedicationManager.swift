import SwiftUI
import UIKit

// MARK: - Medication Manager

// Single owner of medication state: an in-memory cache backed by Firestore,
// mirroring UserProfileStore's pattern exactly (see
// fetchIfNeeded()/performFetch(uid:) below). A singleton (like
// UserProfileStore), passed down as @ObservedObject from ContentView rather
// than recreated.
class MedicationManager: ObservableObject {
    static let shared = MedicationManager()

    @Published var medications: [Medication] = []
    @Published var gameStats = GameStats()

    // Read-only: UserProfileStore owns profile state (in-memory cache +
    // Firestore persistence). MedicationManager never fetches, caches, or
    // writes profile data itself - views that need to edit the profile
    // observe UserProfileStore directly (see ProfileView).
    var userProfile: UserProfile { UserProfileStore.shared.profile }

    private let userDefaults: UserDefaults
    // UserDefaults was medications' only storage before Firestore-backed
    // sync existed. It's not used as an ongoing cache anymore - this key is
    // read (and then cleared) exactly once, in migrateLegacyLocalMedicationsIfNeeded
    // below, purely to carry an existing install's data into Firestore.
    static let legacyMedicationsKey = "savedMedications"
    private let remoteStore: MedicationRemoteStore
    private var hasFetched = false

    // Not private: `.shared` is still the only instance the app itself
    // constructs (always with the real Firestore-backed remoteStore and
    // .standard defaults), but tests need an isolated UserDefaults suite to
    // exercise the legacy migration without touching a real device's data,
    // and SwiftUI previews need their own instance too.
    init(remoteStore: MedicationRemoteStore = FirestoreMedicationRemoteStore(), userDefaults: UserDefaults = .standard) {
        self.remoteStore = remoteStore
        self.userDefaults = userDefaults
    }

    // MARK: - Firestore sync

    // What fetchIfNeeded should do, given its two inputs, kept as a pure
    // decision separate from the Firestore I/O below - mirrors
    // UserProfileStore.decideFetch for the same reason (testable without
    // live Firebase).
    enum FetchDecision: Equatable {
        case skipAlreadyFetched
        case skipNoSignedInUser
        case fetch(uid: String)
    }

    static func decideFetch(hasFetched: Bool, uid: String?) -> FetchDecision {
        guard !hasFetched else { return .skipAlreadyFetched }
        guard let uid else { return .skipNoSignedInUser }
        return .fetch(uid: uid)
    }

    // One-shot fetch into the in-memory cache, called from TABIApp's launch
    // .task alongside UserProfileStore.fetchIfNeeded().
    func fetchIfNeeded() async {
        switch Self.decideFetch(hasFetched: hasFetched, uid: AuthenticationManager.shared.uid) {
        case .skipAlreadyFetched:
            return
        case .skipNoSignedInUser:
            print("MedicationManager: skipping fetch - no signed-in user")
        case .fetch(let uid):
            hasFetched = true
            await performFetch(uid: uid)
        }
    }

    // Not private: exercised directly in unit tests against a fake
    // remoteStore, bypassing fetchIfNeeded()'s AuthenticationManager.uid
    // lookup (which needs live Firebase).
    func performFetch(uid: String) async {
        let remote: [Medication]
        do {
            remote = try await remoteStore.fetchMedications(uid: uid)
        } catch {
            print("MedicationManager: failed to fetch medications - \(error.localizedDescription)")
            return
        }

        guard !remote.isEmpty else {
            await migrateLegacyLocalMedicationsIfNeeded(uid: uid)
            return
        }

        await MainActor.run {
            self.medications = remote
        }
    }

    // One-time upload of medications saved locally before Firestore-backed
    // sync existed. Guarded by the legacy UserDefaults key's presence
    // rather than a separate flag: once every medication uploads
    // successfully, the key is removed, so a later genuinely-empty
    // Firestore fetch (e.g. the user deleted every medication) is trusted
    // instead of re-migrating stale data. A partial failure leaves the key
    // in place, so the next launch retries in full - saveMedication is a
    // full overwrite, so re-uploading an already-succeeded entry is
    // harmless.
    private func migrateLegacyLocalMedicationsIfNeeded(uid: String) async {
        guard let data = userDefaults.data(forKey: Self.legacyMedicationsKey),
              let legacy = try? JSONDecoder().decode([Medication].self, from: data),
              !legacy.isEmpty else { return }

        var allSucceeded = true
        for medication in legacy {
            let succeeded = await persistRemote(medication, uid: uid)
            if !succeeded { allSucceeded = false }
        }
        guard allSucceeded else { return }

        userDefaults.removeObject(forKey: Self.legacyMedicationsKey)
        await MainActor.run {
            self.medications = legacy
        }
    }

    @discardableResult
    private func persistRemote(_ medication: Medication, uid: String? = nil) async -> Bool {
        guard let uid = uid ?? AuthenticationManager.shared.uid else { return false }
        do {
            try await remoteStore.saveMedication(uid: uid, medication: medication)
            return true
        } catch {
            print("MedicationManager: failed to save medication - \(error.localizedDescription)")
            return false
        }
    }

    private func deleteRemote(_ medication: Medication) async {
        guard let uid = AuthenticationManager.shared.uid else { return }
        do {
            try await remoteStore.deleteMedication(uid: uid, medicationId: medication.id)
        } catch {
            print("MedicationManager: failed to delete medication - \(error.localizedDescription)")
        }
    }

    func add(_ medication: Medication) {
        medications.append(medication)
        Task { await persistRemote(medication) }
    }

    private func save(_ medication: Medication) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
        }
        Task { await persistRemote(medication) }
    }

    // Persists an edited medication (name, dosage, frequency, dose times)
    // and regenerates its upcoming schedule/notifications so the new times
    // take effect immediately - past/resolved DoseEntry records are left
    // untouched (see CalendarPersistenceManager.save(schedule:)).
    func update(_ medication: Medication) {
        save(medication)
        let schedule = MedicationScheduleParser.schedule(for: medication, dosage: medication.dosage)
        CalendarPersistenceManager.shared.save(schedule: schedule)
        NotificationScheduler.shared.schedule(for: schedule)
    }

    func startMissedDoseMonitoring() {
        CalendarPersistenceManager.shared.startMonitoring { [weak self] in self?.medications ?? [] }
    }

    func remove(_ medication: Medication) {
        if medications.count == 1 {
            NotificationScheduler.shared.cancelAll()
        } else {
            NotificationScheduler.shared.cancel(for: medication.id)
        }
        medications.removeAll { $0.id == medication.id }
        Task { await deleteRemote(medication) }
    }

    func recordMedicationTaken(_ medication: Medication, points: Int) {
        guard let i = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        var med = medications[i]
        let isNewDay = med.lastTaken.map { !Calendar.current.isDateInToday($0) } ?? true
        if isNewDay { med.takenToday = 0; med.skippedToday = 0 }
        med.takenToday += 1
        med.lastTaken = Date()
        med.streak += 1
        medications[i] = med
        save(med)

        if med.resolvedTodayCount >= med.frequencyPerDay {
            NotificationScheduler.shared.cancelRemainingToday(for: medication.id)
        } else {
            NotificationScheduler.shared.cancelNext(for: medication.id)
        }

        gameStats.totalPoints += points
        gameStats.currentStreak = medications.allSatisfy { !$0.isOverdue } ? gameStats.currentStreak + 1 : 0
        gameStats.level = gameStats.calculatedLevel

        markTodaysDoseTaken(for: med)
    }

    // Marks the earliest still-`.upcoming` DoseEntry for today as `.taken`
    // so the Calendar and Progress views actually reflect a real Taken tap,
    // instead of the entry silently staying `.upcoming` (or later flipping
    // to `.missed`) despite the user having taken the dose.
    private func markTodaysDoseTaken(for medication: Medication) {
        let todaysUpcoming = CalendarPersistenceManager.shared.loadAll(forMedicationId: medication.id)
            .filter { Calendar.current.isDateInToday($0.scheduledDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first { if case .upcoming = $0.status { return true }; return false }
        guard let entry = todaysUpcoming else { return }
        CalendarPersistenceManager.shared.updateStatus(entryId: entry.id, medicationId: medication.id, status: .taken(Date()))
    }

    func recordMedicationSkipped(_ medication: Medication) {
        guard let i = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        var med = medications[i]
        let isNewDay = med.lastTaken.map { !Calendar.current.isDateInToday($0) } ?? true
        if isNewDay { med.takenToday = 0; med.skippedToday = 0 }
        med.skippedToday += 1
        med.lastTaken = Date()
        med.streak = 0
        medications[i] = med
        save(med)

        if med.resolvedTodayCount >= med.frequencyPerDay {
            NotificationScheduler.shared.cancelRemainingToday(for: medication.id)
        } else {
            NotificationScheduler.shared.cancelNext(for: medication.id)
        }

        gameStats.currentStreak = 0

        markTodaysDoseSkipped(for: med)
    }

    // Marks the earliest still-`.upcoming` DoseEntry for today as `.skipped`
    // so the Calendar view reflects the skip and the missed-dose checker
    // doesn't later flip it to `.missed` and fire a false caretaker alert.
    private func markTodaysDoseSkipped(for medication: Medication) {
        let todaysUpcoming = CalendarPersistenceManager.shared.loadAll(forMedicationId: medication.id)
            .filter { Calendar.current.isDateInToday($0.scheduledDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first { if case .upcoming = $0.status { return true }; return false }
        guard let entry = todaysUpcoming else { return }
        CalendarPersistenceManager.shared.updateStatus(entryId: entry.id, medicationId: medication.id, status: .skipped(Date()))
    }

    // Clears everything stored on-device. Firestore-backed data (doses,
    // sharedPeople, medications, the profile doc) is deleted separately via
    // AuthenticationManager.deleteAccountAndAllData() - this only covers
    // what MedicationManager itself owns locally. Resets hasFetched so a
    // subsequent sign-in in the same app session doesn't show stale
    // medications.
    func deleteAllLocalData() {
        NotificationScheduler.shared.cancelAll()
        medications = []
        userDefaults.removeObject(forKey: Self.legacyMedicationsKey)
        gameStats = GameStats()
        hasFetched = false
    }
}
