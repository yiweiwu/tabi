import SwiftUI

// MARK: - Completion Page

struct CompletionPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var confettiOpacity: Double = 0.0
    
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
            
            // Confetti background (optional decoration)
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(randomColor())
                    .frame(width: 8, height: 8)
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: CGFloat.random(in: -300...300)
                    )
                    .opacity(confettiOpacity)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
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
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.tabiOrange.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(checkmarkScale)
                
                // Welcome message
                VStack(spacing: 16) {
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
                
                Spacer()
                
                // Quick tips
                VStack(spacing: 20) {
                    Text("Quick Tips")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    QuickTipRow(
                        icon: "plus.circle.fill",
                        text: "Tap + to add your first medication"
                    )
                    
                    QuickTipRow(
                        icon: "camera.fill",
                        text: "Use the camera to scan pill bottles"
                    )
                    
                    QuickTipRow(
                        icon: "bell.badge.fill",
                        text: "Set reminders to stay on schedule"
                    )
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                checkmarkScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                confettiOpacity = 0.6
            }
        }
    }
    
    private func randomColor() -> Color {
        let colors: [Color] = [.tabiOrange, .tabiLavender, .tabiBlue, .tabiGreen, .tabiAmber]
        return colors.randomElement() ?? .tabiOrange
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
