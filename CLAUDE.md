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
- **Bundle ID**: `com.hellotabi.Tabi`
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
│   ├── DoseModels.swift       — DoseStatus, DoseEntry, DoseSchedule, DetectedMedicationInfo
│   ├── UserProfile.swift      — UserProfile, UserSettings, Pharmacy, Allergy
│   └── MedicationTimelineModels.swift — ScheduledMedication, Weekday, DoseDotStatus (mock data backing the Calendar tab's week/month view — not wired to MedicationManager/Firestore yet)
├── ViewModels/
│   ├── MedicationManager.swift
│   └── CalendarViewModel.swift
├── Services/
│   ├── AnalyzeMedication/
│   │   ├── GeminiService.swift  — Gemini API for prescription label extraction
│   │   ├── LabelScanner.swift   — Vision OCR
│   │   └── PillVerifier.swift   — pill verification
│   ├── CameraManager.swift    — AVFoundation singleton + CameraPreviewView + PhotoCaptureDelegate
│   ├── AuthenticationManager.swift — Firebase Auth singleton (Sign in with Apple + Google)
│   ├── MedicationScheduleParser.swift
│   ├── NotificationScheduler.swift
│   ├── MedicationTimelineProvider.swift — `MedicationTimelineProviding` protocol + `MockMedicationTimelineProvider`; the seam to swap in a real backend for the Calendar tab later
│   └── Firestore/
│       ├── CalendarPersistenceManager.swift
│       ├── UserProfileStore.swift — single owner of `UserProfile` state: in-memory cache + Firestore persistence (the `users/{uid}` doc)
│       ├── MissedDoseAlertService.swift — fans out a missed-dose SMS alert doc per caretaker to Firestore
│       ├── ConnectionConfirmationService.swift — writes a caretaker-added SMS confirmation doc to Firestore
│       └── FirestoreHelpers.swift — `firestoreDict()`/`decoded(from:)` Codable <-> Firestore helpers
└── Views/
    ├── Today/     — TodayView, WeekStripHeader, TABIMedicationRow
    ├── Calendar/  — CalendarView + calendar subcomponents
    ├── Sharing/   — SharingView
    ├── Profile/   — ProfileView (incl. SettingsView), PrivacyPolicyView
    ├── Camera/    — NewMedicationCameraView, CameraView, DetectedMedicationView, AnalysisResultView
    ├── Progress/  — MedicationProgressView, AchievementRow, WeeklyProgressView
    └── Onboarding/ — OnboardingFlow (coordinator + most pages, entry point is now WelcomeToTabiPageView), AuthenticationPageView, ProfileSetupPageView, PermissionsPageView, CompletionPageView
```

**Where to add new code:**
- New screen → `Views/<FeatureName>/`
- New data type → `Models/`
- New service (API, persistence, hardware) → `Services/`
- New ObservableObject that drives a screen → `ViewModels/`
- Design tokens (colors, spacing) → `DesignSystem.swift`

This root file only carries genuinely project-wide context. Feature-specific conventions live in path-scoped rules that load only when relevant files are read — see [Feature-scoped rules](#feature-scoped-rules) below.

## Architecture Patterns

### Singletons
`CameraManager`, `GeminiService`, `NotificationScheduler`, and the Firestore-backed services are deliberate singletons — don't add a new one without a clear lifecycle reason. Rationale for each lives in its feature's scoped rule.

### State management
- `MedicationManager` is the source of truth for medications and game stats, passed down as `@ObservedObject`. Backed by Firestore — use `add(_:)` to add medications, never append directly to `medications`.
- `CalendarViewModel` exists but is currently unused — `CalendarView` manages its own state directly.
- Prefer `@ObservedObject` over re-creating ViewModels to avoid state loss

### Design system
Always use the semantic colors from `DesignSystem.swift`:
```swift
.tabiOrange, .tabiGreen, .tabiRed, .tabiAmber, .tabiBlue
.tabiGray, .tabiLavender, .tabiLavLight, .tabiOrangeLight
.tabiCard   // white in light mode, dark gray in dark mode
.tabiBG     // light gray in light mode, black in dark mode
```

## Code Conventions

- **SwiftUI views**: Keep `body` focused. Extract sub-views as separate structs in the same file if they are only used there, or in a new file in the same directory if reused.
- **Imports**: Only import what the file actually uses. Most view files only need `import SwiftUI`.
- **Concurrency**: Always dispatch UI updates from a completion handler to `DispatchQueue.main.async`.
- **Error handling**: Never silently swallow an error — no bare `try?`, no fire-and-forget completion handler that ignores its `error` parameter, no empty `catch {}`. At minimum `print()` it. A swallowed error can be indistinguishable from a normal empty result, hiding real bugs (see `.claude/rules/firestore.md` for a concrete case).
- **Avoid**: Global state beyond the declared singletons. Don't create new singletons without a clear lifecycle reason.
- **Formatting**: Match the surrounding file's style. No auto-formatting passes that reformat unrelated code.

## Privacy & Compliance

Tabi stores medication, dosage, and profile data that's regulated under CMIA,
Washington's My Health My Data Act, and CCPA/CPRA even though HIPAA itself
doesn't apply to us as a direct-to-consumer app. Before adding any feature that
shares user data with a third party (including caretaker SMS), adds a new
stored field, or touches analytics/research/monetization, read
`PRIVACY_COMPLIANCE.md` at the repo root — it has the specific guardrails and a
pre-flight checklist.

User-facing legal docs live at the repo root: `PRIVACY_POLICY.md` and
`TERMS_OF_SERVICE.md` (mirrored in-app via `PrivacyPolicyView.swift`, linked
from the auth screen and Settings → Privacy). `AuthenticationManager.deleteAccountAndAllData()`
plus `MedicationManager.deleteAllLocalData()` implement the account/data
deletion these documents promise — keep both in sync if the deletion scope
ever changes.

## Common Gotchas

- `pillColors` is a module-level `let` in `DesignSystem.swift`, not a static member. Access it directly: `pillColors[index]`.
- `GoogleService-Info.plist` is gitignored — never commit it. Obtain it from a teammate.
- `PRODUCT_BUNDLE_IDENTIFIER` (the `Tabi` target's build setting) must match `GoogleService-Info.plist`'s `BUNDLE_ID`. Because the plist is gitignored, a mismatch never shows up in a PR diff — a "Verify GoogleService-Info.plist bundle ID" build phase checks this on every build and fails loudly if they diverge. If you change the bundle ID, re-download the plist from the Firebase console for that bundle ID.

## Feature-scoped rules

Detailed conventions for specific areas live in `.claude/rules/`, loaded automatically only when a matching file is read — see each file's `paths:` frontmatter for exactly what triggers it:

| Rule | Covers |
|---|---|
| `.claude/rules/firestore.md` | Data model, stored fields/paths, `firestore.rules` deploy gotchas, outbound SMS footer convention |
| `.claude/rules/dose-tracking.md` | Today/Calendar invariants, mid-day add behavior, display rules, `DoseStatus` gotcha |
| `.claude/rules/camera.md` | The two camera flows, `AnalyzeMedication/` pipeline, `CameraManager`/`GeminiService` singletons |
| `.claude/rules/testing.md` | `TabiTests` conventions and test image setup |

When you touch a large, self-contained topic that doesn't apply to most of the codebase, add a new scoped rule under `.claude/rules/` instead of growing this file. Keep instructions where they're relevant, not where they're convenient to write.
