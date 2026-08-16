import SwiftUI

// MARK: - Onboarding Coordinator

@MainActor
@Observable
class OnboardingCoordinator {
    var currentPage: OnboardingPage = .welcome
    var isOnboardingComplete = false

    // Profile data
    var firstName = ""
    var lastName = ""
    var age = ""
    var selectedGender = "Prefer not to say"

    enum OnboardingPage {
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
            // Persist as soon as the user leaves this page rather than
            // waiting for completeOnboarding() - otherwise a name typed
            // here is only ever held in this in-memory coordinator, and
            // backgrounding/killing the app anywhere before the final
            // completion page (e.g. mid system permission prompt) silently
            // loses it, since a fresh OnboardingCoordinator is created next
            // launch. Mirrors the returning-user load bug fixed in #24, but
            // for data going the other direction.
            syncProfileToStore()
            currentPage = .permissions
        case .permissions:
            currentPage = .completion
        case .completion:
            completeOnboarding()
        }
    }

    func previousPage() {
        switch currentPage {
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
        case .welcome:
            break // Can't go back from welcome - it's now the first page
        }
    }
    
    func skipToNext() {
        nextPage()
    }
    
    func completeOnboarding() {
        syncProfileToStore()
        isOnboardingComplete = true
    }

    private func syncProfileToStore() {
        var profile = UserProfileStore.shared.profile
        profile.firstName = firstName
        profile.lastName = lastName
        profile.age = age
        profile.gender = selectedGender
        UserProfileStore.shared.profile = profile
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
                case .welcome:
                    WelcomeToTabiPageView()
                        .transition(.opacity)
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
                    .padding(.bottom, bottomButtonPadding)
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
        case .welcome:
            return "Get Started"
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

    // Permissions and completion pages both have content (the disclosure
    // text / Quick Tips) that sits close to the button, so they need it
    // lifted further off the bottom edge than other pages.
    private var bottomButtonPadding: CGFloat {
        switch coordinator.currentPage {
        case .permissions:
            return 72
        case .completion:
            return 110
        default:
            return 40
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
                .foregroundColor(.tabiLavender)
                .font(.body)
                .padding(.top, 16)
                .padding(.trailing, 24)
            }

            Spacer(minLength: 24)

            // Medication list preview with notification callout
            MedicationListPreviewCard()
                .frame(width: 280)

            Spacer(minLength: 24)

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
            Text("We'll remind you right on time. Get notified so you never miss a dose.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
        }
    }
}

// MARK: - Medication List Preview (pill reminders illustration)

struct MedicationListPreviewCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("My Medications")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "bell")
                        .foregroundColor(.tabiLavender)
                }

                Divider()

                Text("Today")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    MedPreviewRow(color: pillColors[1], name: "Pill A", time: "8:00 AM")
                    MedPreviewRow(color: pillColors[2], name: "Pill B", time: "2:00 PM")
                    MedPreviewRow(color: pillColors[4], name: "Pill C", time: "8:00 PM")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.tabiLavLight)
            )

            NotificationBubble()
                .padding(.leading, 4)
                .offset(y: 66)
        }
    }
}

struct MedPreviewRow: View {
    let color: Color
    let name: String
    let time: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "pill.fill")
                        .font(.system(size: 15))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(-45))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("1 tablet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(time)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(color.opacity(0.16))
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.tabiCard)
        )
    }
}

struct NotificationBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.tabiLavender)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                Circle()
                    .fill(Color.tabiRed)
                    .frame(width: 10, height: 10)
                    .offset(x: 3, y: -3)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Time to take Pill A")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("now")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.tabiLavender)
                }
                Text("It's time for your 8:00 AM dose.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.tabiCard)
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
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
            // Fixed-height container matching the other intro pages' image
            // frame (380pt) so this page's shorter, wider photo still starts
            // at the same top position instead of sitting lower on screen.
            Image("family-sharing")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 360)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(height: 380, alignment: .top)
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

