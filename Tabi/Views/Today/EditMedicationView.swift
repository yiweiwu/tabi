import SwiftUI

// MARK: - Edit Medication View

struct EditMedicationView: View {
    let medication: Medication
    @ObservedObject var medicationManager: MedicationManager
    @Environment(\.dismiss) private var dismiss

    @State private var genericName: String
    @State private var brandName: String
    @State private var dosage: String
    @State private var frequencyPerDay: Int
    @State private var doseTimes: [Date]

    init(medication: Medication, medicationManager: MedicationManager) {
        self.medication = medication
        self.medicationManager = medicationManager
        _genericName = State(initialValue: medication.genericName)
        _brandName = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _frequencyPerDay = State(initialValue: medication.frequencyPerDay)
        _doseTimes = State(initialValue: MedicationScheduleParser.times(for: medication.resolvedDoseTimeMinutes))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Generic name", text: $genericName)
                    TextField("Brand name (optional)", text: $brandName)
                    TextField("Dosage", text: $dosage)
                }

                Section("Schedule") {
                    Stepper("Times per day: \(frequencyPerDay)", value: $frequencyPerDay, in: 1...4)
                        .onChange(of: frequencyPerDay) { _, newCount in resizeDoseTimes(to: newCount) }

                    ForEach(doseTimes.indices, id: \.self) { i in
                        DatePicker("Dose \(i + 1)", selection: $doseTimes[i], displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(genericName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func resizeDoseTimes(to count: Int) {
        if doseTimes.count < count {
            let defaults = MedicationScheduleParser.times(for: MedicationScheduleParser.defaultDoseTimeMinutes(for: count))
            doseTimes.append(contentsOf: defaults.suffix(count - doseTimes.count))
        } else if doseTimes.count > count {
            doseTimes.removeLast(doseTimes.count - count)
        }
    }

    private func save() {
        var updated = medication
        updated.genericName = genericName
        updated.name = brandName.isEmpty ? genericName : brandName
        updated.dosage = dosage
        updated.frequencyPerDay = frequencyPerDay
        let cal = Calendar.current
        updated.doseTimeMinutes = doseTimes
            .map { cal.component(.hour, from: $0) * 60 + cal.component(.minute, from: $0) }
            .sorted()
        medicationManager.update(updated)
        dismiss()
    }
}
