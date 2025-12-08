# Visual Intelligence Integration for Tabi

✅ **Visual Intelligence has been successfully integrated into your Tabi medication tracking app!**

## 🎯 What This Does

Users can now:
1. Open the Visual Intelligence camera (iOS 18+)
2. Point at any medication bottle, pill, or medication name
3. Circle the medication
4. See matching medications from their Tabi app
5. Tap to open the medication directly in your app

## 📁 Files Created

### Core Implementation
- **MedicationEntity.swift** - AppEntity conformance for medications
- **MedicationVisualIntelligenceQuery.swift** - Handles visual searches with OCR
- **OpenMedicationIntent.swift** - Opens specific medications from search results
- **TabiAppIntentsPackage.swift** - Registers all App Intents

### Documentation
- **VISUAL_INTELLIGENCE_SETUP.md** - Complete setup instructions
- **VisualIntelligenceExample.swift** - Implementation guide and examples

### Modified Files
- **ContentView.swift** - Added deep link handling

## 🚀 Setup Required

### 1. Add to Info.plist

Add these entries to your `Info.plist`:

```xml
<!-- URL Scheme for Deep Linking -->
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

<!-- Camera Permission -->
<key>NSCameraUsageDescription</key>
<string>Tabi uses the camera to identify medications and help you track your medication schedule.</string>
```

### 2. Add Frameworks

In Xcode, add these frameworks to your target:
- `VisualIntelligence.framework`
- `AppIntents.framework`
- `Vision.framework`

These should already be available if you're targeting iOS 18+.

### 3. Update Deployment Target

Ensure your deployment target is set to **iOS 18.0** or later.

### 4. Add App Intents Capability

1. Select your target in Xcode
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "App Intents"

## 🧪 Testing

### Option 1: Physical Device (Recommended)

1. Build and run on an iOS 18+ device with Apple Intelligence support
2. Open Visual Intelligence:
   - Press and hold the Camera Control button, OR
   - Open Control Center → Visual Intelligence
3. Point the camera at a medication
4. Circle the medication name or bottle
5. Your app should appear in results!

### Option 2: Simulator Testing

While Visual Intelligence requires a physical device, you can test the search logic:

```swift
import Testing

@Test("Medication search by label")
func testMedicationSearch() async throws {
    let query = MedicationIntentValueQuery()
    
    // Create mock semantic content
    let descriptor = SemanticContentDescriptor(
        labels: ["Aspirin", "Medicine"]
    )
    
    let results = try await query.values(for: descriptor)
    
    #expect(results.count > 0)
    #expect(results.contains { $0.name.lowercased().contains("aspirin") })
}
```

## 🔍 How It Works

### 1. Image Analysis
When a user circles a medication in Visual Intelligence:
- System performs OCR to read text
- Detects objects and provides semantic labels
- Creates a `SemanticContentDescriptor`

### 2. Your App Searches
`MedicationIntentValueQuery` receives the descriptor and:
- Extracts labels (e.g., "Aspirin", "Medicine")
- Performs OCR on the pixel buffer using Vision framework
- Searches your medication database
- Returns top 10 matches

### 3. Results Display
Each medication shows:
- 💊 Emoji + Name
- ⏰ Dosage time
- 🔔 Points/streak info

### 4. Deep Linking
When user taps a result:
- Opens URL: `tabi://medication/{uuid}`
- App navigates to that specific medication
- Shows on the Today tab

## 🎨 Customization Ideas

### Enhance Search Accuracy

```swift
// Add more medication metadata
struct Medication {
    var genericName: String?
    var brandNames: [String]
    var activeIngredient: String?
    var pillColor: String?
    var pillShape: String?
}
```

### Add Image Classification

```swift
import Vision

func classifyPillShape(_ pixelBuffer: CVPixelBuffer) async throws -> String {
    // Use Vision's image classification
    let request = VNClassifyImageRequest()
    // Classify as "Round", "Oval", "Capsule", etc.
}
```

### Use Foundation Models

```swift
import FoundationModels

func analyzeMedicationWithAI(_ image: UIImage) async throws -> String {
    let session = LanguageModelSession(instructions: """
        Analyze this medication image and extract:
        - Name
        - Dosage
        - Active ingredients
        """)
    
    let response = try await session.respond(
        to: "What medication is shown in this image?"
    )
    
    return response.content
}
```

### Add Barcode Scanning

```swift
import VisionKit

func scanMedicationBarcode(_ pixelBuffer: CVPixelBuffer) async throws -> String {
    let request = VNDetectBarcodesRequest()
    // Scan NDC (National Drug Code) barcodes
}
```

## 📱 User Experience Tips

1. **Add onboarding**: Show users how to use Visual Intelligence with Tabi
2. **Medication photos**: Let users take photos of medications for easier identification
3. **Search history**: Track what medications users search for
4. **Suggestions**: Show "Did you mean...?" for similar medications
5. **Add medication from search**: Quick button to add a found medication to their schedule

## 🐛 Troubleshooting

### App not appearing in Visual Intelligence results?
- Verify App Intents capability is added
- Check that you have medications saved
- Ensure medication names match search terms
- Rebuild and reinstall the app

### Deep links not working?
- Check URL scheme in Info.plist
- Verify `onOpenURL` handler in ContentView
- Test with: `xcrun simctl openurl booted tabi://medication/test`

### No OCR text detected?
- Ensure camera permission is granted
- Check that text is clear and in focus
- Try different lighting conditions
- Verify Vision framework is imported

### Camera permission denied?
- Check Info.plist has NSCameraUsageDescription
- Reset permissions in Settings → Privacy → Camera

## 📚 Next Steps

1. ✅ Complete Info.plist setup
2. ✅ Test on device with saved medications
3. ⚡ Add more medication metadata for better matching
4. 🎨 Enhance search algorithm with fuzzy matching
5. 🤖 Consider Foundation Models for smarter analysis
6. 📊 Track Visual Intelligence usage analytics
7. 👥 Gather user feedback on accuracy

## 🎉 You're All Set!

Visual Intelligence is now integrated into Tabi. Once you complete the setup steps and test on a device, users will be able to identify and track their medications simply by pointing their camera at them!

Need help? Check out:
- VISUAL_INTELLIGENCE_SETUP.md - Detailed setup guide
- VisualIntelligenceExample.swift - Code examples and explanations
- Apple's Documentation: https://developer.apple.com/documentation/VisualIntelligence
