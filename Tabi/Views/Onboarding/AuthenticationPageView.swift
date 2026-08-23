import SwiftUI
import AuthenticationServices
import GoogleSignIn

// MARK: - Authentication Page

struct AuthenticationPageView: View {
    private enum Field {
        case fullName, email, password
    }

    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var showPhoneSignUp = false
    @State private var isSignInMode = false
    @State private var currentNonce: String?
    @State private var isSigningIn = false
    @State private var authError: String?
    @State private var appleSignInCoordinator = AppleSignInCoordinator()
    @State private var showingPrivacyPolicy = false
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            Color.tabiBG.ignoresSafeArea()

            VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Image("app-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)

                        Text(isSignInMode ? "Sign in" : "Sign up")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)

                    // Form Fields
                    VStack(spacing: 12) {
                        // Name section (sign-up only - a returning user's
                        // name already lives on their profile doc)
                        if !isSignInMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                HStack {
                                    Image(systemName: "person")
                                        .foregroundColor(.tabiGray)
                                    TextField("Full name", text: $fullName)
                                        .textContentType(.name)
                                        .autocapitalization(.words)
                                        .focused($focusedField, equals: .fullName)
                                        .onChange(of: fullName) { _, newValue in
                                            let parts = newValue.trimmingCharacters(in: .whitespaces)
                                                .components(separatedBy: " ")
                                            coordinator.firstName = parts.first ?? ""
                                            coordinator.lastName = parts.dropFirst().joined(separator: " ")
                                        }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color.tabiCard)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }

                        // Email section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.tabiGray)
                                TextField("Email address", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
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
                                SecureField("Password", text: $password)
                                    .textContentType(isSignInMode ? .password : .newPassword)
                                    .focused($focusedField, equals: .password)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
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
                        Button(action: handleEmailContinue) {
                            Text(isSignInMode ? "Sign in" : "Continue")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.tabiLavender)
                                )
                        }
                        .disabled(!isEmailFormValid || isSigningIn)
                        .opacity(isEmailFormValid ? 1.0 : 0.5)
                        Spacer()
                    }
                    .padding(.top, 4)

                    // "or" divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(height: 1)
                        Text("or")
                            .font(.footnote)
                            .foregroundColor(.tabiGray)
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)

                    // Social Login Buttons
                    VStack(spacing: 12) {
                        // Continue with Google
                        SocialLoginButton(
                            icon: "g.circle.fill",
                            title: "Continue with Google",
                            iconColor: .red
                        ) {
                            Task { await handleGoogleSignIn() }
                        }
                        .disabled(isSigningIn)

                        // Continue with Apple
                        SocialLoginButton(
                            icon: "apple.logo",
                            title: "Continue with Apple",
                            iconColor: .black
                        ) {
                            handleSignInWithApple()
                        }
                        .disabled(isSigningIn)

                        // Continue with Facebook
                        SocialLoginButton(
                            icon: "f.circle.fill",
                            title: "Continue with Facebook",
                            iconColor: Color(red: 0.23, green: 0.35, blue: 0.60)
                        ) {
                            handleFacebookSignIn()
                        }
                    }
                    .padding(.horizontal, 32)

                    // Terms & Privacy disclosure — one Button around a
                    // concatenated Text so the sentence wraps as a single
                    // paragraph instead of an HStack splitting mid-line on
                    // narrow screens; the whole line is tappable, with
                    // "Privacy Policy" styled to signal it's the link.
                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        (Text("By continuing, you agree to Tabi's Terms and ")
                            .foregroundColor(.tabiGray)
                        + Text("Privacy Policy")
                            .foregroundColor(.tabiLavender)
                            .fontWeight(.semibold))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                    // Sign in / sign up toggle
                    HStack(spacing: 4) {
                        Text(isSignInMode ? "Don't have an account?" : "Do you have account?")
                            .font(.subheadline)
                            .foregroundColor(.tabiGray)

                        Button(isSignInMode ? "Sign up" : "Sign in") {
                            authError = nil
                            isSignInMode.toggle()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.tabiLavender)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 16)
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
                    .foregroundColor(.tabiGray)
                    .font(.body)
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                }
                Spacer()
            }

            if let authError {
                VStack {
                    Spacer()
                    Text(authError)
                        .font(.caption)
                        .foregroundColor(.tabiRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showPhoneSignUp) {
            PhoneSignUpSheet()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Authentication Handlers

    private var isEmailFormValid: Bool {
        guard !email.isEmpty, password.count >= 6 else { return false }
        return isSignInMode || !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func handleEmailContinue() {
        focusedField = nil
        authError = nil
        isSigningIn = true
        Task {
            do {
                if isSignInMode {
                    _ = try await AuthenticationManager.shared.signIn(withEmail: email, password: password)
                } else {
                    _ = try await AuthenticationManager.shared.signUp(withEmail: email, password: password)
                    MedicationStore.shared.discardLegacyMedicationsForNewAccount()
                }
                await UserProfileStore.shared.fetchIfNeeded()
                prefillFromExistingProfile()
                isSigningIn = false
                // A brand-new signup is always subject to the gate - it's
                // deterministically a fresh account, so there's no need to
                // wait on the onUserCreate claim (which may not have
                // propagated to a token fetched this instant) to know that.
                // A sign-in has to actually check: an old, pre-feature
                // account is just as unverified but was never asked to be,
                // and should never see this gate - see
                // currentUserRequiresEmailVerificationGate().
                let requiresGate: Bool
                if isSignInMode {
                    requiresGate = await AuthenticationManager.shared.currentUserRequiresEmailVerificationGate()
                } else {
                    requiresGate = !AuthenticationManager.shared.isCurrentUserEmailVerified
                }
                if requiresGate {
                    coordinator.currentPage = .emailVerification
                } else {
                    coordinator.nextPage()
                }
            } catch {
                isSigningIn = false
                authError = AuthenticationManager.friendlyMessage(for: error)
            }
        }
    }

    private func handleSignInWithApple() {
        let nonce = AuthenticationManager.shared.startSignInWithAppleFlow()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthenticationManager.sha256(nonce)

        appleSignInCoordinator.onCompletion = { result in
            handleSignInWithAppleResult(result)
        }
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = appleSignInCoordinator
        controller.presentationContextProvider = appleSignInCoordinator
        controller.performRequests()
    }

    private func handleSignInWithAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Unexpected Apple sign-in credential."
                return
            }
            guard let nonce = currentNonce else {
                authError = AuthenticationError.missingAppleNonce.errorDescription
                return
            }
            guard let identityToken = credential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                authError = AuthenticationError.missingAppleIdentityToken.errorDescription
                return
            }
            authError = nil
            isSigningIn = true
            Task {
                do {
                    let authResult = try await AuthenticationManager.shared.signInWithApple(idTokenString: idTokenString, nonce: nonce, fullName: credential.fullName)
                    if authResult.additionalUserInfo?.isNewUser == true {
                        MedicationStore.shared.discardLegacyMedicationsForNewAccount()
                    }
                    await UserProfileStore.shared.fetchIfNeeded()
                    prefillFromExistingProfile()
                    prefillNameIfNewAccount(givenName: credential.fullName?.givenName, familyName: credential.fullName?.familyName)
                    isSigningIn = false
                    coordinator.nextPage()
                } catch {
                    isSigningIn = false
                    authError = AuthenticationManager.friendlyMessage(for: error)
                }
            }
        case .failure(let error):
            authError = error.localizedDescription
        }
    }

    private func handleGoogleSignIn() async {
        guard let presentingViewController = Self.rootViewController() else {
            authError = "Unable to present Google sign-in."
            return
        }
        authError = nil
        isSigningIn = true
        do {
            let authResult = try await AuthenticationManager.shared.signInWithGoogle(presenting: presentingViewController)
            if authResult.additionalUserInfo?.isNewUser == true {
                MedicationStore.shared.discardLegacyMedicationsForNewAccount()
            }
            await UserProfileStore.shared.fetchIfNeeded()
            prefillFromExistingProfile()
            let profile = GIDSignIn.sharedInstance.currentUser?.profile
            prefillNameIfNewAccount(givenName: profile?.givenName, familyName: profile?.familyName)
            isSigningIn = false
            coordinator.nextPage()
        } catch {
            isSigningIn = false
            authError = AuthenticationManager.friendlyMessage(for: error)
        }
    }

    // Populates onboarding's profile fields from an already-persisted
    // Firestore profile right after a sign-in's fetchIfNeeded() completes -
    // covers every returning-user path (email sign-in, and Apple/Google
    // when the account already existed). Without this, ProfileSetupPageView
    // binds directly to OnboardingCoordinator's fields (see
    // coordinator.firstName in that file), which otherwise stay at their
    // blank/default init values for a returning user going through
    // onboarding again (e.g. reinstalled the app, or never completed it
    // locally) - completeOnboarding() would then overwrite their real
    // name/age/gender in Firestore with those blanks. No-ops for a brand
    // new account, since its profile is still the default UserProfile().
    private func prefillFromExistingProfile() {
        let profile = UserProfileStore.shared.profile
        guard !profile.firstName.isEmpty else { return }
        coordinator.firstName = profile.firstName
        coordinator.lastName = profile.lastName
        coordinator.age = profile.age
        if !profile.gender.isEmpty { coordinator.selectedGender = profile.gender }
    }

    // Apple/Google both hand back the account's name on first sign-in - use
    // it so a brand-new user isn't retyping a name the provider already
    // gave us. Only applies to new accounts: if prefillFromExistingProfile()
    // above already found a returning user's saved profile, firstName is
    // already set and this is skipped so we don't clobber it.
    private func prefillNameIfNewAccount(givenName: String?, familyName: String?) {
        // Don't clobber a name the user already typed into the "Full name"
        // field on this page, or one a returning account already has saved.
        guard coordinator.firstName.isEmpty, UserProfileStore.shared.profile.firstName.isEmpty else { return }
        if let givenName, !givenName.isEmpty { coordinator.firstName = givenName }
        if let familyName, !familyName.isEmpty { coordinator.lastName = familyName }
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
    
    private func handleFacebookSignIn() {
        print("Facebook Sign In tapped")
        coordinator.nextPage()
    }
}

// MARK: - Apple Sign In Coordinator

// The redesigned Create Account screen uses a custom-styled button for Apple
// sign-in instead of the native SignInWithAppleButton, so the
// ASAuthorizationController flow has to be driven manually via this delegate.
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
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
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
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
