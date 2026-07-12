import SwiftUI
import AuthenticationServices

// MARK: - Authentication Page

struct AuthenticationPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var showEmailSignUp = false
    @State private var showPhoneSignUp = false
    
    var body: some View {
        ZStack {
            Color.tabiBG.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Tabi logo and title
                    VStack(spacing: 12) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.tabiLavender)
                        
                        Text("Tabi")
                            .font(.title.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 60)
                    
                    // Social Login Buttons
                    VStack(spacing: 12) {
                        // Continue with Google
                        SocialLoginButton(
                            icon: "g.circle.fill",
                            title: "Continue with Google",
                            iconColor: .red
                        ) {
                            handleGoogleSignIn()
                        }
                        
                        // Continue with Facebook
                        SocialLoginButton(
                            icon: "f.circle.fill",
                            title: "Continue with Facebook",
                            iconColor: Color(red: 0.23, green: 0.35, blue: 0.60)
                        ) {
                            handleFacebookSignIn()
                        }
                        
                        // Continue with Apple
                        SocialLoginButton(
                            icon: "apple.logo",
                            title: "Continue with Apple",
                            iconColor: .black
                        ) {
                            handleSignInWithApple()
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        // User name section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User name")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.tabiGray)
                                TextField("Full name", text: .constant(""))
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                            }
                            .padding()
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Email section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.tabiGray)
                                TextField("Email address", text: .constant(""))
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Password section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.tabiGray)
                                SecureField("Password", text: .constant(""))
                                    .textContentType(.newPassword)
                                
                                Button(action: {
                                    // Toggle password visibility
                                }) {
                                    Image(systemName: "eye")
                                        .foregroundColor(.tabiGray)
                                }
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
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    
                    // Continue Button (smaller, centered)
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                coordinator.nextPage()
                            }
                        }) {
                            Text("Continue")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.tabiLavender)
                                )
                        }
                        Spacer()
                    }
                    .padding(.top, 12)
                    
                    // Sign in link
                    HStack(spacing: 4) {
                        Text("Do you have account?")
                            .font(.subheadline)
                            .foregroundColor(.tabiGray)
                        
                        Button("Sign in") {
                            // Handle sign in
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.tabiLavender)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            
            // Skip button overlay
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            coordinator.currentPage = .profileSetup
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.top, 50)
                    .padding(.trailing, 24)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpSheet()
        }
        .sheet(isPresented: $showPhoneSignUp) {
            PhoneSignUpSheet()
        }
    }
    
    // MARK: - Authentication Handlers
    
    private func handleSignInWithApple() {
        print("Sign in with Apple tapped")
        coordinator.nextPage()
    }
    
    private func handleGoogleSignIn() {
        print("Google Sign In tapped")
        coordinator.nextPage()
    }
    
    private func handleFacebookSignIn() {
        print("Facebook Sign In tapped")
        coordinator.nextPage()
    }
}

// MARK: - Social Login Button Component

struct SocialLoginButton: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
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

// MARK: - Auth Button Component (Legacy)

struct AuthButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    var borderColor: Color? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.body.weight(.medium))
                
                Spacer()
            }
            .foregroundColor(foregroundColor)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor ?? Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Email Sign Up Sheet

struct EmailSignUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Sign Up with Email")
                        .font(.title2.bold())
                    
                    Text("Create your Tabi account")
                        .font(.body)
                        .foregroundColor(.tabiGray)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.tabiCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.tabiCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.tabiCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 32)
                
                Button(action: {
                    handleEmailSignUp()
                }) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.tabiOrange)
                        )
                }
                .padding(.horizontal, 32)
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
    
    private func handleEmailSignUp() {
        print("Email sign up: \(email)")
        dismiss()
        coordinator.nextPage()
    }
}

// MARK: - Phone Sign Up Sheet

struct PhoneSignUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var codeSent = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Sign Up with Phone")
                        .font(.title2.bold())
                    
                    Text(codeSent ? "Enter the code sent to your phone" : "We'll send you a verification code")
                        .font(.body)
                        .foregroundColor(.tabiGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    if !codeSent {
                        TextField("Phone Number", text: $phoneNumber)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        TextField("Verification Code", text: $verificationCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)
                
                Button(action: {
                    if codeSent {
                        handleVerifyCode()
                    } else {
                        handleSendCode()
                    }
                }) {
                    Text(codeSent ? "Verify" : "Send Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.tabiOrange)
                        )
                }
                .padding(.horizontal, 32)
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if codeSent {
            return verificationCode.count >= 4
        } else {
            return phoneNumber.count >= 10
        }
    }
    
    private func handleSendCode() {
        print("Sending code to: \(phoneNumber)")
        withAnimation {
            codeSent = true
        }
    }
    
    private func handleVerifyCode() {
        print("Verifying code: \(verificationCode)")
        dismiss()
        coordinator.nextPage()
    }
}

// MARK: - Preview

#Preview {
    AuthenticationPageView()
        .environment(OnboardingCoordinator())
}
