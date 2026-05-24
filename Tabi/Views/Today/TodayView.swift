import SwiftUI

// MARK: - Today View

struct TodayView: View {
    @ObservedObject var medicationManager: MedicationManager
    @State private var showingCamera = false
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Date + week strip ──────────────────────────────────
                WeekStripHeader()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // ── Your Medications ──────────────────────────────────
                VStack(spacing: 0) {
                    HStack {
                        Text("Your Medications")
                            .font(.headline).fontWeight(.bold)
                        Spacer()
                        Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                            .font(.subheadline).foregroundColor(.tabiOrange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(medicationManager.medications) { med in
                            HStack(spacing: 0) {
                                if isEditing {
                                    Button(action: { medicationManager.remove(med) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.leading, 16)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                }
                                TABIMedicationRow(
                                    medication: med,
                                    onTake: { medicationManager.recordMedicationTaken(med, points: med.points) },
                                    onSkip: {}
                                )
                            }
                            .animation(.easeInOut(duration: 0.2), value: isEditing)
                            if med.id != medicationManager.medications.last?.id {
                                Divider().padding(.leading, isEditing ? 60 : 80)
                            }
                        }
                        Divider().padding(.leading, 80)
                        // Add Medication row
                        Button(action: { showingCamera = true }) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.tabiOrangeLight)
                                    .frame(width: 52, height: 52)
                                    .overlay(Image(systemName: "plus").font(.title3).foregroundColor(.tabiOrange))
                                Text("Add Medication")
                                    .font(.subheadline).foregroundColor(.tabiOrange)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }

                // ── Drug Interaction ──────────────────────────────────
                HStack(spacing: 12) {
                    Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "exclamationmark.triangle").font(.caption).foregroundColor(.tabiLavender))
                    Text("Drug Interaction").font(.subheadline).foregroundColor(.primary)
                    Spacer()
                    Text("😊").font(.title2)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.tabiCard).cornerRadius(14)
                .padding(.horizontal, 16).padding(.top, 14)

                // ── Upcoming Refills ──────────────────────────────────
                HStack(spacing: 12) {
                    Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "arrow.clockwise.circle").font(.caption).foregroundColor(.tabiLavender))
                    Text("Upcoming Refills").font(.subheadline).foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.tabiCard).cornerRadius(14)
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer().frame(height: 32)
            }
        }
        .background(Color.tabiBG)
        .fullScreenCover(isPresented: $showingCamera) {
            NewMedicationCameraView(medicationManager: medicationManager, isPresented: $showingCamera)
        }
    }
}

// MARK: - Week Strip Header

struct WeekStripHeader: View {
    private let cal = Calendar.current
    private let letters = ["S","M","T","W","T","F","S"]

    var weekDates: [Date] {
        let today = Date()
        let wd = cal.component(.weekday, from: today)
        let start = cal.date(byAdding: .day, value: -(wd - 1), to: cal.startOfDay(for: today)) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(todayString())
                .font(.title2).fontWeight(.bold).foregroundColor(.primary)

            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { i, date in
                    let isToday = cal.isDateInToday(date)
                    let day = cal.component(.day, from: date)
                    VStack(spacing: 4) {
                        Text(letters[i])
                            .font(.caption2)
                            .foregroundColor(isToday ? .primary : .tabiGray)
                        ZStack {
                            Circle()
                                .fill(isToday ? Color.primary : Color.clear)
                                .frame(width: 28, height: 28)
                            Text("\(day)")
                                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                                .foregroundColor(isToday ? Color(UIColor.systemBackground) : .tabiGray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f.string(from: Date())
    }
}

// MARK: - TABI Medication Row

struct TABIMedicationRow: View {
    let medication: Medication
    let onTake: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Colored icon square
            RoundedRectangle(cornerRadius: 10)
                .fill(medication.pillColor)
                .frame(width: 52, height: 52)
                .overlay(Text(medication.emoji).font(.title3))

            // Text stack
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.timeWithCountdown)
                    .font(.caption).foregroundColor(.tabiGray)
                Text(medication.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary).lineLimit(2)
                Text(medication.type)
                    .font(.caption).foregroundColor(.tabiGray)
                if !medication.dosage.isEmpty {
                    Text(medication.dosage)
                        .font(.caption).foregroundColor(.tabiGray)
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2).foregroundColor(.tabiGray)
                    Text(medication.scheduleLabel).font(.caption).foregroundColor(.tabiGray)
                }
            }

            Spacer()

            // Take / Skip
            VStack(spacing: 6) {
                Button(action: onTake) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.caption2.bold())
                        Text("Taken").font(.caption.bold())
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.tabiGreen.opacity(0.12))
                    .foregroundColor(.tabiGreen).cornerRadius(8)
                }
                Button(action: onSkip) {
                    Text("Skip").font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(.tabiGray).cornerRadius(8)
                }
            }

            Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.tabiCard)
    }
}
