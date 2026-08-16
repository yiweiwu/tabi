import SwiftUI

// MARK: - Completion Page

struct CompletionPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var checkmarkScale: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Skip button
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            coordinator.completeOnboarding()
                        }
                    }
                    .foregroundColor(.tabiGray)
                    .font(.body)
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                }
                Spacer()
            }
            .zIndex(1)

            VStack(spacing: 20) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.tabiOrange, Color.tabiLavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.tabiOrange.opacity(0.3), radius: 20, x: 0, y: 10)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(checkmarkScale)
                .padding(.top, 40)

                // Welcome message
                VStack(spacing: 10) {
                    Text("You're All Set!")
                        .font(.title.bold())
                        .foregroundColor(.primary)

                    if !coordinator.firstName.isEmpty {
                        Text("Welcome to Tabi, \(coordinator.firstName)!")
                            .font(.title3)
                            .foregroundColor(.tabiOrange)
                    }

                    Text("Start tracking your medications and never miss a dose")
                        .font(.body)
                        .foregroundColor(.tabiGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Quick tips
                VStack(spacing: 14) {
                    Text("Quick Tips")
                        .font(.headline)
                        .foregroundColor(.primary)

                    QuickTipRow(
                        icon: "plus.circle.fill",
                        text: "Tap + to add your first medication"
                    )

                    QuickTipRow(
                        icon: "camera.fill",
                        text: "Take a picture of your pill bottle"
                    )

                    QuickTipRow(
                        icon: "bell.badge.fill",
                        text: "We'll remind you when it's time to take your meds"
                    )
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                checkmarkScale = 1.0
            }
        }
    }
}

// MARK: - Quick Tip Row

struct QuickTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.tabiLavender)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color.tabiCard)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    CompletionPageView()
        .environment(OnboardingCoordinator())
}
