import SwiftUI

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var medicationManager: MedicationManager
    @StateObject private var viewModel = CalendarViewModel()
    private let cal = Calendar.current
    private let weekdayLabels = ["Su","Mo","Tu","We","Th","Fr","Sa"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Segmented control: Week / Month / Year
                Picker("", selection: $viewModel.viewMode) {
                    ForEach(CalendarViewModel.ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)

                // Month + year pickers row
                HStack(spacing: 8) {
                    Button { viewModel.advanceMonth(by: -1) } label: {
                        Image(systemName: "chevron.left").foregroundColor(.primary)
                    }

                    Menu {
                        ForEach(1...12, id: \.self) { m in Button(monthName(m)) { setMonth(m) } }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentMonthName()).font(.subheadline.bold())
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray6)).cornerRadius(8)
                    }.foregroundColor(.primary)

                    Menu {
                        ForEach(2020...2030, id: \.self) { y in Button("\(y)") { setYear(y) } }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentYear()).font(.subheadline.bold())
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray6)).cornerRadius(8)
                    }.foregroundColor(.primary)

                    Spacer()
                    Button { viewModel.advanceMonth(by: 1) } label: {
                        Image(systemName: "chevron.right").foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)

                // Calendar grid card
                VStack(spacing: 0) {
                    // Day-of-week headers
                    HStack(spacing: 0) {
                        ForEach(weekdayLabels, id: \.self) { d in
                            Text(d).font(.caption2).foregroundColor(.tabiGray).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 8)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(viewModel.daysInMonth().enumerated()), id: \.offset) { _, date in
                            if let date = date {
                                TABICalendarDayCell(
                                    date: date,
                                    entries: viewModel.entries(forDay: date),
                                    isToday: cal.isDateInToday(date),
                                    isSelected: viewModel.selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false,
                                    onTap: { viewModel.selectDay(date, medications: medicationManager.medications) }
                                )
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 8).padding(.bottom, 12)
                }
                .background(Color.tabiCard)
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .shadow(color: .black.opacity(0.04), radius: 4)

                // Filter list
                ScrollView {
                    VStack(spacing: 0) {
                        Text("List (baseline)")
                            .font(.caption).foregroundColor(.tabiGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 4)

                        VStack(spacing: 0) {
                            ForEach(medicationManager.medications) { med in
                                CalendarFilterRow(label: med.name)
                                Divider().padding(.leading, 60)
                            }
                            CalendarFilterRow(label: "Refill")
                        }
                        .background(Color.tabiCard).cornerRadius(14)
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showDaySheet) {
                DayDetailSheet(date: viewModel.selectedDate ?? Date(), entries: viewModel.entriesForSelectedDay, viewModel: viewModel, medicationManager: medicationManager)
                    .presentationDetents([.medium, .large])
            }
            .onAppear { viewModel.load(medications: medicationManager.medications) }
            .onChange(of: viewModel.displayedMonth) { _, _ in viewModel.load(medications: medicationManager.medications) }
        }
    }

    private func currentMonthName() -> String { let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: viewModel.displayedMonth) }
    private func currentYear() -> String { let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: viewModel.displayedMonth) }
    private func monthName(_ m: Int) -> String { DateFormatter().monthSymbols[m - 1] }
    private func setMonth(_ m: Int) {
        var c = Calendar.current.dateComponents([.year, .month], from: viewModel.displayedMonth); c.month = m
        if let d = Calendar.current.date(from: c) { viewModel.displayedMonth = d }
    }
    private func setYear(_ y: Int) {
        var c = Calendar.current.dateComponents([.year, .month], from: viewModel.displayedMonth); c.year = y
        if let d = Calendar.current.date(from: c) { viewModel.displayedMonth = d }
    }
}

// MARK: - TABI Calendar Day Cell

struct TABICalendarDayCell: View {
    let date: Date
    let entries: [DoseEntry]
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary)
                            .frame(width: 30, height: 30)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.tabiOrange, lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                    }
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                        .foregroundColor(
                            isSelected ? Color(UIColor.systemBackground)
                            : isToday ? .tabiOrange
                            : .primary
                        )
                }
                // Dose dots
                if !entries.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(dotColors.prefix(3).enumerated()), id: \.offset) { _, c in
                            Circle().fill(c).frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Color.clear.frame(height: 4)
                }
            }
            .frame(height: 44).frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dotColors: [Color] {
        entries.map {
            switch $0.status {
            case .taken: return Color.tabiGreen
            case .skipped: return Color.tabiAmber
            case .missed: return Color.tabiRed
            case .upcoming: return Color.tabiBlue
            }
        }
    }
}

// MARK: - Calendar Filter Row

struct CalendarFilterRow: View {
    let label: String
    @State private var isOn = true
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.tabiLavLight).frame(width: 32, height: 32)
                .overlay(Image(systemName: "person.circle").font(.caption).foregroundColor(.tabiLavender))
            Text(label).font(.subheadline).foregroundColor(.primary).lineLimit(1)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.tabiOrange)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.tabiCard)
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let date: Date
    let entries: [DoseEntry]
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var medicationManager: MedicationManager

    var body: some View {
        NavigationView {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundColor(.tabiGreen.opacity(0.4))
                        Text("No doses scheduled").foregroundColor(.tabiGray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.tabiBG)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(entries) { entry in
                                DoseDetailRow(entry: entry, viewModel: viewModel, medicationManager: medicationManager)
                                if entry.id != entries.last?.id { Divider().padding(.leading, 72) }
                            }
                        }
                        .background(Color.tabiCard).cornerRadius(14).padding()
                    }
                    .background(Color.tabiBG)
                }
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var dayTitle: String { let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: date) }
}

// MARK: - Dose Detail Row

struct DoseDetailRow: View {
    let entry: DoseEntry
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var medicationManager: MedicationManager

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(entry.pillColor)
                .frame(width: 44, height: 44)
                .overlay(Text(entry.medicationEmoji).font(.body))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.medicationName).font(.subheadline.bold()).lineLimit(2)
                if !entry.dosage.isEmpty { Text(entry.dosage).font(.caption).foregroundColor(.tabiGray) }
                Text(timeStr(entry.scheduledDate)).font(.caption).foregroundColor(.tabiGray)
            }

            Spacer()

            if entry.isActionable {
                HStack(spacing: 6) {
                    Button("Taken") { viewModel.recordTaken(entry: entry, medicationManager: medicationManager) }
                        .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.tabiGreen.opacity(0.12)).foregroundColor(.tabiGreen).cornerRadius(8)
                    Button("Skip") { viewModel.recordSkipped(entry: entry, medications: medicationManager.medications) }
                        .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5)).foregroundColor(.tabiGray).cornerRadius(8)
                }
            } else {
                Label(entry.status.label, systemImage: entry.status.icon)
                    .font(.caption.bold()).foregroundColor(entry.status.color)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(entry.status.color.opacity(0.12)).cornerRadius(8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.tabiCard)
    }

    private func timeStr(_ d: Date) -> String { let f = DateFormatter(); f.timeStyle = .short; return f.string(from: d) }
}
