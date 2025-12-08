# Visual Intelligence Setup Instructions

## Required Info.plist Entries

Add the following entries to your `Info.plist` file to enable Visual Intelligence:

### 1. URL Scheme for Deep Linking

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>tabi</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.tabi</string>
    </dict>
</array>
```

### 2. Privacy - Camera Usage Description

Since Visual Intelligence uses the camera, you need to add a camera usage description:

```xml
<key>NSCameraUsageDescription</key>
<string>Tabi uses the camera to identify medications and help you track your medication schedule.</string>
```

## Xcode Configuration

### 1. Add Required Frameworks

In your target's "Frameworks, Libraries, and Embedded Content" section, ensure these are added:
- VisualIntelligence.framework
- AppIntents.framework
- Vision.framework

### 2. Update Deployment Target

Visual Intelligence requires:
- iOS 18.0 or later
- A device with Apple Intelligence support

### 3. Add Capability

In your target's "Signing & Capabilities" tab:
1. Click "+ Capability"
2. Add "App Intents"

## Testing Visual Intelligence

1. Build and run your app on a physical device (iOS 18+)
2. Open the Visual Intelligence camera (Camera Control button or Control Center)
3. Point the camera at a medication or medication name
4. Circle the medication
5. Your app should appear in the search results!

## How It Works

1. **Visual Intelligence** detects text and objects in the camera view
2. **SemanticContentDescriptor** provides labels and pixel buffer data
3. **MedicationIntentValueQuery** searches your medications using:
   - Labels provided by Visual Intelligence
   - OCR text recognition from the image
4. **Results** appear in the Visual Intelligence interface
5. **Tapping a result** opens your app via deep link

## Troubleshooting

- **No results appearing?** Check that you have medications saved in your app
- **App not opening?** Verify the URL scheme is correctly configured in Info.plist
- **Camera permission denied?** Ensure NSCameraUsageDescription is in Info.plist
- **Not seeing Visual Intelligence button?** Ensure device supports Apple Intelligence and is running iOS 18+
