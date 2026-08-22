import Foundation
import FirebaseFirestore

// MARK: - Calendar Persistence Manager

// Single owner of dose-schedule state: an in-memory cache backed by
// Firestore through CalendarRemoteStore, conforming to FirestoreCacheStore
// like UserProfileStore/MedicationStore/SharedPeopleStore - but "fetch"
// means "subscribe" here rather than a one-shot read. Dose entries are
// stored one document per medication, so instead of a single uid-scoped
// fetch, fetchIfNeeded() starts a live Firestore listener per medication
// currently known to MedicationStore, plus the recurring missed-dose
// check. New medications added later get their listener started directly by
// save(schedule:) (called from MedicationStore.update(_:)), not by
// re-running fetchIfNeeded().
//
// @Published (not a plain cache dictionary) so views observe changes
// directly - see TodayView/WeeklyProgressView, which hold this as
// @ObservedObject rather than reaching into CalendarPersistenceManager.shared
// from inside their body and hoping some unrelated state change triggers a
// re-render.
final class CalendarPersistenceManager: ObservableObject, FirestoreCacheStore {
    static let shared = CalendarPersistenceManager()
    @Published private(set) var entriesByMedicationId: [UUID: [DoseEntry]] = [:]
    private var listeners: [UUID: ListenerRegistration] = [:]
    private var missedCheckTimer: Timer?
    private var hasFetched = false
    private let remoteStore: CalendarRemoteStore

    // Not private: `.shared` is still the only instance the app itself
    // constructs (always with the real Firestore-backed remoteStore), but
    // tests need an isolated fake to exercise save(schedule:)/updateStatus
    // without live Firebase.
    init(remoteStore: CalendarRemoteStore = FirestoreCalendarRemoteStore()) {
        self.remoteStore = remoteStore
    }

    static func decideFetch(hasFetched: Bool, uid: String?) -> FirestoreFetchDecision {
        decideFirestoreFetch(hasFetched: hasFetched, uid: uid)
    }

    // Starts a listener for every medication MedicationStore currently
    // knows about, plus the recurring missed-dose check - once per sign-in.
    // Must run after MedicationStore.fetchIfNeeded() has populated
    // `medications` (see TABIApp's launch task); this store doesn't fetch
    // medications itself.
    func fetchIfNeeded() async {
        switch Self.decideFetch(hasFetched: hasFetched, uid: AuthenticationManager.shared.uid) {
        case .skipAlreadyFetched:
            return
        case .skipNoSignedInUser:
            print("CalendarPersistenceManager: skipping fetch - no signed-in user")
        case .fetch:
            hasFetched = true
            startMonitoringCurrentMedications()
        }
    }

    func invalidate() {
        hasFetched = false
    }

    private func startMonitoringCurrentMedications() {
        for med in MedicationStore.shared.medications { startListening(for: med.id) }
        missedCheckTimer?.invalidate()
        // Re-scans every minute to catch doses that go overdue while the app
        // sits open with no other Firestore write to trigger a snapshot
        // listener. Reads MedicationStore.shared.medications live on each
        // tick (rather than a snapshot captured here) so medications added
        // after this fires are still covered.
        missedCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.markMissedIfOverdue(medications: MedicationStore.shared.medications)
        }
    }

    func save(schedule: DoseSchedule) {
        var entries = loadAll(forMedicationId: schedule.medicationId)
        entries.removeAll { if case .upcoming = $0.status { return true }; return false }
        entries.append(contentsOf: schedule.buildEntries())
        persist(entries, id: schedule.medicationId)
        startListening(for: schedule.medicationId)
    }

    func loadAll(forMedicationId id: UUID) -> [DoseEntry] {
        entriesByMedicationId[id] ?? []
    }

    func loadEntries(forMonth date: Date, medications: [Medication]) -> [DoseEntry] {
        let cal = Calendar.current
        return medications.flatMap { med in loadAll(forMedicationId: med.id).filter { cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .month) } }
    }

    func loadEntries(forDay date: Date, medications: [Medication]) -> [DoseEntry] {
        let cal = Calendar.current
        return medications.flatMap { med in loadAll(forMedicationId: med.id).filter { cal.isDate($0.scheduledDate, inSameDayAs: date) } }.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    func updateStatus(entryId: UUID, medicationId: UUID, status: DoseStatus) {
        var entries = loadAll(forMedicationId: medicationId)
        if let i = entries.firstIndex(where: { $0.id == entryId }) { entries[i].status = status; persist(entries, id: medicationId) }
    }

    func markMissedIfOverdue(medications: [Medication]) {
        for med in medications { checkMissed(for: med.id) }
    }

    // Flips overdue `.upcoming` entries to `.missed` and fires a caretaker
    // alert for each one newly missed. See `applyingMissedStatus` for why a
    // re-run (e.g. the listener re-firing after `persist` below) won't
    // re-alert for a dose already marked missed.
    private func checkMissed(for id: UUID) {
        let (updated, newlyMissed) = loadAll(forMedicationId: id).applyingMissedStatus()
        if !newlyMissed.isEmpty { persist(updated, id: id) }
        for entry in newlyMissed { MissedDoseAlertService.shared.sendAlert(for: entry) }
    }

    func startListening(for id: UUID) {
        guard listeners[id] == nil, let uid = AuthenticationManager.shared.uid else { return }
        listeners[id] = remoteStore.listenToEntries(uid: uid, medicationId: id) { [weak self] entries in
            guard let self else { return }
            self.entriesByMedicationId[id] = entries
            self.checkMissed(for: id)
        }
    }

    private func persist(_ entries: [DoseEntry], id: UUID) {
        entriesByMedicationId[id] = entries
        Task {
            guard let uid = AuthenticationManager.shared.uid else { return }
            do {
                try await remoteStore.saveEntries(uid: uid, medicationId: id, entries: entries)
            } catch {
                print("CalendarPersistenceManager: failed to save dose entries - \(error.localizedDescription)")
            }
        }
    }
}
