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
        case medicineTracking
        case pillReminders
        case familySharing
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
            currentPage = .medicineTracking
        case .medicineTracking:
            currentPage = .pillReminders
        case .pillReminders:
            currentPage = .familySharing
        case .familySharing:
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
    
    func previousPage() {
        switch currentPage {
        case .welcome:
            currentPage = .splash
        case .medicineTracking:
            currentPage = .welcome
        case .pillReminders:
            currentPage = .medicineTracking
        case .familySharing:
            currentPage = .pillReminders
        case .authentication:
            currentPage = .familySharing
        case .profileSetup:
            currentPage = .authentication
        case .permissions:
            currentPage = .profileSetup
        case .completion:
            currentPage = .permissions
        case .splash:
            break // Can't go back from splash
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
                case .medicineTracking:
                    MedicineTrackingPageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .pillReminders:
                    PillRemindersPageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .familySharing:
                    FamilySharingPageView()
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
            if shouldShowBottomNavigation {
                VStack {
                    Spacer()
                    
                    // Centered Continue button
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                coordinator.nextPage()
                            }
                        }) {
                            Text(buttonTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.tabiLavender)
                                )
                        }
                        .disabled(!canProceed)
                        .opacity(canProceed ? 1.0 : 0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .environment(coordinator)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    // Swipe left to go to next page
                    if gesture.translation.width < -50 && canProceed {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            coordinator.nextPage()
                        }
                    }
                    // Swipe right to go to previous page
                    else if gesture.translation.width > 50 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            coordinator.previousPage()
                        }
                    }
                }
        )
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
    
    private var shouldShowBottomNavigation: Bool {
        // Hide bottom navigation on authentication page since it has its own buttons
        coordinator.currentPage != .authentication
    }
    
    private var buttonTitle: String {
        switch coordinator.currentPage {
        case .splash:
            return "Continue"
        case .welcome:
            return "Continue"
        case .medicineTracking, .pillReminders, .familySharing:
            return "Continue"
        case .authentication:
            return "Continue"
        case .profileSetup:
            return "Continue"
        case .permissions:
            return "Continue"
        case .completion:
            return "Start Using Tabi"
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
// MARK: - Medicine Tracking Page

struct MedicineTrackingPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentPage = .authentication
                    }
                }
                .foregroundColor(.tabiGray)
                .font(.body)
                .padding(.top, 16)
                .padding(.trailing, 24)
            }
            
            Spacer()
            
            // Image/Illustration Area
            Image("medicine-scanning")
                .resizable()
                .scaledToFill()
                .frame(width: 280, height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 40)
            
            // Page indicator dots
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.tabiOrange)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 20)
            
            // Title
            Text("Effortless Medicine Tracking")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            
            // Description
            Text("Snap your prescription, and we'll handle the rest – medicine tracking!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
        }
    }
}

// MARK: - Pill Reminders Page

struct PillRemindersPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentPage = .authentication
                    }
                }
                .foregroundColor(.tabiGray)
                .font(.body)
                .padding(.top, 16)
                .padding(.trailing, 24)
            }
            
            Spacer()
            
            // Image/Illustration Area
            ZStack {
                // Background image simulation
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 380)
                
                VStack {
                    // Person image placeholder
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 280, height: 220)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.7))
                        )
                    
                    Spacer()
                    
                    // Pill reminder cards
                    HStack(spacing: 12) {
                        PillReminderCard(color: .purple.opacity(0.4), time: "8 A", label: "PILL A")
                        PillReminderCard(color: .yellow.opacity(0.5), time: "2 A", label: "PILL B")
                        PillReminderCard(color: .yellow.opacity(0.6), time: "8 P", label: "PILL C")
                    }
                    .padding(.bottom, 20)
                }
                .frame(width: 280, height: 380)
            }
            .padding(.bottom, 40)
            
            // Page indicator dots
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.tabiOrange)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 20)
            
            // Title
            Text("Personalized Pill Reminders")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            
            // Description
            Text("We'll remind you when to take your pill so you stay on track.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
        }
    }
}

// MARK: - Family Sharing Page

struct FamilySharingPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentPage = .authentication
                    }
                }
                .foregroundColor(.tabiGray)
                .font(.body)
                .padding(.top, 16)
                .padding(.trailing, 24)
            }
            
            Spacer()
            
            // Image/Illustration Area
            ZStack {
                // Background image simulation
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 380)
                    .overlay(
                        // Family/caregiver image placeholder
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            .padding(.bottom, 40)
            
            // Page indicator dots
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.tabiOrange)
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 20)
            
            // Title
            Text("Simple Sharing with Family")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            
            // Description
            Text("Share your progress with family for theirs and your peace of mind.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
        }
    }
}

// MARK: - Pill Reminder Card Component

struct PillReminderCard: View {
    let color: Color
    let time: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(time)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(width: 70, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
        )
    }
}

