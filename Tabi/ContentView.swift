import SwiftUI
import AVFoundation
import UIKit
import Vision
import UserNotifications

// MARK: - App Entry Point

@main
struct TABIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - TABI Design System

extension Color {
    // Brand colors extracted from TABI presentation
    static let tabiOrange      = Color(red: 0.91, green: 0.53, blue: 0.29)  // #E8874A — primary orange
    static let tabiOrangeLight = Color(red: 0.99, green: 0.93, blue: 0.87)  // warm tint
    static let tabiLavender    = Color(red: 0.69, green: 0.65, blue: 0.84)  // #B0A7D6 — active tab / accents
    static let tabiLavLight    = Color(red: 0.94, green: 0.93, blue: 0.97)  // light lavender bg
    static let tabiBlue        = Color(red: 0.24, green: 0.60, blue: 0.90)  // action blue
    static let tabiGreen       = Color(red: 0.27, green: 0.76, blue: 0.45)  // taken / positive
    static let tabiRed         = Color(red: 0.93, green: 0.27, blue: 0.27)  // missed
    static let tabiAmber       = Color(red: 0.97, green: 0.65, blue: 0.13)  // skipped / warning
    static let tabiGray        = Color(red: 0.56, green: 0.56, blue: 0.58)  // secondary text
    static let tabiCard        = Color(UIColor.systemBackground)
    static let tabiBG          = Color(UIColor.systemGroupedBackground)
}

// Pill card icon background colors (as shown in Today wireframe)
let pillColors: [Color] = [
    Color(red: 0.22, green: 0.38, blue: 0.62),  // blue-slate
    Color(red: 0.52, green: 0.38, blue: 0.72),  // purple
    Color(red: 0.94, green: 0.75, blue: 0.18),  // golden
    Color(red: 0.20, green: 0.52, blue: 0.55),  // teal
    Color(red: 0.91, green: 0.53, blue: 0.29),  // orange
]

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var medicationManager = MedicationManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(medicationManager: medicationManager)
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(0)

            SharingView()
                .tabItem { Label("Sharing", systemImage: "person.2") }
                .tag(1)

            CalendarView(medicationManager: medicationManager)
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(2)

            ProfileView(medicationManager: medicationManager)
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(3)
        }
        .tint(.tabiOrange)
        .onAppear { NotificationScheduler.shared.requestPermission() }
    }
}

// MARK: - Data Models

struct Medication: Identifiable, Codable {
    var id = UUID()
    var name: String
    var type: String           // "Tablet", "Eye Drops", "Capsule", etc.
    var emoji: String
    var dosageTime: Date
    var dosage: String
    var scheduleLabel: String  // "Every Day", "Twice Daily", etc.
    var points: Int
    var lastTaken: Date? = nil
    var streak: Int = 0
    var colorIndex: Int = 0
    var isMuted: Bool = false

    var isOverdue: Bool {
        guard let lastTaken else { return true }
        return Date().timeIntervalSince(lastTaken) > 86400
    }

    var pillColor: Color { pillColors[colorIndex % pillColors.count] }

    var timeWithCountdown: String {
        let f = DateFormatter(); f.timeStyle = .short
        let t = f.string(from: dosageTime)
        let diff = dosageTime.timeIntervalSinceNow
        if diff > 3600 { return "\(t) (in \(Int(diff / 3600))h)" }
        return t
    }
}

struct GameStats: Codable {
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var level: Int = 1
    var achievements: [Achievement] = []
    var adherencePercent: Int = 97

    var calculatedLevel: Int { max(1, totalPoints / 150 + 1) }
}

struct Achievement: Identifiable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let icon: String
    let pointsRequired: Int
    var isEarned: Bool = false
    var earnedDate: Date? = nil
}

struct DetectedMedicationInfo {
    var medicationName: String
    var schedule: String
    var dosage: String
    var scheduleTime: Date
    var allDetectedText: [String]
}

// MARK: - Dose Calendar Models

enum DoseStatus: Codable, Equatable {
    case upcoming, taken(Date), skipped(Date), missed

    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .taken:    return "Taken"
        case .skipped:  return "Skipped"
        case .missed:   return "Missed"
        }
    }
    var color: Color {
        switch self {
        case .upcoming: return .tabiBlue
        case .taken:    return .tabiGreen
        case .skipped:  return .tabiAmber
        case .missed:   return .tabiRed
        }
    }
    var icon: String {
        switch self {
        case .upcoming: return "circle"
        case .taken:    return "checkmark.circle.fill"
        case .skipped:  return "forward.circle.fill"
        case .missed:   return "xmark.circle.fill"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, date }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .upcoming:       try c.encode("upcoming", forKey: .type)
        case .taken(let d):   try c.encode("taken",    forKey: .type); try c.encode(d, forKey: .date)
        case .skipped(let d): try c.encode("skipped",  forKey: .type); try c.encode(d, forKey: .date)
        case .missed:         try c.encode("missed",   forKey: .type)
        }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "taken":   self = .taken(try c.decode(Date.self, forKey: .date))
        case "skipped": self = .skipped(try c.decode(Date.self, forKey: .date))
        case "missed":  self = .missed
        default:        self = .upcoming
        }
    }
}

struct DoseEntry: Identifiable, Codable {
    var id = UUID()
    var medicationId: UUID
    var medicationName: String
    var medicationEmoji: String
    var dosage: String
    var scheduledDate: Date
    var status: DoseStatus
    var colorIndex: Int = 0

    var isActionable: Bool { if case .upcoming = status { return true }; return false }
    var pillColor: Color { pillColors[colorIndex % pillColors.count] }
}

struct DoseSchedule {
    let medicationId: UUID
    let medicationName: String
    let medicationEmoji: String
    let dosage: String
    let colorIndex: Int
    let scheduledTimes: [Date]
    let startDate: Date
    let endDate: Date
}

// MARK: - Medication Schedule Parser

class MedicationScheduleParser {
    static func parse(info: DetectedMedicationInfo, medication: Medication) -> DoseSchedule {
        let schedule = info.schedule.lowercased()
        let count = detectFrequency(from: schedule)
        let times = generateTimes(count: count, hint: schedule, baseTime: info.scheduleTime)
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return DoseSchedule(
            medicationId: medication.id, medicationName: medication.name,
            medicationEmoji: medication.emoji, dosage: info.dosage,
            colorIndex: medication.colorIndex, scheduledTimes: times,
            startDate: Date(), endDate: endDate
        )
    }
    private static func detectFrequency(from text: String) -> Int {
        if text.contains("four") || text.contains("qid") || text.contains("every 6") { return 4 }
        if text.contains("three") || text.contains("tid") || text.contains("every 8") { return 3 }
        if text.contains("twice") || text.contains("bid") || text.contains("every 12") { return 2 }
        return 1
    }
    private static func generateTimes(count: Int, hint: String, baseTime: Date) -> [Date] {
        func t(_ h: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date() }
        switch count {
        case 2: return [t(8), t(20)]
        case 3: return [t(8), t(14), t(20)]
        case 4: return [t(8), t(12), t(16), t(20)]
        default:
            if hint.contains("evening") || hint.contains("night") { return [t(20)] }
            return [t(9)]
        }
    }
}

// MARK: - Calendar Persistence Manager

class CalendarPersistenceManager {
    static let shared = CalendarPersistenceManager()
    private let prefix = "tabi.doses."
    private init() {}

    func save(schedule: DoseSchedule) {
        var entries = loadAll(forMedicationId: schedule.medicationId)
        entries.removeAll { if case .upcoming = $0.status { return true }; return false }
        let cal = Calendar.current
        var current = cal.startOfDay(for: schedule.startDate)
        let end = cal.startOfDay(for: schedule.endDate)
        while current <= end {
            for t in schedule.scheduledTimes {
                let c = cal.dateComponents([.hour, .minute], from: t)
                if let d = cal.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: current) {
                    entries.append(DoseEntry(medicationId: schedule.medicationId, medicationName: schedule.medicationName, medicationEmoji: schedule.medicationEmoji, dosage: schedule.dosage, scheduledDate: d, status: .upcoming, colorIndex: schedule.colorIndex))
                }
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        persist(entries, id: schedule.medicationId)
    }

    func loadAll(forMedicationId id: UUID) -> [DoseEntry] {
        guard let data = UserDefaults.standard.data(forKey: prefix + id.uuidString),
              let entries = try? JSONDecoder().decode([DoseEntry].self, from: data) else { return [] }
        return entries
    }

    func loadEntries(forMonth date: Date, medications: [Medication]) -> [DoseEntry] {
        let cal = Calendar.current
        return medications.flatMap { med in loadAll(forMedicationId: med.id).filter { cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .month) } }
    }

    func loadEntries(forDay date: Date, medications: [Medication]) -> [DoseEntry] {
        let cal = Calendar.current
        return medications.flatMap { med in loadAll(forMedicationId: med.id).filter { cal.isDate($0.scheduledDate, inSameDayAs: date) } }.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    func updateStatus(entryId: UUID, medicationId: UUID, status: DoseStatus) {
        var entries = loadAll(forMedicationId: medicationId)
        if let i = entries.firstIndex(where: { $0.id == entryId }) { entries[i].status = status; persist(entries, id: medicationId) }
    }

    func markMissedIfOverdue(medications: [Medication]) {
        let now = Date()
        for med in medications {
            var entries = loadAll(forMedicationId: med.id); var changed = false
            for i in entries.indices { if case .upcoming = entries[i].status, entries[i].scheduledDate < now { entries[i].status = .missed; changed = true } }
            if changed { persist(entries, id: med.id) }
        }
    }

    private func persist(_ entries: [DoseEntry], id: UUID) {
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: prefix + id.uuidString) }
    }
}

// MARK: - Notification Scheduler

class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}
    func requestPermission() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in } }
    func schedule(for s: DoseSchedule) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.filter { $0.identifier.hasPrefix("tabi.\(s.medicationId)") }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        let cal = Calendar.current; var current = cal.startOfDay(for: s.startDate); let end = cal.startOfDay(for: s.endDate); var count = 0
        while current <= end && count < 60 {
            for t in s.scheduledTimes {
                guard count < 60 else { break }
                let comps = cal.dateComponents([.hour, .minute], from: t)
                guard let date = cal.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: current), date > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Time for \(s.medicationEmoji) \(s.medicationName)"
                content.body = "\(s.dosage.isEmpty ? "Your dose" : s.dosage) — tap to log."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year,.month,.day,.hour,.minute], from: date), repeats: false)
                center.add(UNNotificationRequest(identifier: "tabi.\(s.medicationId).\(date.timeIntervalSince1970)", content: content, trigger: trigger), withCompletionHandler: nil)
                count += 1
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
    }
}

// MARK: - Calendar View Model

class CalendarViewModel: ObservableObject {
    @Published var displayedMonth: Date = Date()
    @Published var selectedDate: Date?
    @Published var entriesForMonth: [DoseEntry] = []
    @Published var entriesForSelectedDay: [DoseEntry] = []
    @Published var showDaySheet = false
    @Published var viewMode: ViewMode = .month
    enum ViewMode: String, CaseIterable { case week = "Week", month = "Month", year = "Year" }
    private let p = CalendarPersistenceManager.shared

    func load(medications: [Medication]) {
        p.markMissedIfOverdue(medications: medications)
        entriesForMonth = p.loadEntries(forMonth: displayedMonth, medications: medications)
    }
    func selectDay(_ date: Date, medications: [Medication]) {
        selectedDate = date
        entriesForSelectedDay = p.loadEntries(forDay: date, medications: medications)
        showDaySheet = true
    }
    func entries(forDay date: Date) -> [DoseEntry] {
        entriesForMonth.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }
    func advanceMonth(by v: Int) { displayedMonth = Calendar.current.date(byAdding: .month, value: v, to: displayedMonth) ?? displayedMonth }
    func daysInMonth() -> [Date?] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let first = cal.date(from: comps), let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let nils = Array(repeating: Date?.none, count: weekday - 1)
        let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) as Date? }
        return nils + days
    }
    func recordTaken(entry: DoseEntry, medicationManager: MedicationManager) {
        p.updateStatus(entryId: entry.id, medicationId: entry.medicationId, status: .taken(Date()))
        if let med = medicationManager.medications.first(where: { $0.id == entry.medicationId }) { medicationManager.recordMedicationTaken(med, points: med.points) }
        refreshDay(medications: medicationManager.medications); load(medications: medicationManager.medications)
    }
    func recordSkipped(entry: DoseEntry, medications: [Medication]) {
        p.updateStatus(entryId: entry.id, medicationId: entry.medicationId, status: .skipped(Date()))
        refreshDay(medications: medications); load(medications: medications)
    }
    private func refreshDay(medications: [Medication]) {
        guard let day = selectedDate else { return }
        entriesForSelectedDay = p.loadEntries(forDay: day, medications: medications)
    }
}

// MARK: - Medication Manager

class MedicationManager: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var gameStats = GameStats()

    init() { loadSampleData() }

    func loadSampleData() {
        medications = [
            Medication(name: "Cequa", type: "Eye Drops", emoji: "💧", dosageTime: createTime(hour: 20), dosage: "1 drop", scheduleLabel: "Every Day", points: 10, colorIndex: 0),
            Medication(name: "Cyanocobalamin (Vitamin B12)", type: "Tablet", emoji: "💊", dosageTime: createTime(hour: 20), dosage: "1000 mcg", scheduleLabel: "Every Day", points: 10, colorIndex: 1),
            Medication(name: "Vitamin A Palmitate, Ascorbic Acid (Vitamin C)", type: "Soft Chew", emoji: "🟡", dosageTime: createTime(hour: 20), dosage: "1 chew", scheduleLabel: "Every Day", points: 10, colorIndex: 2),
            Medication(name: "Vitamin D", type: "Tablet", emoji: "💊", dosageTime: createTime(hour: 20), dosage: "1 tablet", scheduleLabel: "Every Day", points: 10, colorIndex: 3),
        ]
        gameStats = GameStats(totalPoints: 420, currentStreak: 7, level: 3,
            achievements: [
                Achievement(title: "Week Warrior", description: "7 days perfect streak", icon: "🔥", pointsRequired: 70, isEarned: true, earnedDate: Date()),
                Achievement(title: "Calendar Keeper", description: "7 consecutive days all doses taken", icon: "📅", pointsRequired: 105, isEarned: false, earnedDate: nil)
            ], adherencePercent: 97)
    }

    func createTime(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    func recordMedicationTaken(_ medication: Medication, points: Int) {
        if let i = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[i].lastTaken = Date(); medications[i].streak += 1
        }
        gameStats.totalPoints += points
        gameStats.currentStreak = medications.allSatisfy { !$0.isOverdue } ? gameStats.currentStreak + 1 : 0
        gameStats.level = gameStats.calculatedLevel
    }
}

// MARK: - Today View

struct TodayView: View {
    @ObservedObject var medicationManager: MedicationManager
    @State private var showingCamera = false

    var body: some View {
        NavigationView {
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
                            Button("Edit") {}
                                .font(.subheadline).foregroundColor(.tabiOrange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            ForEach(medicationManager.medications) { med in
                                TABIMedicationRow(
                                    medication: med,
                                    onTake: { medicationManager.recordMedicationTaken(med, points: med.points) },
                                    onSkip: {}
                                )
                                if med.id != medicationManager.medications.last?.id {
                                    Divider().padding(.leading, 80)
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
            .navigationTitle("")
            .navigationBarHidden(true)
        }
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

// MARK: - Sharing View

struct SharingView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    let sharingPeople: [(String, String, Bool)] = [("Dad", "9:23 AM", true), ("Mom", "9:36 AM", false)]
                    ForEach(sharingPeople, id: \.0) { person in
                        let name = person.0; let time = person.1; let hasAlert = person.2
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(hasAlert
                                      ? LinearGradient(colors: [Color.tabiLavender.opacity(0.7), Color.tabiBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                      : LinearGradient(colors: [Color.tabiOrange.opacity(0.5), Color.tabiAmber.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 52, height: 52)
                                .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.subheadline.bold())
                                if hasAlert {
                                    Label("1 Alert", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption).foregroundColor(.tabiAmber)
                                    Label("3 Changes", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption).foregroundColor(.tabiGray)
                                } else {
                                    Label("2 Changes", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption).foregroundColor(.tabiGray)
                                }
                            }
                            Spacer()
                            Text(time).font(.caption).foregroundColor(.tabiGray)
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.tabiCard)
                        if name != "Mom" { Divider().padding(.leading, 82) }
                    }
                }
                .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16).padding(.top, 8)

                // Export PDF
                HStack(spacing: 12) {
                    Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "doc.fill").font(.caption).foregroundColor(.tabiLavender))
                    Text("Export PDF").font(.subheadline)
                    Spacer()
                    Image(systemName: "square.and.arrow.up").foregroundColor(.tabiGray)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.tabiCard).cornerRadius(14)
                .padding(.horizontal, 16).padding(.top, 12)
            }
            .background(Color.tabiBG)
            .navigationTitle("Sharing")
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var medicationManager: MedicationManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + Name
                    HStack(spacing: 16) {
                        Circle().fill(Color.tabiLavLight).frame(width: 72, height: 72)
                            .overlay(Image(systemName: "person.fill").font(.title).foregroundColor(.tabiLavender))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name").font(.title2.bold())
                            Text("Gender, Age").font(.subheadline).foregroundColor(.tabiGray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Stats
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().fill(Color.tabiLavLight).frame(width: 110, height: 110)
                            VStack(spacing: 2) {
                                Text("\(medicationManager.medications.count)").font(.system(size: 36, weight: .bold))
                                Text("Active Meds").font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                        ZStack {
                            Circle().stroke(Color.tabiLavender.opacity(0.2), lineWidth: 10).frame(width: 110, height: 110)
                            Circle().trim(from: 0, to: CGFloat(medicationManager.gameStats.adherencePercent) / 100)
                                .stroke(Color.tabiLavender, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 110, height: 110).rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(medicationManager.gameStats.adherencePercent)%").font(.system(size: 26, weight: .bold))
                                Text("Adherence").font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                    }

                    // Menu items
                    VStack(spacing: 0) {
                        let menuItems: [(String, String, String)] = [
                            ("heart.text.square", "Drug Interactions/Safety", "Safety and Allergies"),
                            ("cross.case",         "My Pharmacies",            ""),
                            ("gearshape",          "Setting",                  ""),
                        ]
                        ForEach(menuItems, id: \.1) { item in
                            let icon = item.0; let title = item.1; let subtitle = item.2
                            HStack(spacing: 12) {
                                Circle().fill(Color.tabiLavLight).frame(width: 36, height: 36)
                                    .overlay(Image(systemName: icon).font(.caption).foregroundColor(.tabiLavender))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title).font(.subheadline.bold())
                                    if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundColor(.tabiGray) }
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up").foregroundColor(.tabiGray).font(.caption)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14).background(Color.tabiCard)
                            if title != "Setting" { Divider().padding(.leading, 64) }
                        }
                    }
                    .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16)
                }
                .padding(.top, 8).padding(.bottom, 32)
            }
            .background(Color.tabiBG)
            .navigationTitle("Profile")
        }
    }
}

// MARK: - New Medication Camera View

struct NewMedicationCameraView: View {
    @ObservedObject var medicationManager: MedicationManager
    @Binding var isPresented: Bool
    @ObservedObject private var cameraManager = CameraManager.shared
    @State private var showingDetectionResult = false
    @State private var capturedImage: UIImage?
    @State private var detectedInfo: DetectedMedicationInfo?
    @State private var hasAttemptedSetup = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cameraManager.isAuthorized {
                CameraPreviewView(cameraManager: cameraManager).ignoresSafeArea()
                VStack {
                    HStack {
                        Button { isPresented = false } label: {
                            Image(systemName: "xmark").font(.title2).foregroundColor(.white)
                                .padding().background(Color.black.opacity(0.5)).clipShape(Circle())
                        }
                        Spacer()
                        VStack {
                            Text("Scan Prescription Label").font(.headline).foregroundColor(.white)
                            Text("Position label in frame").font(.caption).foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Circle().fill(Color.clear).frame(width: 44, height: 44)
                    }
                    .padding()
                    .background(LinearGradient(colors: [Color.black.opacity(0.7), Color.clear], startPoint: .top, endPoint: .bottom))
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.tabiOrange.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                        .frame(width: 300, height: 200)
                        .overlay(VStack(spacing: 8) {
                            Image(systemName: "doc.text.viewfinder").font(.system(size: 40)).foregroundColor(.tabiOrange.opacity(0.85))
                            Text("Position label here").font(.caption).foregroundColor(.white.opacity(0.8))
                        })
                    Spacer()
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle().fill(Color.tabiOrange).frame(width: 80, height: 80)
                            Circle().stroke(Color.tabiOrange.opacity(0.4), lineWidth: 6).frame(width: 100, height: 100)
                            Image(systemName: "camera.fill").font(.title2).foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 50)
                }
            } else {
                VStack(spacing: 30) {
                    Image(systemName: "camera.fill").font(.system(size: 60)).foregroundColor(.tabiOrange)
                    VStack(spacing: 16) {
                        Text("Camera Access Required").font(.title2.bold()).foregroundColor(.white)
                        Text("TABI needs camera access to scan your medication labels.")
                            .font(.body).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    Button("Enable Camera") { cameraManager.requestPermission() }
                        .font(.headline).foregroundColor(.tabiOrange)
                        .frame(maxWidth: .infinity).padding().background(Color.white).cornerRadius(12).padding(.horizontal, 32)
                }
            }
        }
        .onAppear { cameraManager.checkPermission(); if cameraManager.isAuthorized && !hasAttemptedSetup { setupAndStartCamera() } }
        .onChange(of: cameraManager.isAuthorized) { _, v in if v && !hasAttemptedSetup { setupAndStartCamera() } }
        .onDisappear { cameraManager.stopSession(); hasAttemptedSetup = false }
        .sheet(isPresented: $showingDetectionResult) {
            if let image = capturedImage, let info = detectedInfo {
                DetectedMedicationView(image: image, detectedInfo: info,
                    onSave: { finalInfo in
                        let idx = medicationManager.medications.count
                        let newMed = Medication(name: finalInfo.medicationName, type: "Tablet", emoji: "💊", dosageTime: finalInfo.scheduleTime, dosage: finalInfo.dosage, scheduleLabel: "Every Day", points: 10, colorIndex: idx)
                        medicationManager.medications.append(newMed)
                        let schedule = MedicationScheduleParser.parse(info: finalInfo, medication: newMed)
                        CalendarPersistenceManager.shared.save(schedule: schedule)
                        NotificationScheduler.shared.schedule(for: schedule)
                        showingDetectionResult = false; isPresented = false
                    },
                    onCancel: { showingDetectionResult = false })
            }
        }
    }

    func setupAndStartCamera() {
        hasAttemptedSetup = true
        if cameraManager.isSetup { cameraManager.startSession() }
        else { cameraManager.setupSession { self.cameraManager.startSession() } }
    }
    func capturePhoto() {
        cameraManager.capturePhoto { image in
            self.cameraManager.stopSession()
            if let image = image {
                MedicationAnalyzer.shared.detectMedicationFromLabel(image: image) { info in
                    DispatchQueue.main.async { self.capturedImage = image; self.detectedInfo = info; self.showingDetectionResult = true }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cameraManager.startSession() }
            }
        }
    }
}

// OLD CAMERA VIEW - Replace your CameraView with this

struct CameraView: View {
    let medication: Medication
    @ObservedObject var medicationManager: MedicationManager
    @Binding var isPresented: Bool
    @ObservedObject private var cameraManager = CameraManager.shared  // Use singleton!
    @State private var showingAnalysis = false
    @State private var capturedImage: UIImage?
    @State private var analysisResult: MedicationAnalyzer.AnalysisResult?  // Store analysis result
    @State private var hasAttemptedSetup = false  // Track if we've tried to setup
    
    init(medication: Medication, medicationManager: MedicationManager, isPresented: Binding<Bool>) {
        self.medication = medication
        self.medicationManager = medicationManager
        self._isPresented = isPresented
        print("✅ CameraView INIT for medication: \(medication.name)")
        print("   🔍 Using shared CameraManager - isAuthorized: \(CameraManager.shared.isAuthorized)")
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // ENHANCED DEBUG OVERLAY
            VStack(spacing: 4) {
                Text("🔍 DEBUG STATUS")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
                
                HStack {
                    Text("Auth:")
                    Text(cameraManager.isAuthorized ? "✅" : "❌")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Running:")
                    Text(cameraManager.isSessionRunning ? "✅" : "❌")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Setup:")
                    Text(cameraManager.isSetup ? "✅" : "❌")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Inputs:")
                    Text("\(cameraManager.session.inputs.count)")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Outputs:")
                    Text("\(cameraManager.session.outputs.count)")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                // MANUAL START BUTTON
                Button(action: {
                    print("🔵 MANUAL START BUTTON TAPPED")
                    cameraManager.forceSetupAndStart()
                }) {
                    Text("🚀 START CAMERA")
                        .font(.caption2.bold())
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.yellow)
                        .cornerRadius(4)
                }
                .padding(.top, 4)
            }
            .padding(8)
            .background(Color.red.opacity(0.9))
            .cornerRadius(8)
            .position(x: UIScreen.main.bounds.width / 2, y: 100)
            .zIndex(1000)
            
            if cameraManager.isAuthorized {
                // Camera Preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer().frame(height: 150) // Space for debug box
                    
                    // Top header
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Position pill in center")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(medication.name)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Center overlay guide
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                        .frame(width: 220, height: 220)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Place pill here")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack {
                        Button(action: {}) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundColor(.white)
                                )
                        }
                        .disabled(true)
                        
                        Spacer()
                        
                        // Capture button
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 6)
                                    .frame(width: 100, height: 100)
                            }
                        }
                        
                        Spacer()
                        
                        // Restart button
                        Button(action: {
                            print("🔄 RESTART BUTTON TAPPED")
                            cameraManager.stopSession()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                cameraManager.startSession()
                            }
                        }) {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.yellow)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            } else {
                // Camera permission request
                VStack(spacing: 30) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(spacing: 16) {
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("PillQuest needs camera access to verify your medications and help you stay on track.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Button("Enable Camera") {
                        cameraManager.requestPermission()
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Button("Not Now") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            print("📱 ========== CameraView APPEARED ==========")
            print("📱 Medication: \(medication.name)")
            print("📱 Using SHARED CameraManager instance")
            print("📱 isAuthorized: \(cameraManager.isAuthorized)")
            print("📱 isSetup: \(cameraManager.isSetup)")
            print("📱 isRunning: \(cameraManager.isSessionRunning)")
            
            // Always check permission status
            cameraManager.checkPermission()
            
            // If already authorized, proceed immediately
            if cameraManager.isAuthorized && !hasAttemptedSetup {
                print("📱 Already authorized on appear - setting up")
                setupAndStartCamera()
            }
        }
        .onChange(of: cameraManager.isAuthorized) { oldValue, newValue in
            print("📱 ========== isAuthorized CHANGED to: \(newValue) ==========")
            if newValue && !hasAttemptedSetup {
                print("📱 Authorization granted - setting up camera")
                setupAndStartCamera()
            }
        }
        .onDisappear {
            print("📱 ========== CameraView DISAPPEARED ==========")
            print("📱 Stopping session (CameraManager persists)")
            cameraManager.stopSession()
            hasAttemptedSetup = false  // Reset for next time
        }
        .sheet(isPresented: $showingAnalysis) {
            if let image = capturedImage {
                AnalysisResultView(
                    capturedImage: image,
                    medicationName: medication.name,
                    medicationPoints: medication.points,
                    analysisResult: analysisResult,  // Pass the analysis result
                    onContinue: {
                        medicationManager.recordMedicationTaken(medication, points: medication.points)
                        showingAnalysis = false
                        isPresented = false
                    },
                    onRetake: {
                        showingAnalysis = false
                        analysisResult = nil
                        capturedImage = nil
                    },
                    onCancel: {
                        showingAnalysis = false
                        isPresented = false
                    }
                )
            }
        }
    }
    
    func setupAndStartCamera() {
        print("📱 ========== setupAndStartCamera CALLED ==========")
        hasAttemptedSetup = true
        
        if cameraManager.isSetup {
            print("📱 Already setup - just starting session")
            cameraManager.startSession()
        } else {
            print("📱 Not setup yet - setting up then starting")
            cameraManager.setupSession {
                print("📱 Setup completed - now starting session")
                self.cameraManager.startSession()
            }
        }
    }
    
    func capturePhoto() {
        print("📸 Capture button tapped")
        cameraManager.capturePhoto { image in
            if let image = image {
                print("📸 Photo captured - starting AI analysis...")
                
                // Perform real AI analysis
                MedicationAnalyzer.shared.analyzePill(image: image, expectedMedication: self.medication) { result in
                    print("✅ Analysis complete:")
                    print("   - Match: \(result.isMatch)")
                    print("   - Confidence: \(Int(result.confidence * 100))%")
                    print("   - Detected text count: \(result.detectedText.count)")
                    print("   - Detected text: \(result.detectedText)")
                    print("   - Valid medication detected: \(result.validMedicationDetected)")
                    print("   - Matched terms: \(result.matchedTerms)")
                    print("   - Color: \(result.colorProfile)")
                    print("   - Shape detected: \(result.shapeDetected)")
                    
                    DispatchQueue.main.async {
                        self.capturedImage = image
                        self.analysisResult = result
                        self.showingAnalysis = true
                    }
                }
            }
        }
    }
}

// ENHANCED CAMERA MANAGER - SINGLETON (persists across views!)

class CameraManager: NSObject, ObservableObject {
    // Singleton instance - shared across all views
    static let shared = CameraManager()
    
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var isSetup = false
    
    private var photoOutput: AVCapturePhotoOutput?
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Private init to enforce singleton
    private override init() {
        super.init()
        print("🎬 ========== CameraManager SINGLETON INIT (only happens once!) ==========")
        // DON'T call checkPermission here - let the view control the lifecycle
        // Just check the permission status and update the published property
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔐 Initial camera permission status: \(status.rawValue)")
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized)
            print("🔐 Initial isAuthorized set to: \(self.isAuthorized)")
        }
    }
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔐 Camera permission status raw value: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("✅ Camera AUTHORIZED")
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            // DON'T auto-setup here - let the caller handle it
            print("✅ Permission check complete - caller should handle setup/start")
        case .notDetermined:
            print("❓ Camera permission NOT DETERMINED - will request")
            requestPermission()
        case .denied:
            print("❌ Camera permission DENIED")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        case .restricted:
            print("🚫 Camera permission RESTRICTED")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        @unknown default:
            print("⚠️ Unknown camera permission status")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    func requestPermission() {
        print("🔐 Requesting camera permission...")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("🔐 Permission result: \(granted ? "✅ GRANTED" : "❌ DENIED")")
            DispatchQueue.main.async {
                self.isAuthorized = granted
                // Let the view's onChange handler take care of setup/start
                print("🔐 Published isAuthorized updated - view should react via onChange")
            }
        }
    }
    
    // NEW: Force setup and start (for manual button)
    func forceSetupAndStart() {
        print("🚀 ========== FORCE SETUP AND START ==========")
        print("🚀 Current state:")
        print("   - isAuthorized: \(isAuthorized)")
        print("   - isSetup: \(isSetup)")
        print("   - isRunning: \(session.isRunning)")
        print("   - inputs: \(session.inputs.count)")
        print("   - outputs: \(session.outputs.count)")
        
        if !isAuthorized {
            print("❌ Not authorized - cannot start")
            return
        }
        
        if !isSetup {
            print("🔧 Not setup - calling setupSession")
            setupSession {
                print("✅ Setup completed in forceSetupAndStart - now starting session")
                self.startSession()
            }
        } else {
            print("✅ Already setup - calling startSession")
            startSession()
        }
    }
    
    func startSession() {
        print("🎥 ========== START SESSION CALLED ==========")
        print("   - isAuthorized: \(isAuthorized)")
        print("   - isSetup: \(isSetup)")
        print("   - isRunning: \(session.isRunning)")
        print("   - Published isSessionRunning: \(isSessionRunning)")
        
        guard isAuthorized else {
            print("❌ Cannot start - not authorized")
            return
        }
        
        if !isSetup {
            print("⚠️ Not setup yet - calling setupSession first")
            setupSession {
                print("✅ Setup completed in startSession - now starting")
                self.startSession()
            }
            return
        }
        
        sessionQueue.async {
            // Always check the actual session state, not just our published property
            if self.session.isRunning {
                print("⚠️ Session already running - stopping first for clean restart")
                self.session.stopRunning()
                // Brief pause to ensure clean stop
                Thread.sleep(forTimeInterval: 0.2)
            }
            
            print("🎥 Starting session on background queue...")
            print("   - Inputs before start: \(self.session.inputs.count)")
            print("   - Outputs before start: \(self.session.outputs.count)")
            
            self.session.startRunning()
            
            // Small delay to let the session actually start
            Thread.sleep(forTimeInterval: 0.1)
            
            let isRunning = self.session.isRunning
            print("🎥 Session.startRunning() completed. isRunning: \(isRunning)")
            
            if !isRunning {
                print("❌ WARNING: Session failed to start! Debugging info:")
                print("   - Inputs: \(self.session.inputs.count)")
                print("   - Outputs: \(self.session.outputs.count)")
                print("   - Preset: \(self.session.sessionPreset.rawValue)")
                
                // Try to diagnose the issue
                if self.session.inputs.isEmpty {
                    print("❌ PROBLEM: No inputs configured!")
                }
                if self.session.outputs.isEmpty {
                    print("❌ PROBLEM: No outputs configured!")
                }
            }
            
            DispatchQueue.main.async {
                self.isSessionRunning = isRunning
                print("✅ Published isSessionRunning updated to: \(isRunning)")
            }
        }
    }
    
    func stopSession() {
        print("🛑 ========== STOP SESSION CALLED ==========")
        print("   - isRunning before: \(session.isRunning)")
        print("   - Published isSessionRunning before: \(isSessionRunning)")
        
        // Always try to stop, even if we think it's not running
        sessionQueue.async {
            if self.session.isRunning {
                print("🛑 Stopping session...")
                self.session.stopRunning()
                
                // Wait a bit to ensure it's fully stopped
                Thread.sleep(forTimeInterval: 0.2)
                
                let stillRunning = self.session.isRunning
                print("🛑 After stop, isRunning: \(stillRunning)")
            } else {
                print("🛑 Session already stopped")
            }
            
            // Always update state to ensure consistency
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("✅ Session stopped, published state updated to false")
            }
        }
    }
    
    func setupSession(completion: (() -> Void)? = nil) {
        print("⚙️ ========== SETUP SESSION CALLED ==========")
        
        if isSetup {
            print("⚠️ Already setup - calling completion immediately on main thread")
            // Important: Call completion on main thread asynchronously to maintain consistency
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        
        guard isAuthorized else {
            print("❌ Cannot setup - not authorized")
            return
        }
        
        sessionQueue.async {
            print("⚙️ Setting up session on background queue...")
            
            // Remove any existing inputs/outputs to start fresh
            for input in self.session.inputs {
                self.session.removeInput(input)
                print("🗑️ Removed existing input")
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
                print("🗑️ Removed existing output")
            }
            
            self.session.beginConfiguration()
            print("⚙️ Session configuration began")
            
            // Set preset
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
                print("✅ Session preset set to .photo")
            } else {
                print("⚠️ Cannot set preset to .photo")
            }
            
            // Get camera
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ CRITICAL: No back camera found!")
                self.session.commitConfiguration()
                return
            }
            
            print("📷 Found camera: \(camera.localizedName)")
            print("📷 Camera uniqueID: \(camera.uniqueID)")
            
            // Create input
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                print("✅ Created AVCaptureDeviceInput")
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    print("✅ Camera input added to session")
                    print("   Total inputs: \(self.session.inputs.count)")
                } else {
                    print("❌ CRITICAL: Cannot add camera input to session")
                }
            } catch {
                print("❌ CRITICAL: Error creating camera input: \(error.localizedDescription)")
                self.session.commitConfiguration()
                return
            }
            
            // Create output
            let output = AVCapturePhotoOutput()
            print("✅ Created AVCapturePhotoOutput")
            
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
                output.isHighResolutionCaptureEnabled = true
                self.photoOutput = output
                print("✅ Photo output added to session")
                print("   Total outputs: \(self.session.outputs.count)")
            } else {
                print("❌ CRITICAL: Cannot add photo output to session")
            }
            
            self.session.commitConfiguration()
            print("✅ Session configuration committed")
            
            print("📊 Final session state:")
            print("   - Inputs: \(self.session.inputs.count)")
            print("   - Outputs: \(self.session.outputs.count)")
            print("   - Preset: \(self.session.sessionPreset.rawValue)")
            
            DispatchQueue.main.async {
                self.isSetup = true
                print("✅ Published isSetup updated to: true")
                print("⚙️ ========== SETUP COMPLETE ==========")
                
                // Call completion handler after state is updated
                completion?()
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        print("📸 ========== CAPTURE PHOTO CALLED ==========")
        
        guard let photoOutput = photoOutput else {
            print("❌ No photo output available")
            completion(nil)
            return
        }
        
        guard session.isRunning else {
            print("❌ Session not running - cannot capture")
            completion(nil)
            return
        }
        
        print("📸 Creating photo settings...")
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        print("📸 Capturing photo with settings...")
        
        currentPhotoDelegate = PhotoCaptureDelegate { image in
            if image != nil {
                print("✅ Photo captured successfully!")
            } else {
                print("❌ Photo capture failed")
            }
            completion(image)
        }
        
        photoOutput.capturePhoto(with: settings, delegate: currentPhotoDelegate!)
        print("📸 capturePhoto called on photoOutput")
    }
}
// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Photo Capture Delegate

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo error: \(error)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        completion(image)
    }
}

// MARK: - Medication Analyzer (AI Vision)

class MedicationAnalyzer {
    static let shared = MedicationAnalyzer()
    
    struct AnalysisResult {
        let isMatch: Bool
        let confidence: Double
        let detectedText: [String]
        let colorProfile: String
        let shapeDetected: Bool
        let validMedicationDetected: Bool
        let matchedTerms: [String]
    }
    
    func analyzePill(image: UIImage, expectedMedication: Medication, completion: @escaping (AnalysisResult) -> Void) {
        // Old verification method - keeping for compatibility
        guard let cgImage = image.cgImage else {
            completion(AnalysisResult(
                isMatch: false,
                confidence: 0.0,
                detectedText: [],
                colorProfile: "unknown",
                shapeDetected: false,
                validMedicationDetected: false,
                matchedTerms: []
            ))
            return
        }
        
        var detectedTexts: [String] = []
        var hasShape = false
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        recognizeText(in: cgImage) { texts in
            detectedTexts = texts
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        detectPillShape(in: cgImage) { detected in
            hasShape = detected
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let colorProfile = self.analyzeColor(image: image)
            let validationResult = self.validateMedicationText(
                detectedTexts: detectedTexts,
                expectedMedication: expectedMedication
            )
            
            let confidence = self.calculateConfidence(
                textMatch: validationResult.isMatch,
                hasShape: hasShape,
                colorProfile: colorProfile,
                hasValidMedTerms: validationResult.hasValidTerms
            )
            
            let result = AnalysisResult(
                isMatch: confidence > 0.5,
                confidence: confidence,
                detectedText: detectedTexts,
                colorProfile: colorProfile,
                shapeDetected: hasShape,
                validMedicationDetected: validationResult.hasValidTerms,
                matchedTerms: validationResult.matchedTerms
            )
            
            completion(result)
        }
    }
    
    // NEW: Detect medication info from prescription label
    func detectMedicationFromLabel(image: UIImage, completion: @escaping (DetectedMedicationInfo) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(DetectedMedicationInfo(
                medicationName: "Unknown Medication",
                schedule: "Daily",
                dosage: "Unknown",
                scheduleTime: Date(),
                allDetectedText: []
            ))
            return
        }
        
        recognizeText(in: cgImage) { detectedTexts in
            print("📝 Detected texts from label:")
            detectedTexts.forEach { print("  - \($0)") }
            
            // Extract medication name and schedule
            let info = self.extractMedicationInfo(from: detectedTexts)
            completion(info)
        }
    }
    
    private func extractMedicationInfo(from texts: [String]) -> DetectedMedicationInfo {
        var medicationName = "Unknown Medication"
        var schedule = "Take as directed"
        var dosage = ""
        var scheduleTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        
        // Common medication name patterns (case-insensitive partial matches)
        let medicationKeywords = [
            "hydrocodone", "acetaminophen", "acetamin",  // Added "acetamin" for truncated versions
            "doxycycline", "hyclate",  // Added "hyclate" for doxycycline hyclate
            "vitamin", "ibuprofen", "amoxicillin",
            "lisinopril", "metformin", "atorvastatin", "omeprazole"
        ]
        
        // Dosage patterns
        let dosagePattern = /(\d+[-\s]?\d*\s*(MG|MCG|mg|mcg))/
        
        // Schedule patterns
        let scheduleKeywords = ["daily", "twice", "once", "every", "morning", "evening", "night", "take"]
        
        // STEP 1: Find dosage first (this is usually very reliable)
        var dosageIndex: Int?
        for (index, text) in texts.enumerated() {
            if let match = text.firstMatch(of: dosagePattern) {
                dosage = String(match.0)
                dosageIndex = index
                print("✅ Found dosage at index \(index): \(dosage)")
                break
            }
        }
        
        // STEP 2: Look for medication name near the dosage (usually 1-3 lines before)
        if let dosageIdx = dosageIndex {
            // Check the 3 lines before dosage for medication name
            let searchRange = max(0, dosageIdx - 3)..<dosageIdx
            
            for index in searchRange.reversed() {
                let text = texts[index]
                let lowerText = text.lowercased()
                
                // Check if this line contains medication keywords
                for keyword in medicationKeywords {
                    if lowerText.contains(keyword) {
                        // Found a medication keyword!
                        // Check if the next line also contains medication keywords (multi-line name)
                        var fullName = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Look ahead one line to see if it's a continuation
                        if index + 1 < texts.count && index + 1 < dosageIdx {
                            let nextLine = texts[index + 1]
                            let nextLowerText = nextLine.lowercased()
                            
                            // If next line also contains medication keywords, combine them
                            for nextKeyword in medicationKeywords {
                                if nextLowerText.contains(nextKeyword) {
                                    fullName += " " + nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
                                    print("📋 Combined multi-line medication name")
                                    break
                                }
                            }
                        }
                        
                        // Clean up the medication name
                        medicationName = fullName
                            .replacingOccurrences(of: "-\n", with: "")  // Remove line-break hyphens
                            .replacingOccurrences(of: "\n", with: " ")  // Replace newlines with spaces
                            .trimmingCharacters(in: .punctuationCharacters)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Capitalize properly (title case)
                        medicationName = medicationName
                            .split(separator: " ")
                            .map { word in
                                let lower = word.lowercased()
                                return lower == "and" || lower == "with" ? lower : word.capitalized
                            }
                            .joined(separator: " ")
                        
                        print("✅ Found medication name near dosage: \(medicationName)")
                        break
                    }
                }
                
                if medicationName != "Unknown Medication" {
                    break
                }
            }
        }
        
        // STEP 3: Fallback - look in first 5 lines if we didn't find it near dosage
        if medicationName == "Unknown Medication" {
            print("⚠️ Fallback: searching first 5 lines for medication name")
            
            for (index, text) in texts.enumerated() where index < 5 {
                let lowerText = text.lowercased()
                
                for keyword in medicationKeywords {
                    if lowerText.contains(keyword) {
                        // Found potential medication name
                        var fullName = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Check if next line is a continuation
                        if index + 1 < min(texts.count, 5) {
                            let nextLine = texts[index + 1]
                            let nextLowerText = nextLine.lowercased()
                            
                            for nextKeyword in medicationKeywords {
                                if nextLowerText.contains(nextKeyword) {
                                    fullName += " " + nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
                                    break
                                }
                            }
                        }
                        
                        medicationName = fullName
                            .replacingOccurrences(of: "-\n", with: "")
                            .replacingOccurrences(of: "\n", with: " ")
                            .trimmingCharacters(in: .punctuationCharacters)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Capitalize properly
                        medicationName = medicationName
                            .split(separator: " ")
                            .map { word in
                                let lower = word.lowercased()
                                return lower == "and" || lower == "with" ? lower : word.capitalized
                            }
                            .joined(separator: " ")
                        
                        print("✅ Found medication name (fallback): \(medicationName)")
                        break
                    }
                }
                
                if medicationName != "Unknown Medication" {
                    break
                }
            }
        }
        
        // STEP 4: Extract schedule
        for text in texts {
            let lowerText = text.lowercased()
            
            for keyword in scheduleKeywords {
                if lowerText.contains(keyword) {
                    schedule = text
                    print("✅ Found schedule: \(schedule)")
                    
                    // Try to extract time
                    if lowerText.contains("morning") {
                        scheduleTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
                    } else if lowerText.contains("evening") || lowerText.contains("night") {
                        scheduleTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                    } else if lowerText.contains("twice") {
                        scheduleTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
                    }
                    break
                }
            }
        }
        
        print("📊 Final extraction results:")
        print("   - Medication: \(medicationName)")
        print("   - Dosage: \(dosage)")
        print("   - Schedule: \(schedule)")
        
        return DetectedMedicationInfo(
            medicationName: medicationName,
            schedule: schedule,
            dosage: dosage,
            scheduleTime: scheduleTime,
            allDetectedText: texts
        )
    }
    
    func analyzePill_old(image: UIImage, expectedMedication: Medication, completion: @escaping (AnalysisResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(AnalysisResult(
                isMatch: false,
                confidence: 0.0,
                detectedText: [],
                colorProfile: "unknown",
                shapeDetected: false,
                validMedicationDetected: false,
                matchedTerms: []
            ))
            return
        }
        
        var detectedTexts: [String] = []
        var hasShape = false
        
        let dispatchGroup = DispatchGroup()
        
        // 1. Text Recognition (for pill markings/imprints)
        dispatchGroup.enter()
        recognizeText(in: cgImage) { texts in
            detectedTexts = texts
            dispatchGroup.leave()
        }
        
        // 2. Shape Detection (detect pill-like shapes)
        dispatchGroup.enter()
        detectPillShape(in: cgImage) { detected in
            hasShape = detected
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            // Analyze results
            let colorProfile = self.analyzeColor(image: image)
            
            // Enhanced matching with medication validation
            let validationResult = self.validateMedicationText(
                detectedTexts: detectedTexts,
                expectedMedication: expectedMedication
            )
            
            let confidence = self.calculateConfidence(
                textMatch: validationResult.isMatch,
                hasShape: hasShape,
                colorProfile: colorProfile,
                hasValidMedTerms: validationResult.hasValidTerms
            )
            
            let result = AnalysisResult(
                isMatch: confidence > 0.5,
                confidence: confidence,
                detectedText: detectedTexts,
                colorProfile: colorProfile,
                shapeDetected: hasShape,
                validMedicationDetected: validationResult.hasValidTerms,
                matchedTerms: validationResult.matchedTerms
            )
            
            completion(result)
        }
    }
    
    private func validateMedicationText(detectedTexts: [String], expectedMedication: Medication) -> (isMatch: Bool, hasValidTerms: Bool, matchedTerms: [String]) {
        // Keywords that indicate medication-related text
        let medKeywords = ["mg", "mcg", "tablet", "capsule", "pill", "dose", "rx", "vitamin", "daily", "once", "twice", "take"]
        
        var matchedTerms: [String] = []
        var hasValidTerms = false
        var isExactMatch = false
        
        // Combine all detected text for medication name matching
        let allText = detectedTexts.joined(separator: " ").lowercased()
        let expectedName = expectedMedication.name.lowercased()
        
        // Extract medication name words for matching (keep all words, even short ones initially)
        let medicationWords = expectedName
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 } // Skip short words like "mg", "d"
        
        print("🔍 Looking for medication: \(expectedName)")
        print("🔍 Key words: \(medicationWords)")
        
        // Helper function for fuzzy matching (handles OCR errors)
        func fuzzyMatch(_ word1: String, _ word2: String) -> Bool {
            let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
            
            // Exact match
            if w1 == w2 { return true }
            
            // One contains the other (handles substring matches)
            if w1.contains(w2) || w2.contains(w1) { return true }
            
            // Check if they share a significant prefix (handles truncation/OCR errors)
            let minLength = min(w1.count, w2.count)
            if minLength >= 4 { // Lowered from 5 to catch shorter matches
                let prefixLength = min(minLength, 7) // Check up to 7 chars
                if w1.prefix(prefixLength) == w2.prefix(prefixLength) {
                    print("   🔍 Prefix match: '\(w1.prefix(prefixLength))' == '\(w2.prefix(prefixLength))'")
                    return true
                }
            }
            
            // Calculate similarity ratio for very close matches
            let similarity = stringSimilarity(w1, w2)
            if similarity > 0.75 { // 75% similar
                print("   🔍 Similarity match: \(Int(similarity * 100))% similar")
                return true
            }
            
            return false
        }
        
        // Levenshtein distance-based similarity
        func stringSimilarity(_ s1: String, _ s2: String) -> Double {
            let longer = s1.count > s2.count ? s1 : s2
            let shorter = s1.count > s2.count ? s2 : s1
            
            if longer.count == 0 { return 1.0 }
            
            let editDistance = levenshteinDistance(Array(shorter), Array(longer))
            return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
        }
        
        // Calculate Levenshtein distance
        func levenshteinDistance(_ s1: [Character], _ s2: [Character]) -> Int {
            let m = s1.count
            let n = s2.count
            
            var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
            
            for i in 0...m { matrix[i][0] = i }
            for j in 0...n { matrix[0][j] = j }
            
            for i in 1...m {
                for j in 1...n {
                    let cost = s1[i-1] == s2[j-1] ? 0 : 1
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,      // deletion
                        matrix[i][j-1] + 1,      // insertion
                        matrix[i-1][j-1] + cost  // substitution
                    )
                }
            }
            
            return matrix[m][n]
        }
        
        // Check for medication name match (with fuzzy matching for OCR errors)
        for medWord in medicationWords {
            // Check in combined text
            if allText.contains(medWord) {
                isExactMatch = true
                print("✅ Found exact medication word: '\(medWord)'")
                break
            }
            
            // Check each detected text with fuzzy matching
            for detectedText in detectedTexts {
                let detectedWords = detectedText.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                
                for detectedWord in detectedWords {
                    if fuzzyMatch(medWord, detectedWord) {
                        isExactMatch = true
                        print("✅ Fuzzy matched '\(medWord)' with detected '\(detectedWord)'")
                        break
                    }
                }
                if isExactMatch { break }
            }
            if isExactMatch { break }
        }
        
        // Find the most relevant text snippets (prioritize medication-related content)
        for text in detectedTexts {
            let lowerText = text.lowercased()
            let textWords = lowerText.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            var isRelevant = false
            
            // Priority 1: Contains medication name (exact or fuzzy match)
            for medWord in medicationWords {
                if lowerText.contains(medWord) {
                    isRelevant = true
                    print("📌 Medication name found in: '\(text)'")
                    break
                }
                
                // Fuzzy match check
                for textWord in textWords {
                    if fuzzyMatch(medWord, textWord) {
                        isRelevant = true
                        print("📌 Medication name (fuzzy) found in: '\(text)'")
                        break
                    }
                }
                if isRelevant { break }
            }
            
            // Priority 2: Contains medication keywords (dosage, instructions, etc.)
            if !isRelevant && medKeywords.contains(where: { lowerText.contains($0) }) {
                isRelevant = true
                hasValidTerms = true
                print("💊 Medication keyword found in: '\(text)'")
            }
            
            if isRelevant {
                matchedTerms.append(text)
            }
        }
        
        // Deduplicate and keep only top 3 most relevant terms
        matchedTerms = deduplicateMatchedTerms(matchedTerms)
            .prefix(3)
            .map { String($0) }
        
        print("📊 Final matched terms: \(matchedTerms)")
        print("📊 Match: \(isExactMatch), Valid terms: \(hasValidTerms)")
        
        return (isExactMatch, hasValidTerms, matchedTerms)
    }
    
    private func deduplicateMatchedTerms(_ terms: [String]) -> [String] {
        // Normalize a string by removing spaces, hyphens, punctuation, and converting to lowercase
        func normalize(_ text: String) -> String {
            return text.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .components(separatedBy: CharacterSet.punctuationCharacters)
                .joined()
        }
        
        var uniqueTerms: [String] = []
        var seenNormalized: Set<String> = []
        
        for term in terms {
            let normalized = normalize(term)
            
            // Check if we've seen this normalized version
            if !seenNormalized.contains(normalized) {
                // Keep the version with the most formatting (spaces/hyphens)
                // This prefers "5-235 MG" over "5-235MG" or "5235MG"
                let formattingScore = term.filter { $0 == " " || $0 == "-" }.count
                
                // Check if there's a similar term already added
                if let existingIndex = uniqueTerms.firstIndex(where: { normalize($0) == normalized }) {
                    let existingScore = uniqueTerms[existingIndex].filter { $0 == " " || $0 == "-" }.count
                    
                    // Replace with better formatted version
                    if formattingScore > existingScore {
                        uniqueTerms[existingIndex] = term
                    }
                } else {
                    uniqueTerms.append(term)
                    seenNormalized.insert(normalized)
                }
            }
        }
        
        return uniqueTerms
    }
    
    private func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            // Sort observations by vertical position (top to bottom)
            let sortedObservations = observations.sorted { obs1, obs2 in
                // Higher Y value = lower on screen (Vision uses bottom-left origin)
                obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
            }
            
            print("📝 === Text Detection (Top to Bottom) ===")
            
            var allTexts: [(text: String, position: Int, isBold: Bool)] = []
            
            for (index, observation) in sortedObservations.enumerated() {
                let candidates = observation.topCandidates(3)
                
                // Check if text appears bold
                let isBold = self.isBoldText(observation: observation, in: image)
                
                for candidate in candidates {
                    let text = candidate.string
                    let position = index
                    
                    allTexts.append((text, position, isBold))
                    
                    // Enhanced logging
                    let boldIndicator = isBold ? "📌 BOLD" : "📄 normal"
                    print("📝 Line \(position): '\(text)' [\(boldIndicator)]")
                }
            }
            
            // Remove duplicates and filter empty strings
            let uniqueTexts = Array(Set(allTexts.map { $0.text }))
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted()
            
            print("📝 Total unique texts detected: \(uniqueTexts.count)")
            completion(uniqueTexts)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }
    
    // Helper function to detect bold text based on pixel density
    private func isBoldText(observation: VNRecognizedTextObservation, in image: CGImage) -> Bool {
        let boundingBox = observation.boundingBox
        
        // Convert normalized coordinates to pixel coordinates
        let imageHeight = CGFloat(image.height)
        let imageWidth = CGFloat(image.width)
        
        let rect = CGRect(
            x: boundingBox.origin.x * imageWidth,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )
        
        // Crop to text region
        guard let croppedImage = image.cropping(to: rect) else { return false }
        
        // Analyze pixel density - bold text has more dark pixels
        let density = calculatePixelDensity(in: croppedImage)
        
        // Threshold: bold text typically has density > 0.35
        return density > 0.35
    }
    
    private func calculatePixelDensity(in image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0.0
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0.0 }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var darkPixels = 0
        let sampleRate = 2 // Check every 2nd pixel for performance
        
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let offset = (y * width + x) * bytesPerPixel
                let r = Int(buffer[offset])
                let g = Int(buffer[offset + 1])
                let b = Int(buffer[offset + 2])
                
                // Calculate brightness
                let brightness = (r + g + b) / 3
                
                // Dark pixels (likely text)
                if brightness < 128 {
                    darkPixels += 1
                }
            }
        }
        
        let sampledPixels = (width / sampleRate) * (height / sampleRate)
        return Double(darkPixels) / Double(sampledPixels)
    }
    
    private func detectPillShape(in image: CGImage, completion: @escaping (Bool) -> Void) {
        let request = VNDetectContoursRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNContoursObservation] else {
                completion(false)
                return
            }
            
            // If we detect any contours, it's likely a pill
            let hasContours = !observations.isEmpty
            print("🔍 Shape detected: \(hasContours)")
            completion(hasContours)
        }
        
        request.contrastAdjustment = 1.5
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }
    
    private func analyzeColor(image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "unknown" }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                   y: ciImage.extent.origin.y,
                                   z: ciImage.extent.size.width,
                                   w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                   parameters: [kCIInputImageKey: ciImage,
                                              kCIInputExtentKey: extentVector]) else {
            return "unknown"
        }
        
        guard let outputImage = filter.outputImage else { return "unknown" }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        // Simple color classification
        let r = bitmap[0]
        let g = bitmap[1]
        let b = bitmap[2]
        
        let color: String
        if r > 200 && g > 200 && b > 200 {
            color = "white"
        } else if r > 150 && g < 100 && b < 100 {
            color = "red"
        } else if r < 100 && g < 100 && b > 150 {
            color = "blue"
        } else if r > 150 && g > 150 && b < 100 {
            color = "yellow"
        } else if r > 150 && g > 100 && b < 100 {
            color = "orange"
        } else {
            color = "other"
        }
        
        print("🎨 Detected color: \(color)")
        return color
    }
    
    private func calculateConfidence(textMatch: Bool, hasShape: Bool, colorProfile: String, hasValidMedTerms: Bool) -> Double {
        var confidence = 0.2 // Base confidence for taking a photo
        
        if textMatch { confidence += 0.5 }  // Exact medication name match - strongest indicator
        else if hasValidMedTerms { confidence += 0.2 }  // Has medication-related terms
        
        if hasShape { confidence += 0.2 }    // Shape detected
        if colorProfile != "unknown" { confidence += 0.1 }  // Color identified
        
        return min(confidence, 1.0)
    }
}

// MARK: - Detected Medication View (Review & Confirm)

struct DetectedMedicationView: View {
    let image: UIImage
    @State var detectedInfo: DetectedMedicationInfo
    let onSave: (DetectedMedicationInfo) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 200).cornerRadius(12).padding()
                    VStack(spacing: 16) {
                        field("Medication Name", placeholder: "e.g., Vitamin D", binding: $detectedInfo.medicationName)
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
    private func field(_ label: String, placeholder: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.tabiGray)
            TextField(placeholder, text: binding).textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}


// MARK: - Analysis Result View

struct AnalysisResultView: View {
    let capturedImage: UIImage
    let medicationName: String
    let medicationPoints: Int
    let analysisResult: MedicationAnalyzer.AnalysisResult?
    let onContinue: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnalyzing = true
    @State private var showScheduleInfo = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text(isAnalyzing ? "📊 Analyzing Photo" : "Results")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isAnalyzing ? Color.gray : (analysisResult?.isMatch == true ? Color.green : Color.orange), lineWidth: 3)
                )
            
            if isAnalyzing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("AI is analyzing your medication...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Checking pill shape, color, and markings")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            } else if let result = analysisResult {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Text(result.isMatch ? "✅" : "⚠️")
                            .font(.system(size: 50))
                        
                        Text(result.isMatch ? "Pill Verified!" : "Needs Review")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(result.isMatch ? .green : .orange)
                        
                        if result.isMatch && result.validMedicationDetected {
                            Text("Successfully identified \(medicationName)")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text("Valid medication markings detected")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if result.isMatch {
                            Text("Successfully identified \(medicationName)")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else if result.validMedicationDetected {
                            Text("Medication detected but please verify")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text("Markings don't exactly match \(medicationName)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("Please verify this is \(medicationName)")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Confidence bar
                        VStack(spacing: 4) {
                            HStack {
                                Text("Confidence:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(result.confidence * 100))%")
                                    .font(.caption.bold())
                                    .foregroundColor(result.isMatch ? .green : .orange)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(result.isMatch ? Color.green : Color.orange)
                                        .frame(width: geometry.size.width * CGFloat(result.confidence), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.horizontal)
                        
                        // Detection details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.shapeDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.shapeDetected ? .green : .gray)
                                    .font(.caption)
                                Text("Pill shape detected")
                                    .font(.caption)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.colorProfile != "unknown" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.colorProfile != "unknown" ? .green : .gray)
                                    .font(.caption)
                                Text("Color: \(result.colorProfile.capitalized)")
                                    .font(.caption)
                                Spacer()
                            }
                            
                            Divider()
                            
                            // Text detection with multi-line support
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: !result.detectedText.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(!result.detectedText.isEmpty ? .green : .gray)
                                        .font(.caption)
                                    Text("Detected Text:")
                                        .font(.caption.bold())
                                    Spacer()
                                }
                                
                                if result.detectedText.isEmpty {
                                    Text("No text markings detected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                } else {
                                    ForEach(result.detectedText.prefix(5), id: \.self) { text in
                                        HStack(spacing: 4) {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(text)
                                                .font(.caption)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.leading, 20)
                                    }
                                    
                                    if result.detectedText.count > 5 {
                                        Text("+ \(result.detectedText.count - 5) more")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 24)
                                    }
                                }
                            }
                            
                            // Show matched medication terms if any
                            if !result.matchedTerms.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Matched Terms:")
                                            .font(.caption.bold())
                                            .foregroundColor(.green)
                                    }
                                    
                                    ForEach(result.matchedTerms.prefix(3), id: \.self) { term in
                                        Text("✓ \(term)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(.leading, 24)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(result.isMatch ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    
                    if result.isMatch {
                        Text("🎉 +\(medicationPoints) Points Earned!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    } else {
                        Text("You can still record if you're confident this is the right medication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            if !isAnalyzing {
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text(analysisResult?.isMatch == true ? "Continue - Record Dose ✓" : "Record Anyway")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(analysisResult?.isMatch == true ? Color.green : Color.orange)
                            .cornerRadius(12)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Retake Photo", action: onRetake)
                            .foregroundColor(.blue)
                        
                        Button("Cancel", action: onCancel)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            // Simulate processing time for AI analysis
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Medication Progress View

struct MedicationProgressView: View {
    @ObservedObject var medicationManager: MedicationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🏅 Recent Achievements")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(medicationManager.gameStats.achievements.filter { $0.isEarned }) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                    .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("📊 This Week")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        WeeklyProgressView()
                        
                        Text("Perfect week so far! 🎉")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.yellow, Color.orange]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(achievement.icon)
                        .font(.title3)
                )
            
            VStack(alignment: .leading) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct WeeklyProgressView: View {
    let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack {
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    if index < 6 {
                        Text("✓")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(index < 6 ? Color.green : Color.yellow)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}


// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
