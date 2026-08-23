---
paths:
  - "Tabi/Views/Today/**"
  - "Tabi/Views/Calendar/**"
  - "Tabi/Models/DoseModels.swift"
  - "Tabi/Models/Medication.swift"
  - "Tabi/Services/MedicationScheduleParser.swift"
  - "Tabi/Services/Firestore/CalendarStore.swift"
  - "Tabi/Services/Firestore/MedicationStore.swift"
---

# Dose Tracking Logic

These invariants must be preserved across any UI change.

## Source of truth
- `medication.takenTodayCount` — how many doses were taken **today**. Computed from `takenToday` (resets on a new day) and `lastTaken` (guards that `takenToday` only counts for today). Both are persisted in Firestore on `Medication`.
- `medication.frequencyPerDay` — total doses scheduled per day, set from Gemini OCR at scan time.

## Mid-day medication add
When a new medication is added mid-day, doses whose scheduled time has already passed are **not** pre-seeded as taken — a dose only becomes `.taken` when the user actually taps Taken. `Medication` is created with `takenToday: 0, lastTaken: nil` regardless of how many scheduled times already passed; the row's `takenButtonState` (`Views/Today/TodayView.swift`) already shows those as `.overdue` (red) rather than `.notStarted`.

For the Calendar view's per-day `DoseEntry` list (`DoseSchedule.buildEntries()` in `Models/DoseModels.swift`), times that already passed on the add day are seeded as `.skipped` rather than `.upcoming` — leaving them `.upcoming` would let the missed-dose check flip them to `.missed` and fire a caretaker SMS alert for a dose that predates when the medication was even added. `.skipped` avoids that false alert while still not showing as `.taken`.

**Example**: twice-daily (8am, 8pm) added at 2pm → 8am shows as overdue (not taken) on the Today row, and as skipped (not taken, no alert) on the Calendar; 8pm still shows as upcoming/remaining.

**Editing a medication again the same day.** `startDate` in `MedicationScheduleParser.schedule(for:dosage:)` is `Date()` at the moment `schedule(for:dosage:)` runs - every edit, not just the first add - so editing a medication again later the same day (e.g. changing a dose time from 8pm to 9pm after 8pm has already passed) re-runs the mid-day-add seeding logic above and produces a fresh `.skipped` entry for whatever's already passed under the *new* schedule. `CalendarStore.save(schedule:)` calls `entriesSurviving(_:regeneratingOn:)` before appending that fresh batch, which drops any `.skipped` entry scoped to that same day (stale seeds from an earlier edit today - e.g. the old 8pm slot, now nonsensical since the dose time changed) while leaving `.taken`/`.missed` entries and any `.skipped` entry from a *past* day (settled history from that day's own mid-day add) untouched. Without this, edits made after the day's dose time had passed would leave stale/duplicate `.skipped` entries behind forever, since nothing else ever cleans them up.

## Display rules (Today view and Calendar view must agree)
| State | Today view | Calendar bar |
|---|---|---|
| All doses taken today | "All done today" (green) | Checkmark |
| Some doses taken today | "N of M doses today" | Remaining count (M − N) |
| Future day | — | Total doses (M) |
| Past day (medication was active) | — | Checkmark |
| Medication not yet added on that day | — | Empty/gray |

**Never show the total frequency count for today** — always show the remaining count. Use `frequencyPerDay - takenTodayCount` for today's bar, `frequencyPerDay` for future bars.

## Calendar active-day check
`TodayView`'s non-today history rows read `CalendarStore.shared.loadAll(forMedicationId:)`/`loadEntries(forDay:medications:)` (held as `@ObservedObject`, per `.claude/rules/firestore.md`'s Cache-Aside Stores section - not called from inside `body` without observing it, or the view won't re-render when the listener pushes an update). A day is active only if dose entries exist for it — meaning the medication had already been added by that date. Do **not** use a simple "any day before today" check, as that would incorrectly mark days before the medication was added.

`WeekCalendarDotGrid`/`MonthCalendarGrid` (`Views/Calendar/CalendarView.swift`) read `Medication` (from `MedicationStore`) and `DoseEntry` (from `CalendarStore.entriesByMedicationId`, passed down from `CalendarView`) directly - `doseDotStatus(for:on:entriesByMedicationId:)` and `aggregateDoseStatus(_:)` (`Models/DoseModels.swift`) turn those into the dot. `DoseDotStatus` only has two cases, `.taken`/`.missed` - the dots deliberately only report on doses that have actually resolved. `DoseStatus.dotStatus` returns `nil` for `.upcoming` (hasn't happened) and `.skipped` (pre-add seed, never actually required - see Mid-day medication add above), and those get filtered out of the day's aggregate entirely rather than shown as a third "scheduled" bucket. A day with no dot means either no `DoseEntry` exists for that medication that day (not yet added, or beyond the persisted window), or everything that day is still unresolved (a same-day dose scheduled for later, or a fully skip-seeded add day) - a day with at least one resolved dose still gets a dot even if other doses that day haven't happened yet. Since `.missed` is now written exclusively by the server-side `checkMissedDoses` Cloud Function (see `.claude/rules/firestore.md`'s Firestore Gotchas), a dose that went overdue a few minutes ago still reads as `.upcoming` (excluded from the aggregate, same as any other unresolved dose) until the next hourly run catches up - don't read a momentarily-blank dot on today as "nothing was missed."

## Rolling dose-entry window

`DoseEntry` documents aren't generated indefinitely into the future - `MedicationScheduleParser.schedule(for:dosage:)` materializes `MedicationScheduleParser.scheduleWindowDays` (30) days of `.upcoming` entries at a time, written by `CalendarStore.save(schedule:)` on add/edit. Left alone, that's a one-time allocation: a medication added once and never edited would run out of entries entirely past day 30 (not "no dose taken" - no record at all).

`CalendarStore`'s existing 60s missed-dose timer (`startMonitoringCurrentMedications`) also calls `extendScheduleIfNeeded(for:)` per medication on every tick, which keeps the window actually rolling: once the furthest-out persisted entry (`horizon`) comes within `CalendarStore.scheduleExtensionThresholdDays` (7) of now, it appends fresh `.upcoming` entries out to a new `now + scheduleWindowDays` horizon - additively, via `persist(existing + schedule.buildEntries(), id:)`, never touching already-persisted entries. `CalendarStore.decideExtension(horizon:now:)` is the pure decision function behind this (mirrors `decideFetch`), tested in `CalendarStoreScheduleExtensionTests` without live Firebase.

This only affects *future* `.upcoming` entries. Once an entry's status flips away from `.upcoming` (`.taken`/`.skipped`/`.missed`), it's permanent - neither `save(schedule:)` nor `extendScheduleIfNeeded` ever deletes or truncates existing entries, so historical dose history has no 30-day limitation. The longer-horizon concern there is unbounded growth of the single `entries` array Firestore document (`users/{uid}/doses/{medicationId}`, capped at 1MB) - not addressed here; would need archiving/sharding if it ever becomes real.

## Gotchas
- `DoseStatus` is a `Codable` enum with associated values — it has custom `encode`/`decode`. Don't add new cases without updating both.
- `NotificationScheduler.shared` schedules/cancels local reminders based on `takenToday`/`frequencyPerDay` — any change to the source-of-truth fields above should double-check whether a corresponding cancel/reschedule call is still correct.
- `CalendarStore.fetchIfNeeded()` (called from `TABIApp`'s launch task) starts the per-medication listeners and the 60s missed-dose timer once per sign-in - it replaced the old `MedicationStore.startMissedDoseMonitoring()` call that used to fire from `ContentView.onAppear`. A medication added later gets its listener from `save(schedule:)` directly, not from re-running `fetchIfNeeded()`.
