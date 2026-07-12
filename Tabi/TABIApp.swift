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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
