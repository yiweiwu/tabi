# CLAUDE.md — Tabi iOS App

## Build & Run

```bash
# Build for simulator
xcrun xcodebuild -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build

# Run unit tests
xcrun xcodebuild test -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17'

# Run only the unit test target (faster)
xcrun xcodebuild test -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TabiTests
```

**Available simulators**: iPhone 17, iPhone 16e, iPhone Air. Do NOT use "iPhone 16" — it doesn't exist in this environment.

## Project Setup

- **Platform**: iOS, SwiftUI, Swift 5.9+
- **Bundle ID**: `Tabi.Tabi`
- **No `project.pbxproj` edits needed**: The project uses `PBXFileSystemSynchronizedRootGroup`. Any `.swift` file created inside `Tabi/` (or its subdirectories) is automatically compiled. Just create the file.
- **No cross-file imports**: All files are in the same Swift module. Never add `import Tabi` or inter-file imports within the app target.

## File Structure

```
Tabi/
├── TABIApp.swift              — @main entry point (do not add a second @main)
├── ContentView.swift          — Tab container only. Keep this minimal.
├── DesignSystem.swift         — Color extensions + pillColors constant
├── Models/
│   ├── Medication.swift       — Medication, GameStats, Achievement
│   └── DoseModels.swift       — DoseStatus, DoseEntry, DoseSchedule, DetectedMedicationInfo
├── ViewModels/
│   ├── MedicationManager.swift
│   └── CalendarViewModel.swift
├── Services/
│   ├── AnalyzeMedication/
│   │   ├── GeminiService.swift  — Gemini API for prescription label extraction
│   │   ├── LabelScanner.swift   — Vision OCR
│   │   └── PillVerifier.swift   — pill verification
│   ├── CameraManager.swift    — AVFoundation singleton + CameraPreviewView + PhotoCaptureDelegate
│   ├── CalendarPersistenceManager.swift
│   ├── MedicationScheduleParser.swift
│   └── NotificationScheduler.swift
└── Views/
    ├── Today/    — TodayView, WeekStripHeader, TABIMedicationRow
    ├── Calendar/ — CalendarView + calendar subcomponents
    ├── Sharing/  — SharingView
    ├── Profile/  — ProfileView
    ├── Camera/   — NewMedicationCameraView, CameraView, DetectedMedicationView, AnalysisResultView
    └── Progress/ — MedicationProgressView, AchievementRow, WeeklyProgressView
```

**Where to add new code:**
- New screen → `Views/<FeatureName>/`
- New data type → `Models/`
- New service (API, persistence, hardware) → `Services/`
- New ObservableObject that drives a screen → `ViewModels/`
- Design tokens (colors, spacing) → `DesignSystem.swift`

## Architecture Patterns

### Singletons
- `CameraManager.shared` — persists across views so the AVCaptureSession is not torn down on navigation
- `GeminiService.shared` — Gemini API calls are stateless; singleton is fine
- `CalendarPersistenceManager.shared`, `NotificationScheduler.shared`

### State management
- `MedicationManager` is the source of truth for medications and game stats, passed down as `@ObservedObject`. Backed by Firestore — use `add(_:)` to add medications, never append directly to `medications`.
- `CalendarViewModel` exists but is currently unused — `CalendarView` manages its own state directly.
- Prefer `@ObservedObject` over re-creating ViewModels to avoid state loss

### Two camera flows
1. **Add a new medication** → `NewMedicationCameraView` → scans a prescription label → `DetectedMedicationView` (confirm info) → saves to `MedicationManager`
2. **Log a dose** → `CameraView` → photographs the pill → `AnalysisResultView` → records dose in `MedicationManager`

### Design system
Always use the semantic colors from `DesignSystem.swift`:
```swift
.tabiOrange, .tabiGreen, .tabiRed, .tabiAmber, .tabiBlue
.tabiGray, .tabiLavender, .tabiLavLight, .tabiOrangeLight
.tabiCard   // white in light mode, dark gray in dark mode
.tabiBG     // light gray in light mode, black in dark mode
```

## Testing

Tests live in `TabiTests/TabiTests.swift` using Swift Testing (`@Suite`, `@Test`, `#expect`).

**Test images** (`Med_Hydrocodone.jpeg`, `Med_Doxycycline.jpeg`) live in the project root and must be added to the **TabiTests target** in Xcode to be accessible at test time.

Current test coverage:
- `testMedicationDetection` — parameterized OCR accuracy test against known prescription images
- `testHydrocodoneDetailed` / `testDoxycyclineDetailed` — verbose debug output for each image
- `testOCRQuality` — confidence score sanity check

When adding a new test image, place it in the project root alongside existing images and add it to the TabiTests target (not the app target).

## Code Conventions

- **SwiftUI views**: Keep `body` focused. Extract sub-views as separate structs in the same file if they are only used there, or in a new file in the same directory if reused.
- **Imports**: Only import what the file actually uses. Most view files only need `import SwiftUI`. Camera files need `import AVFoundation`. Analyzer needs `import Vision`.
- **Concurrency**: Camera and Vision callbacks use completion handlers. Always dispatch UI updates to `DispatchQueue.main.async`.
- **Avoid**: Global state beyond the declared singletons. Don't create new singletons without a clear lifecycle reason.
- **Formatting**: Match the surrounding file's style. No auto-formatting passes that reformat unrelated code.

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

Stored models: `Medication`, `DoseEntry`, `SharedPerson`. Firestore paths:
- `users/{deviceId}/medications/{id}`
- `users/{deviceId}/doses/{medicationId}` (contains `entries` array)
- `users/{deviceId}/sharedPeople/{id}`

## Dose Tracking Logic

These invariants must be preserved across any UI change.

### Source of truth
- `medication.takenTodayCount` — how many doses were taken **today**. Computed from `takenToday` (resets on a new day) and `lastTaken` (guards that `takenToday` only counts for today). Both are persisted in Firestore on `Medication`.
- `medication.frequencyPerDay` — total doses scheduled per day, set from Gemini OCR at scan time.

### Mid-day medication add
When a new medication is added mid-day, doses whose scheduled time has already passed are pre-seeded as taken:
```swift
let times = MedicationScheduleParser.scheduledTimes(for: frequencyPerDay)
let passedCount = times.filter { $0 < Date() }.count
// takenToday: passedCount, lastTaken: passedCount > 0 ? Date() : nil
```
**Example**: twice-daily (8am, 8pm) added at 2pm → `passedCount = 1` (only 8am passed). `takenTodayCount = 1`, so 8pm still shows as remaining.

### Display rules (Today view and Calendar view must agree)
| State | Today view | Calendar bar |
|---|---|---|
| All doses taken today | "All done today" (green) | Checkmark |
| Some doses taken today | "N of M doses today" | Remaining count (M − N) |
| Future day | — | Total doses (M) |
| Past day (medication was active) | — | Checkmark |
| Medication not yet added on that day | — | Empty/gray |

**Never show the total frequency count for today** — always show the remaining count. Use `frequencyPerDay - takenTodayCount` for today's bar, `frequencyPerDay` for future bars.

### Calendar active-day check
`WeekCalendarDotGrid` calls `CalendarPersistenceManager.shared.loadAll(forMedicationId:)` to determine if a medication was active on a given day. A day is active only if dose entries exist for it — meaning the medication had already been added by that date. Do **not** use a simple "any day before today" check, as that would incorrectly mark days before the medication was added.

## Common Gotchas

- `DoseStatus` is a `Codable` enum with associated values — it has custom `encode`/`decode`. Don't add new cases without updating both.
- `pillColors` is a module-level `let` in `DesignSystem.swift`, not a static member. Access it directly: `pillColors[index]`.
- `Services/FirestoreHelpers.swift` provides `firestoreDict()` and `decoded(from:)` extensions on `Encodable`/`Decodable`. Use these instead of writing inline `JSONEncoder → JSONSerialization` in any new Firestore persistence code.
- `GoogleService-Info.plist` is gitignored — never commit it. Obtain it from a teammate.
