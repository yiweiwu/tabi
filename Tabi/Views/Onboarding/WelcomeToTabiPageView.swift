import SwiftUI

// MARK: - Welcome to Tabi Page

struct WelcomeToTabiPageView: View {
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
            
            VStack(spacing: 40) {
            Spacer()
            
            // App Logo/Icon
            VStack(spacing: 20) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.tabiOrange, Color.tabiLavender],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "pills.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.tabiOrange.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Text("Welcome to Tabi")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            
            // Description
            Text("Stay on top of your meds with ease")
                .font(.body)
                .foregroundColor(.tabiGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            
            // Features list
            VStack(spacing: 20) {
                OnboardingFeatureRow(
                    icon: "camera.fill",
                    title: "Scan & Add",
                    description: "Quickly add meds by scanning labels"
                )
                
                OnboardingFeatureRow(
                    icon: "checklist",
                    title: "Track Medications",
                    description: "Never miss a dose with smart reminders"
                )
                
                OnboardingFeatureRow(
                    icon: "person.2.fill",
                    title: "Share & Care",
                    description: "Connect with family and caregivers"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.vertical, 40)
        }
    }
}

// MARK: - Feature Row Component

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.tabiLavLight)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.tabiLavender)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.tabiGray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeToTabiPageView()
}
