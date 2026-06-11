# iOS Simulator Verifier

Use this to build, install, and screenshot the Tabi app on the simulator.

## Build

```bash
xcrun xcodebuild -scheme Tabi \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Check last line for `** BUILD SUCCEEDED **` or `** BUILD FAILED **`.
Filter errors only: append `| grep "error:"` to the build command.

App binary lands at:
```
~/Library/Developer/Xcode/DerivedData/Tabi-*/Build/Products/Debug-iphonesimulator/Tabi.app
```

Find it with:
```bash
find ~/Library/Developer/Xcode/DerivedData -name "Tabi.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1
```

## Install & Launch

```bash
# Boot simulator (safe to run if already booted)
xcrun simctl boot "iPhone 17" 2>/dev/null

# Install
xcrun simctl install "iPhone 17" <path-to-Tabi.app>

# Launch
xcrun simctl launch "iPhone 17" Tabi.Tabi

# Open Simulator window
open -a Simulator
```

## Screenshot

```bash
xcrun simctl io "iPhone 17" screenshot /tmp/tabi_<step>.png
```

Then Read the file to view it.

## Camera workaround (simulator)

Both camera flows have a built-in simulator path:

- **NewMedicationCameraView**: auto-loads `Med_Hydrocodone.jpeg` from the app bundle. Tap the capture button to run the full add-medication flow.
- **CameraView** (dose logging): same pattern via `simulatorCapture`.

The test images (`Med_Hydrocodone.jpeg`, `Med_Doxycycline.jpeg`) must be added to the **app target** in Xcode (not just TabiTests) for this to work.

## Limitations

- Cannot tap or interact with the simulator — UI interaction still requires a human.
- Firestore write verification: add a medication via the simulator flow, then check the Firebase console for a document at `users/{deviceId}/medications/{id}`.

## Notes

- Available simulators: iPhone 17, iPhone 16e, iPhone Air. Do NOT use "iPhone 16".
- Bundle ID: `Tabi.Tabi`
