import SwiftUI

// MARK: - Privacy Policy (interim, in-app disclosure)

// This is a plain-language summary of what Tabi actually does with your
// data today, not a finalized legal document - see PRIVACY_COMPLIANCE.md
// at the repo root.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PolicySection(
                        title: "What we collect",
                        body: "Your medications, dosage, and schedule; when you mark a dose taken; and anything optional you add yourself — age, gender, height, weight, allergies, pharmacy info, and a profile photo."
                    )

                    PolicySection(
                        title: "Why",
                        body: "To run your reminders, track your dose history, and show your progress. Optional fields personalize the app but are never required to use it."
                    )

                    PolicySection(
                        title: "Who sees it",
                        body: "Only you, by default. If you invite someone as a caretaker, they see your medication names, schedule, and whether you've taken a dose — and only after they've confirmed the invite themselves."
                    )

                    PolicySection(
                        title: "Third parties",
                        body: "When you scan a prescription label, the label's text (not the photo) is sent to a third-party AI service to extract the medication name, dosage, and schedule. Your account and app data are stored with our cloud hosting provider. We don't sell your data or share it with advertisers. The specific companies we currently use are listed in the full Privacy Policy."
                    )

                    PolicySection(
                        title: "Your controls",
                        body: "You can delete your account and everything associated with it at any time from Settings → Privacy → Delete My Account & Data."
                    )
                }
                .padding(20)
            }
            .background(Color.tabiBG)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PolicySection: View {
    let title: String
    let body_: String

    init(title: String, body: String) {
        self.title = title
        self.body_ = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(body_)
                .font(.subheadline)
                .foregroundColor(.tabiGray)
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyPolicyView()
}
