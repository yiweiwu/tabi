import SwiftUI

// MARK: - Detected Medication View (Review & Confirm after scanning a label)

struct DetectedMedicationView: View {
    let image: UIImage
    @State var detectedInfo: DetectedMedicationInfo
    let onSave: (DetectedMedicationInfo) -> Void
    let onCancel: () -> Void

    private let detectedSchedule: String
    @State private var useCustomSchedule = false
    @State private var customScheduleText = ""

    init(image: UIImage, detectedInfo: DetectedMedicationInfo,
         onSave: @escaping (DetectedMedicationInfo) -> Void,
         onCancel: @escaping () -> Void) {
        self.image = image
        self._detectedInfo = State(initialValue: detectedInfo)
        let times = MedicationScheduleParser.scheduledTimes(for: detectedInfo.frequencyPerDay)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        self.detectedSchedule = times.map { formatter.string(from: $0) }.joined(separator: ", ")
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 200).cornerRadius(12).padding()
                    VStack(spacing: 16) {
                        field("Generic Name", placeholder: "e.g., Hydrocodone-Acetaminophen", binding: $detectedInfo.genericName, bold: true)
                        field("Brand Name", placeholder: "e.g., Lortab (leave empty if none)", binding: $detectedInfo.brandName)
                        field("Dosage", placeholder: "e.g., 1000 mcg", binding: $detectedInfo.dosage)
                        scheduleField
                    }
                    .padding(.horizontal)
                    VStack(spacing: 12) {
                        Button {
                            var info = detectedInfo
                            info.schedule = useCustomSchedule ? customScheduleText : detectedSchedule
                            onSave(info)
                        } label: {
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
    private var scheduleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Schedule").font(.caption).foregroundColor(.tabiGray)

            Menu {
                Button { useCustomSchedule = false } label: {
                    HStack {
                        Text("Default Schedule")
                        if !useCustomSchedule { Image(systemName: "checkmark") }
                    }
                }
                Button { useCustomSchedule = true } label: {
                    HStack {
                        Text("Custom Schedule")
                        if useCustomSchedule { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                HStack {
                    Text(useCustomSchedule ? "Custom Schedule" : "Default Schedule")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray4)))
            }

            if useCustomSchedule {
                TextField("e.g., Take 1 tablet daily", text: $customScheduleText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(detectedSchedule.isEmpty ? "No schedule detected" : detectedSchedule)
                    .font(.body)
                    .foregroundColor(detectedSchedule.isEmpty ? .tabiGray : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
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
