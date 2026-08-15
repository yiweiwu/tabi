# CLAUDE.md — Tabi/Services

Firestore-specific conventions for this directory. Loads automatically when working in `Services/` (or `ViewModels/MedicationManager.swift`, which reads Firestore-backed state) so the root `CLAUDE.md` doesn't have to carry this for every unrelated task. `firestore.rules` itself lives at the repo root but is governed by these same conventions.

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
- `users/{uid}/sharedPeople/{id}`
- `users/{uid}` (the profile fields live directly on this document, via `UserProfileStore` — not `MedicationManager`, which only reads it)

## Firestore Gotchas

- Use `FirestoreHelpers.swift`'s `firestoreDict()`/`decoded(from:)` extensions on `Encodable`/`Decodable` instead of writing inline `JSONEncoder → JSONSerialization` in any new Firestore persistence code.
- New Firestore collections need an explicit `match` rule in `firestore.rules` — the default is deny-all, and a missing rule fails silently (client write is rejected, no error surfaced). This applies in particular to any collection that triggers an SMS-sending Cloud Function.
- Editing `firestore.rules` only changes the local file — it has no effect on the live project until deployed with `firebase deploy --only firestore:rules --project tabi-47030`. A merged rules change that was never deployed is indistinguishable from a missing rule: both silently reject the client write.
- Never swallow a Firestore error (bare `try?`, a fire-and-forget `setData`/`addDocument` that ignores its `error` parameter) — a `permission-denied` from a rules mismatch then looks identical to "no data yet," which is exactly what let a real bug (the deploy gap above) go unnoticed until user data silently disappeared. At minimum `print()` it — see `UserProfileStore.persist()`/`fetchIfNeeded()` for the pattern.
