import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TABIApp: App {
    // Deliberately not synced with AuthenticationManager's sign-in state - a
    // signed-out but onboarded device still skips onboarding on relaunch.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        FirebaseApp.configure()
        // GIDSignIn doesn't read GoogleService-Info.plist itself - configure
        // it from the client ID Firebase already parsed out of that file.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                }
            }
            .task {
                // Covers a returning signed-in user relaunching the app -
                // the onboarding flow's own sign-in handlers fetch for the
                // new-signup case instead (see AuthenticationPageView).
                // Must wait for Firebase to finish restoring the persisted
                // session first, or `uid` can read nil on a fresh process
                // launch (e.g. reopening after iOS reaps a backgrounded
                // app) and silently skip the fetch for the whole session.
                await AuthenticationManager.shared.waitForInitialAuthState()
                async let profile: Void = UserProfileStore.shared.fetchIfNeeded()
                async let medications: Void = MedicationStore.shared.fetchIfNeeded()
                async let sharedPeople: Void = SharedPeopleStore.shared.fetchIfNeeded()
                _ = await (profile, medications, sharedPeople)
                // Needs MedicationStore.shared.medications already populated
                // (to know which dose documents to listen to), so it can't run
                // inside the async let group above alongside medications itself.
                await CalendarStore.shared.fetchIfNeeded()
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
