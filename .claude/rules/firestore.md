---
paths:
  - "Tabi/Services/Firestore/**"
  - "Tabi/ViewModels/MedicationStore.swift"
  - "Tabi/Models/UserProfile.swift"
  - "Tabi/Views/Profile/**"
  - "Tabi/Views/Onboarding/**"
  - "Tabi/Views/Sharing/**"
  - "firestore.rules"
  - "firestore.indexes.json"
  - "functions/**"
---

# Firestore Conventions

## Firestore Data Rules

All app state is persisted to Firestore (no UserDefaults). Before adding a field to any `Codable` struct, ask:

1. **Does it need to outlive the current app session?** If not, don't store it.
2. **Is it derived from other stored fields?** If yes, compute it at read time instead.
3. **Is it UI-only?** Colors, icons, display strings, and `colorIndex` belong in the view layer — not in Firestore documents.

### Adding a new field is the last resort

Before adding a field, always check whether the answer can be read from data that already exists:
- `DoseEntry.scheduledDate` encodes when a medication became active (entries only exist from the add date forward) — no need for a separate `createdAt` field on `Medication`.
- `medication.takenTodayCount` + `frequencyPerDay` encodes today's progress — no need to store a separate "remaining" count.

Every extra field is a new source of discrepancy. If existing data can answer the question, use it. Only add a field when the information genuinely cannot be derived at read time.

Stored models: `Medication`, `DoseEntry`, `SharedPerson`, `UserProfile`. Firestore paths are scoped by the signed-in Firebase Auth uid (`AuthenticationManager.shared.uid`), not a device ID:
- `users/{uid}/medications/{id}`
- `users/{uid}/doses/{medicationId}` (contains `entries` array)
- `users/{uid}/sharedPeople/{id}` (via `SharedPeopleStore`)
- `users/{uid}` (the profile fields live directly on this document, via `UserProfileStore` — not `MedicationStore`, which only reads it)

## Cache-Aside Stores (`FirestoreCacheStore`)

`UserProfileStore`, `MedicationStore`, `SharedPeopleStore`, and `CalendarPersistenceManager` all conform to `FirestoreCacheStore` (`Tabi/Services/Firestore/FirestoreCacheStore.swift`) - one shared interface for "memcache in front of Firestore":

- `fetchIfNeeded()` populates the cache once per sign-in (guarded by a private `hasFetched`) and is a no-op every call after that. It's called unconditionally from `TABIApp`'s launch `.task` for all four - a store's data must never depend on some specific screen having been opened to exist. That was `SharedPeopleStore`'s original bug: it used to be view-owned `@State` with its own listener, only populated when `SharingView` happened to appear.
- `invalidate()` clears the `hasFetched` guard (without clearing already-loaded data) so the next `fetchIfNeeded()` re-fetches instead of trusting the cache.
- `refresh()` (a protocol extension, free on all four) is `invalidate()` + `fetchIfNeeded()` in one call - use it when a caller needs the *current* Firestore state, not whatever was true at last load.

`CalendarPersistenceManager` bends "fetch" slightly: dose entries are one document per medication, kept live via a Firestore listener rather than pulled with a single request, so `fetchIfNeeded()` there means "start a listener for every medication `MedicationStore` currently knows about, plus the recurring missed-dose check" - not a one-shot read. It has to run *after* `MedicationStore.fetchIfNeeded()` in `TABIApp`'s launch task (it needs `medications` already populated to know which dose documents to subscribe to), so it can't sit inside the same `async let` group as the other three. A medication added later gets its own listener started directly by `save(schedule:)` (called from `MedicationStore.update(_:)`), not by re-running `fetchIfNeeded()`.

Whether a store actually needs `refresh()` depends on who else can write its data:
- `UserProfileStore`/`MedicationStore`/`CalendarPersistenceManager` are only ever mutated by this same signed-in client, through this same app, via optimistic local writes (`MedicationStore.add(_:)` etc.) that already keep the cache correct. Nothing currently calls their `invalidate()`/`refresh()` - there's no external source of staleness to force a re-check against.
- `SharedPeopleStore` is different: `SharedPerson.optInStatus` is flipped from "pending" to "confirmed" server-side by `confirmCaretakerOptIn`, a Cloud Function using the Admin SDK that bypasses this client entirely. So every consumer that needs an accurate read - `SharingView` on appear, `MissedDoseAlertService` before deciding who to alert - calls `refresh()`, not plain `fetchIfNeeded()`. Don't "simplify" either of those call sites to `fetchIfNeeded()`; that would silently start trusting a session-old opt-in status again.

## User Profile Data

`UserProfileStore.shared.profile` is the one home for profile data (per the Data ownership rule in root `CLAUDE.md`) — never give a profile field a second local copy that only syncs back on some later "save"/"complete" step. Two real bugs came from violating this:

- `UserSettings.emailAddress` was a dead, always-blank field duplicating a value already available live from `AuthenticationManager.shared.currentUser?.email`. It just sat there unread/unwritten - `Tabi/Views/Profile/ProfileView.swift`'s Settings screen now reads the Auth email directly instead.
- `OnboardingCoordinator` (`Tabi/Views/Onboarding/OnboardingFlow.swift`) buffered `firstName`/`lastName`/`age`/`selectedGender` in its own local `@Observable` state across the *entire* onboarding flow, only writing them into `UserProfileStore` in `completeOnboarding()` - the very last step. Backgrounding or killing the app anywhere between `ProfileSetupPageView` and the final "Start Using Tabi" tap silently lost whatever the user had typed, since a fresh `OnboardingCoordinator` is created on relaunch. Fixed by syncing to `UserProfileStore` as soon as the user leaves `ProfileSetupPageView` (on Continue, swipe, or Skip - all funnel through `nextPage()`), not just at the end.

A short-lived edit buffer confined to one screen (e.g. `EditProfileSheet`'s `@State` fields, committed to `UserProfileStore` on "Save") is fine. A buffer that spans multiple screens or a multi-step flow is not - sync it at every step, not just the last one.

## Firestore Gotchas

- Use `FirestoreHelpers.swift`'s `firestoreDict()`/`decoded(from:)` extensions on `Encodable`/`Decodable` instead of writing inline `JSONEncoder → JSONSerialization` in any new Firestore persistence code.
- New Firestore collections need an explicit `match` rule in `firestore.rules` — the default is deny-all, and a missing rule fails silently (client write is rejected, no error surfaced). This applies in particular to any collection that triggers an SMS-sending Cloud Function.
- Editing `firestore.rules` only changes the local file — it has no effect on the live project until deployed with `firebase deploy --only firestore:rules --project tabi-47030`. A merged rules change that was never deployed is indistinguishable from a missing rule: both silently reject the client write.
- Never swallow a Firestore error (bare `try?`, a fire-and-forget `setData`/`addDocument` that ignores its `error` parameter) — a `permission-denied` from a rules mismatch then looks identical to "no data yet," which is exactly what let a real bug (the deploy gap above) go unnoticed until user data silently disappeared. At minimum `print()` it — see `UserProfileStore.persist()`/`fetchIfNeeded()` for the pattern.
- `MissedDoseAlertService`/`ConnectionConfirmationService` write docs that a Cloud Function (`functions/index.js`) picks up to send SMS. All outbound SMS goes through `sendSms()` there, which appends the AWS toll-free/10DLC-required "Reply STOP to unsubscribe, HELP for help." footer to every message — don't add that language at a call site (client or function), it's enforced once, centrally, so it can't be dropped by a future caller.
