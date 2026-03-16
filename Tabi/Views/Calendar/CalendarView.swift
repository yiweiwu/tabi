import SwiftUI

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var medicationManager: MedicationManager
    @StateObject private var viewModel = CalendarViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented control: Week / Month / Year
                Picker("", selection: $viewModel.viewMode) {
                    ForEach(CalendarViewModel.ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)

                // Content based on view mode
                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.viewMode == .week {
                            WeekTimelineView(medications: medicationManager.medications, currentDate: viewModel.displayedMonth)
                        } else if viewModel.viewMode == .month {
                            MonthTimelineView(medications: medicationManager.medications, currentDate: viewModel.displayedMonth)
                        } else {
                            YearTimelineView(medications: medicationManager.medications, currentDate: viewModel.displayedMonth)
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
            // Week header
            HStack {
                Text(weekRangeText)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Week calendar grid with dots
            WeekCalendarDotGrid(medications: medications, weekDays: weekDays)
                .padding(.horizontal, 16)
            
            // Legend
            MedicationLegend(medications: medications)
                .padding(.horizontal, 16)
        }
    }
    
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
}

// MARK: - Medication Week Card

struct MedicationWeekCard: View {
    let medication: Medication
    let weekDays: [Date]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(medication.pillColor)
                    .frame(width: 44, height: 44)
                    .overlay(Text(medication.emoji).font(.title3))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(medication.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(medication.type)
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.tabiCard)
        .cornerRadius(14)
    }
}

// MARK: - Month Timeline View

struct MonthTimelineView: View {
    let medications: [Medication]
    let currentDate: Date
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }
    
    private func daysInMonth() -> [Date] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: currentDate)
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: currentDate) else { return [] }
        return range.compactMap { day in
            cal.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(monthName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Month calendar grid with dots
            MonthCalendarDotGrid(medications: medications, monthDays: daysInMonth())
                .padding(.horizontal, 16)
            
            // Legend
            MedicationLegend(medications: medications)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Medication Month Card

struct MedicationMonthCard: View {
    let medication: Medication
    let currentDate: Date
    let totalDays: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(medication.pillColor)
                    .frame(width: 44, height: 44)
                    .overlay(Text(medication.emoji).font(.title3))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(medication.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(medication.type)
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.tabiCard)
        .cornerRadius(14)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.tabiGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Year Timeline View

struct YearTimelineView: View {
    let medications: [Medication]
    let currentDate: Date
    
    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: currentDate)
    }
    
    private var months: [String] {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(yearText)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ForEach(medications) { medication in
                MedicationYearCard(medication: medication, currentDate: currentDate, months: months)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Medication Year Card

struct MedicationYearCard: View {
    let medication: Medication
    let currentDate: Date
    let months: [String]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(medication.pillColor)
                    .frame(width: 44, height: 44)
                    .overlay(Text(medication.emoji).font(.title3))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(medication.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(medication.type)
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.tabiCard)
        .cornerRadius(14)
    }
}

// MARK: - Week Calendar Dot Grid

struct WeekCalendarDotGrid: View {
    let medications: [Medication]
    let weekDays: [Date]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Week Overview")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Day headers
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { day in
                    dayHeaderView(for: day)
                }
            }
            
            // Week grid with medication dots
            ForEach(weekDays, id: \.self) { day in
                dayRowView(for: day)
            }
        }
        .padding(16)
        .background(Color.tabiCard)
        .cornerRadius(14)
    }
    
    private func dayHeaderView(for day: Date) -> some View {
        VStack(spacing: 4) {
            Text(dayLetter(day))
                .font(.caption2.bold())
                .foregroundColor(.tabiGray)
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.caption2)
                .foregroundColor(.tabiGray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func dayRowView(for day: Date) -> some View {
        HStack(spacing: 8) {
            Text(dayLetter(day))
                .font(.caption.bold())
                .foregroundColor(.primary)
                .frame(width: 30, alignment: .leading)
            
            HStack(spacing: 6) {
                ForEach(medications) { medication in
                    medicationDot(medication, on: day)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func medicationDot(_ medication: Medication, on day: Date) -> some View {
        Circle()
            .fill(isMedicationActive(medication, on: day) ? medication.pillColor : Color.tabiLavLight)
            .frame(width: 20, height: 20)
    }
    
    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private func isMedicationActive(_ medication: Medication, on date: Date) -> Bool {
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: medication.dosageTime)
        let checkDate = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        
        return checkDate >= startDate && checkDate <= today
    }
}

// MARK: - Month Calendar Dot Grid

struct MonthCalendarDotGrid: View {
    let medications: [Medication]
    let monthDays: [Date]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Month Overview")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Calendar grid
            VStack(spacing: 8) {
                // Weekday headers
                weekdayHeaders()
                
                // Days grid
                let weeks = groupByWeeks(monthDays)
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week)
                }
            }
        }
        .padding(16)
        .background(Color.tabiCard)
        .cornerRadius(14)
    }
    
    private func weekdayHeaders() -> some View {
        HStack(spacing: 4) {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { letter in
                Text(letter)
                    .font(.caption2.bold())
                    .foregroundColor(.tabiGray)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func weekRow(_ week: [Date?]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                if index < week.count, let day = week[index] {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
        }
    }
    
    private func dayCell(for day: Date) -> some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.caption.bold())
                .foregroundColor(.primary)
            
            // Medication dots
            HStack(spacing: 2) {
                ForEach(medications) { medication in
                    Circle()
                        .fill(isMedicationActive(medication, on: day) ? medication.pillColor : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hasAnyMedication(on: day) ? Color.tabiLavLight.opacity(0.5) : Color.clear)
        )
    }
    
    private func groupByWeeks(_ days: [Date]) -> [[Date?]] {
        guard let firstDay = days.first else { return [] }
        let cal = Calendar.current
        let firstWeekday = cal.component(.weekday, from: firstDay)
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in days {
            currentWeek.append(day)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    private func isMedicationActive(_ medication: Medication, on date: Date) -> Bool {
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: medication.dosageTime)
        let checkDate = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        
        return checkDate >= startDate && checkDate <= today
    }
    
    private func hasAnyMedication(on date: Date) -> Bool {
        medications.contains { isMedicationActive($0, on: date) }
    }
}

// MARK: - Medication Legend

struct MedicationLegend: View {
    let medications: [Medication]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Medications")
                    .font(.caption.bold())
                    .foregroundColor(.tabiGray)
                Spacer()
            }
            
            ForEach(medications) { medication in
                legendItem(for: medication)
            }
        }
        .padding(12)
        .background(Color.tabiCard)
        .cornerRadius(10)
    }
    
    private func legendItem(for medication: Medication) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(medication.pillColor)
                .frame(width: 12, height: 12)
            
            Text(medication.name)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

