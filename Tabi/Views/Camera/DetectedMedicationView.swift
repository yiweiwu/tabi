import SwiftUI

// MARK: - Detected Medication View (Review & Confirm after scanning a label)

struct DetectedMedicationView: View {
    let image: UIImage
    @State var detectedInfo: DetectedMedicationInfo
    let onSave: (DetectedMedicationInfo) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 200).cornerRadius(12).padding()
                    VStack(spacing: 16) {
                        field("Generic Name", placeholder: "e.g., Hydrocodone-Acetaminophen", binding: $detectedInfo.genericName, bold: true)
                        field("Brand Name", placeholder: "e.g., Lortab (leave empty if none)", binding: $detectedInfo.brandName)
                        field("Dosage", placeholder: "e.g., 1000 mcg", binding: $detectedInfo.dosage)
                        field("Schedule", placeholder: "e.g., Take 1 tablet daily", binding: $detectedInfo.schedule)
                        if !detectedInfo.allDetectedText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("All Detected Text").font(.caption).foregroundColor(.tabiGray)
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(detectedInfo.allDetectedText.prefix(8), id: \.self) { Text("• \($0)").font(.caption2).foregroundColor(.tabiGray) }
                                }
                                .padding().background(Color.tabiBG).cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    VStack(spacing: 12) {
                        Button { onSave(detectedInfo) } label: {
                            Text("Save Medication").font(.headline).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding().background(Color.tabiOrange).cornerRadius(12)
                        }
                        Button("Cancel") { onCancel() }.font(.subheadline).foregroundColor(.tabiGray)
                    }
                    .padding(.horizontal).padding(.bottom)
                }
            }
            .navigationTitle("Confirm Medication")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func field(_ label: String, placeholder: String, binding: Binding<String>, bold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.tabiGray)
            TextField(placeholder, text: binding)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(bold ? .body.bold() : .body)
        }
    }
}
