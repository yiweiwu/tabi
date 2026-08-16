---
paths:
  - "TabiTests/**"
---

# Testing

Tests live in `TabiTests/TabiTests.swift` using Swift Testing (`@Suite`, `@Test`, `#expect`).

**Test images** (`Med_Hydrocodone.jpeg`, `Med_Doxycycline.jpeg`) live in the project root and must be added to the **TabiTests target** in Xcode to be accessible at test time.

Current test coverage:
- `testMedicationDetection` — parameterized OCR accuracy test against known prescription images
- `testHydrocodoneDetailed` / `testDoxycyclineDetailed` — verbose debug output for each image
- `testOCRQuality` — confidence score sanity check

When adding a new test image, place it in the project root alongside existing images and add it to the TabiTests target (not the app target).

Run commands:
```bash
xcrun xcodebuild test -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17'
# Faster: only the unit test target
xcrun xcodebuild test -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TabiTests
```
