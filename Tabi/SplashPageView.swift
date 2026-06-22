import SwiftUI

// MARK: - Splash Page (Tabi Logo)

struct SplashPageView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.tabiOrange.opacity(0.1),
                    Color.tabiLavender.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated logo
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.tabiOrange, Color.tabiLavender],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "pills.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.tabiOrange.opacity(0.4), radius: 30, x: 0, y: 15)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text("TABI")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.tabiOrange, Color.tabiLavender],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(logoOpacity)
                
                Text("Your Medication Companion")
                    .font(.subheadline)
                    .foregroundColor(.tabiGray)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.6)) {
                logoOpacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashPageView()
}
