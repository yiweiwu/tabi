# Tabi Onboarding Workflow

A complete onboarding experience for the Tabi medication tracking app.

## 📱 Onboarding Flow

### 1. **Splash Page** (`SplashPageView.swift`)
- Displays the Tabi logo with an animated entrance
- Auto-advances to the welcome screen after 2 seconds
- Features gradient background and smooth animations

### 2. **Welcome Page** (`WelcomeToTabiPageView.swift`)
- Shows "Welcome to Tabi" message
- Displays tagline: "Create an account to track your meds and share with family"
- Lists key app features:
  - Track Medications
  - Scan & Add
  - Share & Care

### 3. **Authentication Page** (`AuthenticationPageView.swift`)
Multiple sign-up options:
- **Continue with Apple** (Sign in with Apple)
- **Continue with Google**
- **Continue with Facebook**
- **Continue with Email** (opens email sign-up sheet)
- **Continue with Phone Number** (opens phone verification sheet)
- **Sign Up For Free** button at the bottom

Includes Terms of Service and Privacy Policy links.

### 4. **Profile Setup Page** (`ProfileSetupPageView.swift`)
"Let's Get Started" - Collects user information:
- **First Name** (required)
- **Age** (optional)
- **Gender** (optional dropdown):
  - Male
  - Female
  - Non-binary
  - Prefer not to say
  - Other

The "Next" button is only enabled when a first name is entered.

If the user signed in with Apple or Google, `AuthenticationPageView` prefills
`coordinator.firstName`/`lastName` from the account's name (via
`ASAuthorizationAppleIDCredential.fullName` / `GIDGoogleUser.profile`) so a
new user isn't retyping a name the provider already gave us - only for a
brand-new account, never overwriting a returning user's already-saved
profile. `lastName` rides along in `OnboardingCoordinator` even though this
page has no Last Name field.

This is the only page whose data actually reaches Firestore today - see
"Data Persistence" below.

### 5. **Permissions Page** (`PermissionsPageView.swift`)
Requests two key permissions:

- **Camera Access**
  - Purpose: Scan medication labels
  - Shows status: Not Determined / Granted / Denied
  - "Allow" button triggers permission request
  
- **Push Notifications**
  - Purpose: Medication reminders
  - Shows status with visual feedback
  - Links to Settings if denied

Both permissions can be skipped, but are strongly encouraged.

### 6. **Completion Page** (`CompletionPageView.swift`)
- Success checkmark with animation
- Personalized welcome message using the user's first name
- Quick tips for getting started:
  - Add first medication
  - Use camera to scan
  - Set reminders
- "Start Using Tabi" button completes onboarding

## 🏗️ Architecture

### OnboardingCoordinator
An `@Observable` class that manages the onboarding state:
- Tracks current page
- Stores user profile data (firstName, lastName, age, gender)
- Handles navigation between pages
- On `completeOnboarding()`, writes the collected profile fields to
  `UserProfileStore` (see below) before marking onboarding complete

### OnboardingView
The main container view that:
- Displays appropriate page based on coordinator state
- Shows navigation buttons (Skip/Next/Continue)
- Handles transitions between pages
- Validates input before allowing progression
- Saves onboarding completion state

## 💾 Data Persistence

Onboarding no longer just collects data into `OnboardingCoordinator` and
discards it - `OnboardingCoordinator.completeOnboarding()` builds a
`UserProfile` from the collected fields and hands it to
`UserProfileStore.shared` (`Tabi/Services/UserProfileStore.swift`), which is
the single owner of profile state for the rest of the app:

- An in-memory `@Published var profile` cache that `ProfileView` (and its
  edit/allergy/pharmacy/settings sheets) reads and writes directly.
- A one-shot Firestore fetch (`fetchIfNeeded()`, not a live listener) that
  populates the cache once per session - called from `TABIApp` at launch
  (returning signed-in users) and right after sign-in in
  `AuthenticationPageView` (new/reinstalling users).
- A write-through save on every mutation, persisted to the `users/{uid}`
  document in Firestore (see `firestore.rules`).

Because `ContentView`'s `MedicationManager` is created fresh only after
`hasCompletedOnboarding` flips true, and reads from the same
`UserProfileStore` singleton, the onboarding flow and the main app's Profile
tab now share one data source instead of two disconnected copies. There's no
anonymous/device-ID fallback (matching `CalendarPersistenceManager`'s
existing pattern for doses): if a user skips the Authentication page, the
entered name/age/gender stays in the in-memory cache for that session but
never reaches Firestore.

`profileImageData` was removed entirely - there is no profile picture
feature in this app.

## 🎨 Design System

Uses the Tabi design system colors:
- **tabiOrange** - Primary brand color, CTAs
- **tabiLavender** - Accents, icons
- **tabiCard** - Card backgrounds (adaptive light/dark)
- **tabiGray** - Secondary text
- Other semantic colors for success, warnings, etc.

## 🔧 Integration

### Basic Setup

```swift
import SwiftUI

@main
struct TabiApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView() // Your main app
            } else {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
            }
        }
    }
}
```

### Reset Onboarding (for testing)

```swift
// In your settings or debug menu
Button("Reset Onboarding") {
    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
}
```

## 📋 Requirements

- iOS 17.0+
- SwiftUI
- UserNotifications framework (for push notifications)
- AVFoundation (for camera permissions)
- AuthenticationServices (for Sign in with Apple)

## 🔐 Authentication Integration

The authentication page provides UI for multiple sign-in methods:

1. **Sign in with Apple**: integrated via `AuthenticationServices` + `AuthenticationManager`
2. **Google Sign-In**: integrated via the Google Sign-In SDK + `AuthenticationManager`
3. **Facebook Login**: UI only - the button prints and advances the page, no SDK wired up
4. **Email/Phone**: UI only - `EmailSignUpSheet`/`PhoneSignUpSheet` collect input and print it, no backend wired up

## ✨ Features

- **Smooth Animations**: Page transitions with slide and fade effects
- **Smart Validation**: Next button enables only when required fields are filled
- **Skip Options**: Users can skip optional steps (Profile, Permissions)
- **Permission Status**: Visual feedback for permission states
- **Adaptive Design**: Works in light and dark mode
- **Type-Safe Navigation**: Enum-based page navigation

## 📁 File Structure

```
Onboarding/
├── OnboardingFlow.swift              # Main coordinator and container view
├── SplashPageView.swift              # Page 1: Logo splash
├── WelcomeToTabiPageView.swift       # Page 2: Welcome message
├── AuthenticationPageView.swift      # Page 3: Sign-up options
├── ProfileSetupPageView.swift        # Page 4: User profile (updated)
├── PermissionsPageView.swift         # Page 5: Camera & notifications
├── CompletionPageView.swift          # Page 6: Success & tips
├── DesignSystem.swift                # Color palette
└── TabiApp.swift                     # App entry point example
```

## 🐛 Troubleshooting

### Duplicate Declaration Errors
If you see "Invalid redeclaration" errors:
- Delete the old duplicate files: `OnboardingWelcomePageView.swift` and `ViewsOnboardingWelcomePageView.swift`
- Keep only the new files created by this workflow

### Build Issues
Make sure to:
1. Add `Info.plist` entries for camera and notifications:
   - `NSCameraUsageDescription`: "Tabi needs camera access to scan medication labels"
   - `NSUserNotificationsUsageDescription`: "Tabi sends reminders for your medications"

## 🎯 Next Steps

1. Implement actual authentication backends for Email/Phone/Facebook (Apple
   and Google are real today; the rest are UI-only stubs that print and
   advance the page - see `AuthenticationPageView.swift`)
2. ~~Store user profile data to your database~~ - done, see "Data
   Persistence" above
3. Set up analytics to track onboarding completion rates
4. Add onboarding skip tracking for re-engagement
5. Implement proper error handling for auth failures

---

**Created for Tabi Medication Tracker**
