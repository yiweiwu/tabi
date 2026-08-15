import SwiftUI

// MARK: - Calendar View

enum CalendarViewMode {
    case week, month
}

struct CalendarView: View {
    // Defaults to the mock provider - pass a real-backend-conforming type in
    // once one exists, no other change needed here or in the grid views.
    var provider: MedicationTimelineProviding = MockMedicationTimelineProvider()
    @State private var currentDate = Date()
    @State private var viewMode: CalendarViewMode = .week

    private var medications: [ScheduledMedication] { provider.fetchMedications() }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                modeToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Period navigation controls
                HStack {
                    Button(action: previousPeriod) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                    }

                    Spacer()

                    Text(dateRangeText)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: nextPeriod) {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Timeline content
                ScrollView {
                    VStack(spacing: 16) {
                        switch viewMode {
                        case .week:
                            WeekTimelineView(medications: medications, currentDate: currentDate)
                        case .month:
                            MonthTimelineView(medications: medications, currentDate: currentDate)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Medication Timeline")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            modeButton(.week, title: "Week")
            modeButton(.month, title: "Month")
        }
        .padding(4)
        .background(Color.tabiBG)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.91))
        )
    }

    private func modeButton(_ mode: CalendarViewMode, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(viewMode == mode ? .primary : .tabiGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewMode == mode ? Color.tabiCard : Color.clear)
                        .shadow(color: viewMode == mode ? Color.black.opacity(0.08) : .clear, radius: 4, x: 0, y: 1)
                )
        }
    }

    private func previousPeriod() {
        switch viewMode {
        case .week:
            currentDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        case .month:
            currentDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        }
    }

    private func nextPeriod() {
        switch viewMode {
        case .week:
            currentDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case .month:
            currentDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
    }

    private var dateRangeText: String {
        switch viewMode {
        case .week:
            let cal = Calendar.current
            let weekday = cal.component(.weekday, from: currentDate)
            let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: currentDate)) ?? currentDate
            let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? currentDate

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentDate)
        }
    }
}

// MARK: - Week Timeline View

struct WeekTimelineView: View {
    let medications: [ScheduledMedication]
    let currentDate: Date

    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: currentDate)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: currentDate)) ?? currentDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        VStack(spacing: 16) {
            WeekCalendarDotGrid(medications: medications, weekDays: weekDays)
                .padding(.horizontal, 16)

            RefillReminderCard(medications: medications)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Month Timeline View

struct MonthTimelineView: View {
    let medications: [ScheduledMedication]
    let currentDate: Date

    var body: some View {
        VStack(spacing: 16) {
            MonthCalendarGrid(medications: medications, monthDate: currentDate)
                .padding(.horizontal, 16)

            RefillReminderCard(medications: medications)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Week Calendar Dot Grid

struct WeekCalendarDotGrid: View {
    let medications: [ScheduledMedication]
    let weekDays: [Date]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(medications.count) active medications")
                    .font(.caption)
                    .foregroundColor(.tabiGray)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 0) {
                // Day headers (top row)
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 100)

                    ForEach(weekDays, id: \.self) { day in
                        dayHeaderView(for: day)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 16)

                Divider()
                    .padding(.bottom, 12)

                if medications.isEmpty {
                    Text("No medications added yet")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(medications.enumerated()), id: \.element.id) { index, medication in
                        medicationRow(for: medication)
                        if index < medications.count - 1 {
                            Divider()
                                .padding(.leading, 100)
                                .padding(.vertical, 4)
                        }
                    }

                    Divider()
                        .padding(.top, 8)

                    legend
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.tabiCard)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    private func dayHeaderView(for day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)

        return VStack(spacing: 6) {
            Text(dayLetter(day))
                .font(.caption.weight(.medium))
                .foregroundColor(.tabiGray)
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isToday ? Color.black : Color.clear))
        }
        .frame(maxWidth: .infinity)
    }

    private func medicationRow(for medication: ScheduledMedication) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(medication.subtitleText)
                    .font(.caption)
                    .foregroundColor(.tabiGray)
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    dayDot(for: medication, on: day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func dayDot(for medication: ScheduledMedication, on day: Date) -> some View {
        let status = medication.doseStatus(on: day, today: Date())
        let isToday = Calendar.current.isDateInToday(day)

        return ZStack {
            if isToday {
                Circle()
                    .fill(Color.tabiGray.opacity(0.15))
                    .frame(width: 28, height: 28)
            }
            if let status {
                Circle()
                    .fill(status.color)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(height: 28)
    }

    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private var legend: some View {
        HStack(spacing: 20) {
            Spacer(minLength: 0)
            legendItem(color: .tabiGreen, label: "Taken")
            legendItem(color: .tabiRed, label: "Missed")
            legendItem(color: .black, label: "Scheduled")
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.tabiGray)
        }
    }
}

// MARK: - Month Calendar Grid

struct MonthCalendarGrid: View {
    let medications: [ScheduledMedication]
    let monthDate: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    // Leading/trailing days from adjacent months pad the grid out to full
    // weeks, mirroring a standard month calendar.
    private var gridDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        let firstOfMonth = monthInterval.start
        let leadingCount = calendar.component(.weekday, from: firstOfMonth) - 1
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingCount, to: firstOfMonth) else { return [] }

        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let totalCells = Int(ceil(Double(leadingCount + daysInMonth) / 7.0)) * 7
        return (0..<totalCells).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(medications.count) active medications")
                    .font(.caption)
                    .foregroundColor(.tabiGray)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                        Text(letter)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.tabiGray)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(gridDays, id: \.self) { day in
                        dayCell(for: day)
                    }
                }
            }
            .padding(.horizontal, 20)

            legend
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.tabiCard)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    private func dayCell(for day: Date) -> some View {
        let isCurrentMonth = calendar.isDate(day, equalTo: monthDate, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)

        return VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: day))")
                .font(.subheadline.weight(isToday ? .semibold : .regular))
                .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .primary.opacity(0.25)))
                .frame(width: 28, height: 28)
                .background(Circle().fill(isToday ? Color.black : Color.clear))

            if isCurrentMonth, let status = monthDayStatus(for: day) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            } else if !isCurrentMonth {
                // Faint decorative marker for adjacent-month padding days -
                // these aren't part of "active medications" for this month.
                Circle()
                    .fill(Color.tabiRed.opacity(0.12))
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func monthDayStatus(for day: Date) -> DoseDotStatus? {
        let statuses = medications.compactMap { $0.doseStatus(on: day, today: Date()) }
        return aggregateDoseStatus(statuses)
    }

    private var legend: some View {
        HStack(spacing: 20) {
            Spacer(minLength: 0)
            legendItem(color: .tabiGreen, label: "All taken")
            legendItem(color: .tabiRed, label: "Missed a dose")
            legendItem(color: .black, label: "Scheduled")
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.tabiGray)
        }
    }
}

// MARK: - Refill Reminder Card

struct RefillReminderCard: View {
    let medications: [ScheduledMedication]
    @State private var showingDetail = false

    private var lowSupplyMedications: [ScheduledMedication] {
        medications.filter(\.isLowSupply).sorted { $0.daysOfSupplyRemaining < $1.daysOfSupplyRemaining }
    }

    var body: some View {
        if !lowSupplyMedications.isEmpty {
            Button {
                showingDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Refill needed soon")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundColor(.tabiGray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(lowSupplyMedications.enumerated()), id: \.element.id) { index, medication in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(medication.pillColor)
                                    .frame(width: 3, height: 36)

                                Text(medication.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("\(medication.daysOfSupplyRemaining) \(medication.daysOfSupplyRemaining == 1 ? "day" : "days") left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.tabiRed)
                            }
                            .padding(.vertical, 10)

                            if index < lowSupplyMedications.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.tabiCard)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
            .sheet(isPresented: $showingDetail) {
                RefillDetailSheet(medications: lowSupplyMedications)
            }
        }
    }
}

// MARK: - Refill Detail Sheet

struct RefillDetailSheet: View {
    let medications: [ScheduledMedication]
    @Environment(\.dismiss) private var dismiss

    // Grouped by pharmacy rather than one shared contact block - different
    // medications are often filled at different pharmacies, and grouping is
    // what actually answers "where do I need to call/go" when there's more
    // than one. Groups are ordered by their most urgent medication first.
    private var groupedByPharmacy: [(pharmacy: MedicationPharmacy, medications: [ScheduledMedication])] {
        Dictionary(grouping: medications, by: \.pharmacy)
            .map { pharmacy, meds in
                (pharmacy: pharmacy, medications: meds.sorted { $0.daysOfSupplyRemaining < $1.daysOfSupplyRemaining })
            }
            .sorted { ($0.medications.first?.daysOfSupplyRemaining ?? .max) < ($1.medications.first?.daysOfSupplyRemaining ?? .max) }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedByPharmacy, id: \.pharmacy.id) { group in
                    Section {
                        ForEach(group.medications) { medication in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(medication.pillColor)
                                    .frame(width: 3, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(medication.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(medication.subtitleText)
                                        .font(.caption)
                                        .foregroundColor(.tabiGray)
                                }

                                Spacer()

                                Text("\(medication.daysOfSupplyRemaining) \(medication.daysOfSupplyRemaining == 1 ? "day" : "days") left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.tabiRed)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(group.pharmacy.name)
                    } footer: {
                        // Placeholder until real pharmacy integration exists
                        // - see PharmaciesView for the user's saved pharmacies.
                        Text("\(group.pharmacy.address) · \(group.pharmacy.phone)")
                    }
                }
            }
            .navigationTitle("Refill Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
