---
paths:
  - "Tabi/Views/Camera/**"
  - "Tabi/Services/CameraManager.swift"
  - "Tabi/Services/AnalyzeMedication/**"
---

# Camera & Label/Pill Analysis

## Two camera flows
1. **Add a new medication** → `NewMedicationCameraView` → scans a prescription label → `DetectedMedicationView` (confirm info) → saves to `MedicationStore`
2. **Log a dose** → `CameraView` → photographs the pill → `AnalysisResultView` → records dose in `MedicationStore`

Don't conflate these — they use different underlying analysis (`AnalyzeMedication/` pipeline for labels, pill verification for dose logging) and write to `MedicationStore` differently (`add(_:)` vs `recordMedicationTaken(_:points:)`).

## AnalyzeMedication pipeline
`Services/AnalyzeMedication/` is a tight 3-file pipeline used together for prescription label scanning:
- `GeminiService.swift` — Gemini API call that extracts structured medication info from the label
- `LabelScanner.swift` — Vision OCR, runs before the Gemini call
- `PillVerifier.swift` — pill verification (dose-logging flow)

## Singletons
- `CameraManager.shared` — persists across views so the `AVCaptureSession` is not torn down on navigation. Don't instantiate a second `CameraManager`.
- `GeminiService.shared` — Gemini API calls are stateless; singleton is fine, no special lifecycle concerns.

## Conventions
- **Imports**: Camera files need `import AVFoundation`. The analyzer needs `import Vision`.
- **Concurrency**: Camera and Vision callbacks use completion handlers. Always dispatch UI updates to `DispatchQueue.main.async`.
