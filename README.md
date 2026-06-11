# Tabi — Medication Reminder App

iOS medication tracker with AI-powered prescription label scanning.

## Setup

### 1. Clone the repo
```bash
git clone <repo-url>
cd tabi
```

### 2. Add your Gemini API key

Create `Tabi/Config.swift` (this file is gitignored — never commit it):

```swift
enum Config {
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
}
```

Get a free API key at [aistudio.google.com](https://aistudio.google.com). The app uses **Gemini 2.5 Flash** for prescription label extraction.

> **Note:** The free tier has rate limits. Enable billing on your Google Cloud project for production use.

### 3. Add your Firebase config

Obtain `GoogleService-Info.plist` from a team member and place it at `Tabi/GoogleService-Info.plist` (gitignored — never commit it).

### 4. Build & Run

Open `Tabi.xcodeproj` in Xcode and run on a device or simulator.

```bash
# Build from command line
xcrun xcodebuild -scheme Tabi -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

**Available simulators:** iPhone 17, iPhone 16e, iPhone Air

## How Label Scanning Works

1. Point camera at a prescription pill bottle label
2. Vision OCR extracts the raw text
3. Gemini API interprets the text (handles OCR noise from curved bottles)
4. Extracts brand name, generic name, dosage, and schedule
5. User reviews and confirms before saving
