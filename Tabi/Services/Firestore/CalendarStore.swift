import Foundation
import FirebaseFirestore

// MARK: - Calendar Store

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
// @ObservedObject rather than reaching into CalendarStore.shared
// from inside their body and hoping some unrelated state change triggers a
// re-render.
final class CalendarStore: ObservableObject, FirestoreCacheStore {
    static let shared = CalendarStore()
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
            print("CalendarStore: skipping fetch - no signed-in user")
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
        // listener, and to keep each medication's persisted DoseEntry window
        // rolling forward (see extendScheduleIfNeeded). Reads
        // MedicationStore.shared.medications live on each tick (rather than
        // a snapshot captured here) so medications added after this fires
        // are still covered.
        missedCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let medications = MedicationStore.shared.medications
            self.markMissedIfOverdue(medications: medications)
            for med in medications { self.extendScheduleIfNeeded(for: med) }
        }
    }

    // How many days of runway must remain before the window gets pushed
    // forward. A medication added once and never edited would otherwise
    // stop having any DoseEntry documents past its original add-time
    // MedicationScheduleParser.scheduleWindowDays horizon - not "no dose
    // taken", but literally no record at all, which reads to the Calendar
    // month view and the missed-dose check as "not scheduled." This keeps
    // the window genuinely rolling instead of a one-time allocation.
    static let scheduleExtensionThresholdDays = 7

    // Pure decision logic, kept separate from the Firestore write below so
    // it's testable without live Firebase - same shape as decideFetch.
    // Returns nil when there's still enough runway to skip extending.
    static func decideExtension(horizon: Date, now: Date = Date(), windowDays: Int = MedicationScheduleParser.scheduleWindowDays, extendWhenWithinDays: Int = scheduleExtensionThresholdDays) -> (startDate: Date, endDate: Date)? {
        let cal = Calendar.current
        guard let thresholdDate = cal.date(byAdding: .day, value: extendWhenWithinDays, to: now), horizon < thresholdDate else { return nil }
        guard let newStart = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: horizon)),
              let newEnd = cal.date(byAdding: .day, value: windowDays, to: now),
              newStart <= newEnd else { return nil }
        return (startDate: newStart, endDate: newEnd)
    }

    // Appends fresh `.upcoming` entries beyond the medication's current
    // furthest-out entry, rather than rebuilding the whole window like
    // save(schedule:) does - existing taken/skipped/missed history and
    // near-term upcoming entries are untouched.
    private func extendScheduleIfNeeded(for medication: Medication) {
        let existing = loadAll(forMedicationId: medication.id)
        guard let horizon = existing.map(\.scheduledDate).max(),
              let decision = Self.decideExtension(horizon: horizon) else { return }

        let schedule = DoseSchedule(
            medicationId: medication.id, medicationName: medication.name,
            medicationEmoji: medication.emoji, dosage: medication.dosage,
            colorIndex: medication.colorIndex,
            scheduledTimes: MedicationScheduleParser.times(for: medication.resolvedDoseTimeMinutes),
            startDate: decision.startDate, endDate: decision.endDate
        )
        persist(existing + schedule.buildEntries(), id: medication.id)
    }

    func save(schedule: DoseSchedule) {
        var entries = loadAll(forMedicationId: schedule.medicationId)
        entries.removeAll { if case .upcoming = $0.status { return true }; return false }
        entries.append(contentsOf: schedule.buildEntries())
        persist(entries, id: schedule.medicationId)
        startListening(for: schedule.medicationId)
    }

    // Called from MedicationStore.remove(_:) so a removed medication's dose
    // history doesn't outlive it as an orphaned doses/{medicationId} doc.
    // Without this, the server-side checkMissedDoses Cloud Function - which
    // scans every doses doc it can find (functions/index.js), unlike this
    // client's markMissedIfOverdue which only ever looks at medications
    // MedicationStore currently knows about - would keep finding it forever
    // and could fire a caretaker alert for a medication the user explicitly
    // deleted.
    func remove(medicationId: UUID) {
        listeners[medicationId]?.remove()
        listeners[medicationId] = nil
        entriesByMedicationId[medicationId] = nil
        Task {
            guard let uid = AuthenticationManager.shared.uid else { return }
            do {
                try await remoteStore.deleteEntries(uid: uid, medicationId: medicationId)
            } catch {
                print("CalendarStore: failed to delete dose entries - \(error.localizedDescription)")
            }
        }
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

    // Detects overdue `.upcoming` entries and fires a caretaker alert for
    // each one - the client's fast path, running every 60s/on every
    // listener snapshot while the app is open. Deliberately does NOT
    // persist the flip to `.missed` anymore: that's now written exclusively
    // by the server-side checkMissedDoses Cloud Function (functions/index.js,
    // hourly). Two independent writers (this client, that function) both
    // doing read-then-overwrite-the-whole-array on the same doc is a lost-
    // update race - a `.taken`/`.skipped` tap landing between the other
    // side's read and write would get silently reverted. The client can't
    // coordinate with the server's schedule, so the safe fix is for it to
    // simply never write `.missed`; the entry stays `.upcoming` in Firestore
    // until the server's next run catches up (see
    // MedicationStore.earliestUnresolvedEntry, which matches `.missed` too
    // so a late Taken/Skip tap still overrides whatever the server wrote).
    //
    // Because this never persists the flip, the same overdue entry reads as
    // "newly missed" on every single call while the app stays open and the
    // dose remains unresolved - MissedDoseAlertService.sendAlert relies on a
    // deterministic Firestore doc ID (not this function) to avoid spamming
    // repeat alerts; see its doc comment.
    private func checkMissed(for id: UUID) {
        let (_, newlyMissed) = loadAll(forMedicationId: id).applyingMissedStatus()
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
                print("CalendarStore: failed to save dose entries - \(error.localizedDescription)")
            }
        }
    }
}
