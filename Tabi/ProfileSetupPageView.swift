import SwiftUI

// MARK: - Profile Setup Page

struct ProfileSetupPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    
    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say", "Other"]
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentPage = .permissions
                    }
                }
                .foregroundColor(.tabiGray)
                .font(.body)
                .padding(.top, 16)
                .padding(.trailing, 24)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.tabiLavender)
                    
                    Text("Let's Get Started")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                    
                    Text("Help us personalize your experience")
                        .font(.body)
                        .foregroundColor(.tabiGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            
            // Form fields
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Name")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    TextField("Enter your first name", text: $bindableCoordinator.firstName)
                        .textContentType(.givenName)
                        .autocapitalization(.words)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.tabiCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age (Optional)")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    TextField("Enter your age", text: $bindableCoordinator.age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.tabiCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender (Optional)")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    Menu {
                        ForEach(genderOptions, id: \.self) { option in
                            Button(option) {
                                coordinator.selectedGender = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(coordinator.selectedGender)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.tabiGray)
                        }
                        .padding()
                        .background(Color.tabiCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSetupPageView()
        .environment(OnboardingCoordinator())
}
