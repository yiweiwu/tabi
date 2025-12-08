# ✅ Visual Intelligence Setup Checklist

## Quick Setup (5 minutes)

### Step 1: Info.plist Configuration

Open your `Info.plist` and add:

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

**Or in Xcode:**
1. Select your project → Info tab
2. Click "+" to add new keys:
   - `URL types` → Add item → `URL Schemes` → `tabi`
   - `Privacy - Camera Usage Description` → "Tabi uses the camera..."

---

### Step 2: Add App Intents Capability

1. Select your target in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Search for and add **App Intents**

---

### Step 3: Verify Frameworks

These frameworks should already be linked (they're part of iOS SDK):
- ✅ VisualIntelligence
- ✅ AppIntents
- ✅ Vision
- ✅ FoundationModels (iOS 18+)

No manual linking needed!

---

### Step 4: Set Deployment Target

Ensure deployment target is **iOS 18.0** or later:
1. Select target → General tab
2. Minimum Deployments → iOS 18.0

---

### Step 5: Build & Run on Device

1. Connect iPhone with iOS 18+
2. Build and run (⌘R)
3. Add some medications to your app
4. Test Visual Intelligence:
   - Press Camera Control button, OR
   - Control Center → Visual Intelligence
   - Point at medication → Circle it
   - Your app should appear! 🎉

---

## Verification Checklist

Before testing, verify:

- [ ] Info.plist has URL scheme `tabi`
- [ ] Info.plist has camera usage description
- [ ] App Intents capability is added
- [ ] Deployment target is iOS 18.0+
- [ ] App builds without errors
- [ ] You have medications saved in the app
- [ ] Testing on physical device (not simulator)
- [ ] Device has iOS 18+ with Apple Intelligence

---

## Testing Steps

### 1. Basic Test
```
1. Open Tabi app
2. Add a medication (e.g., "Aspirin")
3. Open Visual Intelligence camera
4. Point at text that says "Aspirin"
5. Circle the word "Aspirin"
6. ✅ Tabi should appear in results
7. Tap result
8. ✅ App should open to that medication
```

### 2. Advanced Test (Fuzzy Matching)
```
1. Add medication "Ibuprofen"
2. Write "Ibuprfen" on paper (with typo)
3. Circle it in Visual Intelligence
4. ✅ Should still find "Ibuprofen"
```

### 3. Barcode Test (if you have metadata)
```
1. Add medication with NDC code
2. Point camera at medication barcode
3. Circle barcode
4. ✅ Instant match!
```

### 4. Color/Shape Test
```
1. Add medication with color/shape metadata
2. Point at actual pill
3. Circle it
4. ✅ Better matching with visual features
```

---

## Troubleshooting

### App not appearing in results?

**Check:**
- [ ] App Intents capability is added
- [ ] You have saved medications in app
- [ ] Medication name matches what you circled
- [ ] Try rebuilding and reinstalling app

**Try:**
```swift
// Add debug logging to MedicationVisualIntelligenceQuery
print("🔍 Search terms: \(labels)")
print("📦 Found medications: \(medications.count)")
```

### Deep links not working?

**Check:**
- [ ] URL scheme in Info.plist is exactly `tabi`
- [ ] `onOpenURL` handler is in ContentView
- [ ] Test manually: `xcrun simctl openurl booted tabi://medication/test`

### Camera permission denied?

**Fix:**
- Settings → Privacy & Security → Camera → Tabi → Enable

### No text recognized?

**Try:**
- Better lighting
- Clearer text
- Focus camera properly
- Use printed text (not handwritten)

### AI features not working?

**Check:**
- Device supports Apple Intelligence
- Settings → Apple Intelligence & Siri → Enabled
- iOS 18.2+ recommended

---

## Files Overview

### ✅ Ready to Use
- `MedicationEntity.swift` - AppEntity for medications
- `MedicationVisualIntelligenceQuery.swift` - Search handler (ENHANCED)
- `OpenMedicationIntent.swift` - Deep linking
- `TabiAppIntentsPackage.swift` - Intent registration
- `ContentView.swift` - Deep link handling

### 🆕 New Advanced Features
- `EnhancedMedicationModels.swift` - Rich metadata & fuzzy matching
- `AdvancedImageAnalysis.swift` - Color, shape, barcode detection
- `MedicationAIAnalyzer.swift` - Foundation Models integration
- `VisualIntelligenceTests.swift` - Comprehensive tests

### 📚 Documentation
- `VISUAL_INTELLIGENCE_README.md` - Original setup guide
- `VISUAL_INTELLIGENCE_SETUP.md` - Quick setup
- `VisualIntelligenceExample.swift` - Code examples
- `ENHANCED_VI_DOCUMENTATION.md` - Full feature docs
- `VI_SETUP_CHECKLIST.md` - This file!

---

## Next Steps After Setup

### Immediate
1. ✅ Test basic Visual Intelligence flow
2. ✅ Verify deep linking works
3. ✅ Test with multiple medications

### Short-term Enhancements
1. Add metadata UI when creating medications
2. Show "Scan Medication" button in app
3. Display search confidence scores
4. Add medication photo capture

### Long-term
1. Train custom ML model for pills
2. Add drug interaction checking
3. Build medication history tracking
4. Integrate with Apple Health

---

## Support Resources

**Apple Documentation:**
- [Visual Intelligence](https://developer.apple.com/documentation/VisualIntelligence)
- [App Intents](https://developer.apple.com/documentation/AppIntents)
- [Vision Framework](https://developer.apple.com/documentation/Vision)
- [Foundation Models](https://developer.apple.com/documentation/FoundationModels)

**Your Implementation:**
- Read `ENHANCED_VI_DOCUMENTATION.md` for full feature details
- Check `VisualIntelligenceExample.swift` for code examples
- Run tests in `VisualIntelligenceTests.swift`

---

## Success Indicators

You'll know it's working when:

✅ App appears in Visual Intelligence results  
✅ Tapping result opens your app  
✅ App navigates to correct medication  
✅ Fuzzy matching handles typos  
✅ Search is fast (<1 second)  
✅ Results are relevant and ranked  

---

## 🎉 You're Done!

Complete the steps above and you'll have:
- **World-class medication identification**
- **AI-powered search**
- **Fuzzy matching for typos**
- **Barcode support**
- **Color & shape recognition**
- **100% on-device privacy**

**Happy coding!** 🚀

---

Questions? Check the documentation files or add debug logging to trace the flow.
