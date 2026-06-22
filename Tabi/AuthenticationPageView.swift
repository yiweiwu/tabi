import SwiftUI
import AuthenticationServices

// MARK: - Authentication Page

struct AuthenticationPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var showEmailSignUp = false
    @State private var showPhoneSignUp = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.tabiLavender)
                
                Text("Create Account")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                Text("Sign up to start tracking your medications")
                    .font(.body)
                    .foregroundColor(.tabiGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Authentication Options
            VStack(spacing: 16) {
                // Sign in with Apple
                SignInWithAppleButton(.signUp) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInWithApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
                
                // Continue with Google
                AuthButton(
                    icon: "g.circle.fill",
                    title: "Continue with Google",
                    backgroundColor: .white,
                    foregroundColor: .black,
                    borderColor: Color.gray.opacity(0.3)
                ) {
                    handleGoogleSignIn()
                }
                
                // Continue with Facebook
                AuthButton(
                    icon: "f.circle.fill",
                    title: "Continue with Facebook",
                    backgroundColor: Color(red: 0.23, green: 0.35, blue: 0.60),
                    foregroundColor: .white
                ) {
                    handleFacebookSignIn()
                }
                
                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)
                
                // Continue with Email
                AuthButton(
                    icon: "envelope.fill",
                    title: "Continue with Email",
                    backgroundColor: .tabiCard,
                    foregroundColor: .primary,
                    borderColor: Color.gray.opacity(0.3)
                ) {
                    showEmailSignUp = true
                }
                
                // Continue with Phone
                AuthButton(
                    icon: "phone.fill",
                    title: "Continue with Phone Number",
                    backgroundColor: .tabiCard,
                    foregroundColor: .primary,
                    borderColor: Color.gray.opacity(0.3)
                ) {
                    showPhoneSignUp = true
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Terms and Privacy
            VStack(spacing: 8) {
                Text("By signing up, you agree to our")
                    .font(.caption)
                    .foregroundColor(.tabiGray)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Handle terms
                    }
                    .font(.caption.bold())
                    .foregroundColor(.tabiOrange)
                    
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                    
                    Button("Privacy Policy") {
                        // Handle privacy
                    }
                    .font(.caption.bold())
                    .foregroundColor(.tabiOrange)
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.vertical, 40)
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpSheet()
        }
        .sheet(isPresented: $showPhoneSignUp) {
            PhoneSignUpSheet()
        }
    }
    
    // MARK: - Authentication Handlers
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            print("Sign in with Apple successful")
            coordinator.nextPage()
        case .failure(let error):
            print("Sign in with Apple failed: \(error)")
        }
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

// MARK: - Auth Button Component

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
