import SwiftUI

// MARK: - Email Verification Gate

// Shown right after a new email/password signup (and again on a
// still-unverified sign-in) instead of letting onboarding continue -
// firestore.rules blocks this account's first document write until
// email_verified is true, so there's nothing useful onboarding can do past
// this point yet. No Skip button, unlike the other onboarding pages - the
// point of this screen is that skipping isn't possible for this account.
//
// Detection is automatic, not a button tap: Firebase never pushes an
// isEmailVerified change to an existing session, so this polls quietly
// while visible and also re-checks the moment the app returns to
// foreground - the two moments a "did they click the link yet" check is
// actually worth making (right after they switch back from Mail/Safari,
// and as a low-frequency backup for verifying from a different device).
struct EmailVerificationGateView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var isResending = false
    @State private var resendCooldownRemaining = 0
    @State private var resendMessage: String?
    @State private var resendMessageIsError = false

    @State private var isCheckingVerification = false
    @State private var pollTask: Task<Void, Never>?

    private let cooldownSeconds = 60
    private let pollIntervalSeconds: UInt64 = 5

    var body: some View {
        ZStack {
            Color.tabiBG.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.tabiLavender)

                VStack(spacing: 12) {
                    Text("Check your inbox")
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("We sent a verification link to \(currentEmail). Click it - this screen will continue on its own.")
                        .font(.body)
                        .foregroundColor(.tabiGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for verification...")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }

                if let resendMessage {
                    Text(resendMessage)
                        .font(.caption)
                        .foregroundColor(resendMessageIsError ? .tabiRed : .tabiGreen)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Button(action: handleResendTapped) {
                    Text(resendButtonTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(resendCooldownRemaining > 0 ? .tabiGray : .tabiLavender)
                }
                .disabled(isResending || resendCooldownRemaining > 0)
                .padding(.bottom, 40)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await checkVerification() }
            }
        }
    }

    private var currentEmail: String {
        AuthenticationManager.shared.currentUser?.email ?? "your email"
    }

    private var resendButtonTitle: String {
        if resendCooldownRemaining > 0 {
            return "Resend in \(resendCooldownRemaining)s"
        }
        return isResending ? "Sending..." : "Resend email"
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await checkVerification()
                do {
                    try await Task.sleep(nanoseconds: pollIntervalSeconds * 1_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    // Shared by both the poll loop and the foreground-return trigger -
    // guarded by isCheckingVerification so an app-switch landing mid-poll
    // can't fire two overlapping reload() calls.
    private func checkVerification() async {
        guard !isCheckingVerification else { return }
        isCheckingVerification = true
        defer { isCheckingVerification = false }
        do {
            let verified = try await AuthenticationManager.shared.reloadAndCheckEmailVerified()
            if verified {
                pollTask?.cancel()
                coordinator.nextPage()
            }
        } catch {
            // Transient network/reload failures are expected here (e.g. no
            // connectivity right as the app resumes) - the next poll tick
            // or foreground event retries, so this doesn't need to
            // interrupt the user with an error state, just get logged.
            print("Email verification check failed: \(error)")
        }
    }

    private func handleResendTapped() {
        resendMessage = nil
        isResending = true
        Task {
            do {
                try await AuthenticationManager.shared.resendVerificationEmail()
                isResending = false
                resendMessage = "Verification email sent."
                resendMessageIsError = false
                startCooldown()
            } catch EmailVerificationError.alreadyVerified {
                isResending = false
                pollTask?.cancel()
                coordinator.nextPage()
            } catch {
                isResending = false
                resendMessage = error.localizedDescription
                resendMessageIsError = true
            }
        }
    }

    private func startCooldown() {
        resendCooldownRemaining = cooldownSeconds
        Task {
            while resendCooldownRemaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                resendCooldownRemaining -= 1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailVerificationGateView()
        .environment(OnboardingCoordinator())
}
