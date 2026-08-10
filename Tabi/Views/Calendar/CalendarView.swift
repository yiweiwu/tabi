import SwiftUI

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var medicationManager: MedicationManager
    @State private var currentDate = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Week navigation controls
                HStack {
                    Button(action: previousWeek) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.tabiCard)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Text(weekRangeText)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: nextWeek) {
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

                // Week view content
                ScrollView {
                    VStack(spacing: 16) {
                        WeekTimelineView(medications: medicationManager.medications, currentDate: currentDate)
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Medication Timeline")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func previousWeek() {
        currentDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
    }
    
    private func nextWeek() {
        currentDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
    }
    
    private var weekRangeText: String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: currentDate)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: currentDate)) ?? currentDate
        let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? currentDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
    }
}

// MARK: - Week Timeline View

struct WeekTimelineView: View {
    let medications: [Medication]
    let currentDate: Date
    
    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: currentDate)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: currentDate)) ?? currentDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Week calendar grid
            WeekCalendarDotGrid(medications: medications, weekDays: weekDays)
                .padding(.horizontal, 16)
            
            // Refill reminders
            RefillRemindersSection(medications: medications, weekDays: weekDays)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Week Calendar Dot Grid

struct WeekCalendarDotGrid: View {
    let medications: [Medication]
    let weekDays: [Date]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with gradient background
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Timeline")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Text("\(medications.count) active medications")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 0) {
                // Day headers (top row)
                HStack(spacing: 0) {
                    // Empty space for medication names column
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

    private func medicationRow(for medication: Medication) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(doseSubtitle(for: medication))
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

    private func dayDot(for medication: Medication, on day: Date) -> some View {
        let status = doseDotStatus(for: medication, on: day)
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

    private func doseSubtitle(for medication: Medication) -> String {
        guard medication.frequencyPerDay == 1 else { return medication.dosage }
        let hour = Calendar.current.component(.hour, from: MedicationScheduleParser.scheduledTimes(for: 1)[0])
        return "\(medication.dosage) · \(hour < 12 ? "AM" : "PM")"
    }

    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    // A day is only marked if dose entries exist for it (medication was
    // already added by that date) - mirrors the "empty/gray" rule in
    // CLAUDE.md's Calendar active-day check.
    private func doseDotStatus(for medication: Medication, on day: Date) -> DoseDotStatus? {
        let entries = CalendarPersistenceManager.shared.loadAll(forMedicationId: medication.id)
            .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: day) }
        guard !entries.isEmpty else { return nil }

        let hasMissedOrSkipped = entries.contains {
            switch $0.status {
            case .missed, .skipped: return true
            case .upcoming, .taken: return false
            }
        }
        if hasMissedOrSkipped { return .missed }

        let allTaken = entries.allSatisfy {
            if case .taken = $0.status { return true }
            return false
        }
        return allTaken ? .taken : .scheduled
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

private enum DoseDotStatus {
    case taken, missed, scheduled

    var color: Color {
        switch self {
        case .taken:     return .tabiGreen
        case .missed:    return .tabiRed
        case .scheduled: return .black
        }
    }
}

// MARK: - Refill Reminders Section

struct RefillRemindersSection: View {
    let medications: [Medication]
    let weekDays: [Date]
    
    // Generate mock refill dates (in real app, these would come from the medication model)
    private var refillReminders: [(medication: Medication, refillDate: Date)] {
        var reminders: [(medication: Medication, refillDate: Date)] = []
        let calendar = Calendar.current
        
        for (index, medication) in medications.enumerated() {
            // Generate a refill date within the current week (for demo purposes)
            if let refillDate = calendar.date(byAdding: .day, value: index + 2, to: weekDays.first ?? Date()) {
                if refillDate >= Date() && weekDays.contains(where: { calendar.isDate($0, inSameDayAs: refillDate) }) {
                    reminders.append((medication: medication, refillDate: refillDate))
                }
            }
        }
        
        return reminders.sorted { reminder1, reminder2 in
            reminder1.refillDate < reminder2.refillDate
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refill Reminders")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Text("Upcoming medication refills")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Refill cards
            VStack(spacing: 12) {
                if refillReminders.isEmpty {
                    EmptyRefillsView()
                        .padding(.horizontal, 20)
                } else {
                    ForEach(refillReminders, id: \.medication.id) { reminder in
                        RefillReminderCard(
                            medication: reminder.medication,
                            refillDate: reminder.refillDate
                        )
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.tabiCard)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
}

// MARK: - Refill Reminder Card
struct RefillReminderCard: View {
    let medication: Medication
    let refillDate: Date
    
    private var daysUntilRefill: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: refillDate).day ?? 0
    }
    
    private var isUrgent: Bool {
        daysUntilRefill <= 2
    }
    
    private var refillDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: refillDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Color stripe and icon
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [medication.pillColor, medication.pillColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 50)
                    .shadow(color: medication.pillColor.opacity(0.4), radius: 2, x: 0, y: 0)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                            .foregroundColor(isUrgent ? .tabiRed : .tabiGray)
                        Text(refillDateText)
                            .font(.caption)
                            .foregroundColor(isUrgent ? .tabiRed : .tabiGray)
                    }
                }
            }
            
            Spacer()
            
            // Days remaining badge
            VStack(spacing: 4) {
                Text("\(daysUntilRefill)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(isUrgent ? .tabiRed : .tabiOrange)
                Text(daysUntilRefill == 1 ? "day" : "days")
                    .font(.caption2)
                    .foregroundColor(.tabiGray)
            }
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isUrgent ? Color.tabiRed.opacity(0.1) : Color.tabiOrangeLight)
            )
            
            // Action button
            Button(action: {
                // Handle refill action
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.tabiGray)
                    .frame(width: 32, height: 32)
                    .background(Color.tabiLavLight)
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.tabiBG)
        )
    }
}

// MARK: - Empty Refills View

struct EmptyRefillsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.tabiGreen)
            
            Text("All Set!")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No refills needed this week")
                .font(.caption)
                .foregroundColor(.tabiGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}




