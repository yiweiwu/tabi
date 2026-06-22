import SwiftUI

// MARK: - Onboarding Coordinator

@MainActor
@Observable
class OnboardingCoordinator {
    var currentPage: OnboardingPage = .splash
    var isOnboardingComplete = false
    
    // Profile data
    var firstName = ""
    var age = ""
    var selectedGender = "Prefer not to say"
    
    enum OnboardingPage {
        case splash
        case welcome
        case authentication
        case profileSetup
        case permissions
        case completion
    }
    
    func nextPage() {
        switch currentPage {
        case .splash:
            currentPage = .welcome
        case .welcome:
            currentPage = .authentication
        case .authentication:
            currentPage = .profileSetup
        case .profileSetup:
            currentPage = .permissions
        case .permissions:
            currentPage = .completion
        case .completion:
            completeOnboarding()
        }
    }
    
    func skipToNext() {
        nextPage()
    }
    
    func completeOnboarding() {
        isOnboardingComplete = true
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @State private var coordinator = OnboardingCoordinator()
    @Binding var isOnboardingComplete: Bool
    
    var body: some View {
        ZStack {
            Color.tabiBG.ignoresSafeArea()
            
            Group {
                switch coordinator.currentPage {
                case .splash:
                    SplashPageView()
                        .transition(.opacity)
                case .welcome:
                    WelcomeToTabiPageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .authentication:
                    AuthenticationPageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .profileSetup:
                    ProfileSetupPageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .permissions:
                    PermissionsPageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .completion:
                    CompletionPageView()
                        .transition(.opacity)
                }
            }
            
            // Navigation Buttons
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    // Skip button (only show on certain pages)
                    if shouldShowSkip {
                        Button("Skip") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                coordinator.skipToNext()
                            }
                        }
                        .foregroundColor(.tabiGray)
                        .font(.body)
                    }
                    
                    Spacer()
                    
                    // Next/Continue button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            coordinator.nextPage()
                        }
                    }) {
                        Text(buttonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: buttonWidth)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.tabiOrange, Color.tabiOrange.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color.tabiOrange.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(!canProceed)
                    .opacity(canProceed ? 1.0 : 0.5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .environment(coordinator)
        .onAppear {
            // Auto-advance from splash after 2 seconds
            if coordinator.currentPage == .splash {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        coordinator.nextPage()
                    }
                }
            }
        }
        .onChange(of: coordinator.isOnboardingComplete) { _, newValue in
            if newValue {
                isOnboardingComplete = true
            }
        }
    }
    
    private var shouldShowSkip: Bool {
        switch coordinator.currentPage {
        case .profileSetup, .permissions:
            return true
        default:
            return false
        }
    }
    
    private var buttonTitle: String {
        switch coordinator.currentPage {
        case .splash:
            return "Get Started"
        case .welcome:
            return "Continue"
        case .authentication:
            return "Sign Up For Free"
        case .profileSetup:
            return "Next"
        case .permissions:
            return "Enable Permissions"
        case .completion:
            return "Start Using Tabi"
        }
    }
    
    private var buttonWidth: CGFloat? {
        switch coordinator.currentPage {
        case .authentication:
            return nil // Full width for auth page
        default:
            return 200
        }
    }
    
    private var canProceed: Bool {
        switch coordinator.currentPage {
        case .profileSetup:
            return !coordinator.firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .authentication:
            return false // Auth buttons handle their own navigation
        default:
            return true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
