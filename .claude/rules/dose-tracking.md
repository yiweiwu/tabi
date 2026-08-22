---
paths:
  - "Tabi/Views/Today/**"
  - "Tabi/Views/Calendar/**"
  - "Tabi/Models/DoseModels.swift"
  - "Tabi/Models/Medication.swift"
  - "Tabi/Services/MedicationScheduleParser.swift"
  - "Tabi/Services/MedicationTimelineProvider.swift"
  - "Tabi/Services/Firestore/CalendarStore.swift"
  - "Tabi/ViewModels/MedicationStore.swift"
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

`WeekCalendarDotGrid` (`Views/Calendar/CalendarView.swift`) does *not* go through `CalendarStore` - the whole Calendar tab timeline still runs on `ScheduledMedication`/`MockMedicationTimelineProvider`'s mock data, per `CLAUDE.md`'s Data ownership section. Don't assume its dots reflect real dose data yet.

## Gotchas
- `DoseStatus` is a `Codable` enum with associated values — it has custom `encode`/`decode`. Don't add new cases without updating both.
- `NotificationScheduler.shared` schedules/cancels local reminders based on `takenToday`/`frequencyPerDay` — any change to the source-of-truth fields above should double-check whether a corresponding cancel/reschedule call is still correct.
- `CalendarStore.fetchIfNeeded()` (called from `TABIApp`'s launch task) starts the per-medication listeners and the 60s missed-dose timer once per sign-in - it replaced the old `MedicationStore.startMissedDoseMonitoring()` call that used to fire from `ContentView.onAppear`. A medication added later gets its listener from `save(schedule:)` directly, not from re-running `fetchIfNeeded()`.
