import SwiftUI

// MARK: - Today View

struct TodayView: View {
    @ObservedObject var medicationManager: MedicationManager
    @State private var showingCamera = false
    @State private var isEditing = false
    @State private var selectedDate = Date()

    private var isSelectedToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    // Groups DoseEntry records by medication for non-today dates.
    // Reads from CalendarPersistenceManager's in-memory cache (populated by
    // Firestore listeners started at app launch), so no async load needed.
    private var historyEntries: [(Medication, [DoseEntry])] {
        guard !isSelectedToday else { return [] }
        let entries = CalendarPersistenceManager.shared.loadEntries(
            forDay: selectedDate,
            medications: medicationManager.medications
        )
        let grouped = Dictionary(grouping: entries, by: \.medicationId)
        return medicationManager.medications.compactMap { med in
            guard let medEntries = grouped[med.id] else { return nil }
            return (med, medEntries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Date + week strip ──────────────────────────────────
                WeekStripHeader(selectedDate: $selectedDate)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // ── Your Medications ──────────────────────────────────
                VStack(spacing: 0) {
                    HStack {
                        Text("Your Medications")
                            .font(.headline).fontWeight(.bold)
                        Spacer()
                        if isSelectedToday {
                            Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                                .font(.subheadline).foregroundColor(.tabiOrange)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        if isSelectedToday {
                            // Live rows with Taken button
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
                                        onTake: { medicationManager.recordMedicationTaken(med, points: med.points) }
                                    )
                                }
                                .animation(.easeInOut(duration: 0.2), value: isEditing)
                                if med.id != medicationManager.medications.last?.id {
                                    Divider().padding(.leading, isEditing ? 60 : 80)
                                }
                            }
                        } else {
                            // Historical dose entry rows
                            if historyEntries.isEmpty {
                                Text("No medications scheduled for this day")
                                    .font(.subheadline)
                                    .foregroundColor(.tabiGray)
                                    .padding(.vertical, 24)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(Array(historyEntries.enumerated()), id: \.1.0.id) { index, pair in
                                    MedicationHistoryRow(medication: pair.0, entries: pair.1)
                                    if index < historyEntries.count - 1 {
                                        Divider().padding(.leading, 80)
                                    }
                                }
                            }
                        }

                        Divider().padding(.leading, 80)
                        if isSelectedToday {
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
    @Binding var selectedDate: Date
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
            Text(headerTitle)
                .font(.title2).fontWeight(.bold).foregroundColor(.primary)

            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { i, date in
                    let isToday = cal.isDateInToday(date)
                    let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                    let day = cal.component(.day, from: date)
                    Button(action: { selectedDate = date }) {
                        VStack(spacing: 4) {
                            Text(letters[i])
                                .font(.caption2)
                                .foregroundColor(isSelected ? .tabiOrange : (isToday ? .primary : .tabiGray))
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.tabiOrange : (isToday ? Color.primary : Color.clear))
                                    .frame(width: 28, height: 28)
                                Text("\(day)")
                                    .font(.system(size: 13, weight: (isSelected || isToday) ? .bold : .regular))
                                    .foregroundColor((isSelected || isToday) ? .white : .tabiGray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var headerTitle: String {
        let f = DateFormatter()
        if cal.isDateInToday(selectedDate) {
            f.dateFormat = "EEEE, MMMM d"
            return f.string(from: selectedDate)
        }
        if cal.isDateInYesterday(selectedDate) {
            f.dateFormat = "MMMM d"
            return "Yesterday, \(f.string(from: selectedDate))"
        }
        if cal.isDateInTomorrow(selectedDate) {
            f.dateFormat = "MMMM d"
            return "Tomorrow, \(f.string(from: selectedDate))"
        }
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: selectedDate)
    }
}

// MARK: - TABI Medication Row

struct TABIMedicationRow: View {
    let medication: Medication
    let onTake: () -> Void

    private enum TakenButtonState { case notStarted, inProgress, overdue, completed }

    private var takenButtonState: TakenButtonState {
        let taken = medication.takenTodayCount
        let total = medication.frequencyPerDay
        if taken >= total { return .completed }
        let passed = MedicationScheduleParser.scheduledTimes(for: total).filter { $0 < Date() }.count
        if passed > taken { return .overdue }
        if taken > 0 { return .inProgress }
        return .notStarted
    }

    private func buttonBackground(for state: TakenButtonState) -> Color {
        switch state {
        case .completed:  return Color.tabiGreen.opacity(0.15)
        case .inProgress: return Color.tabiAmber.opacity(0.15)
        case .overdue:    return Color.tabiRed.opacity(0.15)
        case .notStarted: return Color(UIColor.systemGray5)
        }
    }

    private func buttonForeground(for state: TakenButtonState) -> Color {
        switch state {
        case .completed:  return .tabiGreen
        case .inProgress: return .tabiAmber
        case .overdue:    return .tabiRed
        case .notStarted: return .tabiGray
        }
    }

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
                Text(medication.genericName)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary).lineLimit(2)
                Text(medication.name)
                    .font(.caption).foregroundColor(.tabiGray)
                let taken = medication.takenTodayCount
                let allDone = taken >= medication.frequencyPerDay
                Text(allDone ? "All done today" : "\(taken) of \(medication.frequencyPerDay) doses today")
                    .font(.caption)
                    .foregroundColor(allDone ? .tabiGreen : .tabiGray)
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2).foregroundColor(.tabiGray)
                    Text(medication.scheduleLabel).font(.caption).foregroundColor(.tabiGray)
                }
            }

            Spacer()

            let state = takenButtonState
            Button(action: onTake) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark").font(.caption2.bold())
                    Text("Taken").font(.caption.bold())
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(buttonBackground(for: state))
                .foregroundColor(buttonForeground(for: state))
                .cornerRadius(8)
            }
            .disabled(state == .completed)

            Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.tabiCard)
    }
}

// MARK: - Medication History Row (non-today dates)

struct MedicationHistoryRow: View {
    let medication: Medication
    let entries: [DoseEntry]

    private var takenCount: Int {
        entries.filter { if case .taken = $0.status { return true }; return false }.count
    }

    private var summary: String {
        let total = entries.count
        if takenCount == total { return "All \(total) dose\(total == 1 ? "" : "s") taken" }
        if takenCount == 0 { return "No doses taken" }
        return "\(takenCount) of \(total) doses taken"
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(medication.pillColor)
                .frame(width: 52, height: 52)
                .overlay(Text(medication.emoji).font(.title3))

            VStack(alignment: .leading, spacing: 2) {
                Text(medication.genericName)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary).lineLimit(2)
                Text(medication.name)
                    .font(.caption).foregroundColor(.tabiGray)
                Text(summary)
                    .font(.caption)
                    .foregroundColor(takenCount == entries.count ? .tabiGreen : .tabiGray)
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2).foregroundColor(.tabiGray)
                    Text(medication.scheduleLabel).font(.caption).foregroundColor(.tabiGray)
                }
            }

            Spacer()

            // One status icon per scheduled dose
            HStack(spacing: 6) {
                ForEach(entries) { entry in
                    Image(systemName: entry.status.icon)
                        .font(.title3)
                        .foregroundColor(entry.status.color)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.tabiCard)
    }
}
