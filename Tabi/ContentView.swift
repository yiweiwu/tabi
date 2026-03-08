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

// MARK: - Detected Medication View

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

// MARK: - Camera Manager (Singleton)

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var isSetup = false
    private var photoOutput: AVCapturePhotoOutput?
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    private override init() {
        super.init()
        let s = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async { self.isAuthorized = (s == .authorized) }
    }
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    DispatchQueue.main.async { self.isAuthorized = true }
        case .notDetermined: requestPermission()
        default:             DispatchQueue.main.async { self.isAuthorized = false }
        }
    }
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in DispatchQueue.main.async { self.isAuthorized = granted } }
    }
    func startSession() {
        guard isAuthorized else { return }
        if !isSetup { setupSession { self.startSession() }; return }
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning(); Thread.sleep(forTimeInterval: 0.2) }
            self.session.startRunning()
            let r = self.session.isRunning
            DispatchQueue.main.async { self.isSessionRunning = r }
        }
    }
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning(); Thread.sleep(forTimeInterval: 0.2) }
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }
    func setupSession(completion: (() -> Void)? = nil) {
        if isSetup { DispatchQueue.main.async { completion?() }; return }
        guard isAuthorized else { return }
        sessionQueue.async {
            for i in self.session.inputs { self.session.removeInput(i) }
            for o in self.session.outputs { self.session.removeOutput(o) }
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.photo) { self.session.sessionPreset = .photo }
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else { self.session.commitConfiguration(); return }
            self.session.addInput(input)
            let output = AVCapturePhotoOutput()
            if self.session.canAddOutput(output) { self.session.addOutput(output); output.isHighResolutionCaptureEnabled = true; self.photoOutput = output }
            self.session.commitConfiguration()
            DispatchQueue.main.async { self.isSetup = true; completion?() }
        }
    }
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput, session.isRunning else { completion(nil); return }
        let s = AVCapturePhotoSettings(); s.isHighResolutionPhotoEnabled = true
        currentPhotoDelegate = PhotoCaptureDelegate(completion: completion)
        photoOutput.capturePhoto(with: s, delegate: currentPhotoDelegate!)
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero); v.backgroundColor = .black
        let l = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        l.videoGravity = .resizeAspectFill; l.connection?.videoOrientation = .portrait; v.layer.addSublayer(l)
        context.coordinator.previewLayer = l; return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let l = context.coordinator.previewLayer {
            DispatchQueue.main.async { CATransaction.begin(); CATransaction.setDisableActions(true); l.frame = uiView.bounds; CATransaction.commit() }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var previewLayer: AVCaptureVideoPreviewLayer? }
}

// MARK: - Photo Capture Delegate

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void
    init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { completion(nil); return }
        completion(image)
    }
}

// MARK: - Medication Analyzer

class MedicationAnalyzer {
    static let shared = MedicationAnalyzer()

    struct AnalysisResult {
        let isMatch: Bool; let confidence: Double; let detectedText: [String]
        let colorProfile: String; let shapeDetected: Bool
        let validMedicationDetected: Bool; let matchedTerms: [String]
    }

    func detectMedicationFromLabel(image: UIImage, completion: @escaping (DetectedMedicationInfo) -> Void) {
        guard let cg = image.cgImage else {
            completion(DetectedMedicationInfo(medicationName: "Unknown Medication", schedule: "Daily", dosage: "", scheduleTime: Date(), allDetectedText: []))
            return
        }
        recognizeText(in: cg) { texts in completion(self.extractInfo(from: texts)) }
    }

    func analyzePill(image: UIImage, expectedMedication: Medication, completion: @escaping (AnalysisResult) -> Void) {
        guard let cg = image.cgImage else {
            completion(AnalysisResult(isMatch: false, confidence: 0, detectedText: [], colorProfile: "unknown", shapeDetected: false, validMedicationDetected: false, matchedTerms: []))
            return
        }
        var texts: [String] = []; var hasShape = false
        let g = DispatchGroup()
        g.enter(); recognizeText(in: cg) { t in texts = t; g.leave() }
        g.enter(); detectShape(in: cg) { s in hasShape = s; g.leave() }
        g.notify(queue: .main) {
            let color = self.analyzeColor(image: image)
            let v = self.validateText(texts: texts, med: expectedMedication)
            let conf = self.calcConf(match: v.isMatch, shape: hasShape, color: color, terms: v.hasTerms)
            completion(AnalysisResult(isMatch: conf > 0.5, confidence: conf, detectedText: texts, colorProfile: color, shapeDetected: hasShape, validMedicationDetected: v.hasTerms, matchedTerms: v.matched))
        }
    }

    private func extractInfo(from texts: [String]) -> DetectedMedicationInfo {
        let kws = ["hydrocodone","acetaminophen","doxycycline","vitamin","ibuprofen","amoxicillin","cequa","cyanocobalamin","metformin","atorvastatin","omeprazole"]
        let dosePat = /(\d+[-\s]?\d*\s*(MG|MCG|mg|mcg))/
        let schedKws = ["daily","twice","once","every","morning","evening","night","take"]
        var name = "Unknown Medication"; var sched = "Take as directed"; var dosage = ""; var st = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        var di: Int?
        for (i, t) in texts.enumerated() { if let m = t.firstMatch(of: dosePat) { dosage = String(m.0); di = i; break } }
        if let di {
            outer: for i in stride(from: max(0, di-3), to: di, by: 1).reversed() {
                for kw in kws { if texts[i].lowercased().contains(kw) { name = texts[i].trimmingCharacters(in: .whitespacesAndNewlines); break outer } }
            }
        }
        if name == "Unknown Medication" {
            outer: for (i, t) in texts.enumerated() where i < 5 {
                for kw in kws { if t.lowercased().contains(kw) { name = t.trimmingCharacters(in: .whitespacesAndNewlines); break outer } }
            }
        }
        for t in texts { let lo = t.lowercased(); for kw in schedKws where lo.contains(kw) { sched = t; if lo.contains("evening") || lo.contains("night") { st = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date() }; break } }
        return DetectedMedicationInfo(medicationName: name, schedule: sched, dosage: dosage, scheduleTime: st, allDetectedText: texts)
    }

    private func validateText(texts: [String], med: Medication) -> (isMatch: Bool, hasTerms: Bool, matched: [String]) {
        let kws = ["mg","mcg","tablet","capsule","pill","dose","vitamin","daily","twice"]
        let all = texts.joined(separator: " ").lowercased()
        let mw = med.name.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
        let isMatch = mw.contains { all.contains($0) }
        var hasTerms = false; var matched: [String] = []
        for t in texts { let lo = t.lowercased(); if mw.contains(where: { lo.contains($0) }) || kws.contains(where: { lo.contains($0) }) { hasTerms = true; matched.append(t) } }
        return (isMatch, hasTerms, Array(matched.prefix(3)))
    }

    private func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let req = VNRecognizeTextRequest { req, err in
            guard err == nil, let obs = req.results as? [VNRecognizedTextObservation] else { completion([]); return }
            let t = obs.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }.compactMap { $0.topCandidates(1).first?.string }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            completion(Array(Set(t)))
        }
        req.recognitionLevel = .accurate; req.usesLanguageCorrection = true; req.recognitionLanguages = ["en-US"]
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([req])
    }

    private func detectShape(in image: CGImage, completion: @escaping (Bool) -> Void) {
        let req = VNDetectContoursRequest { req, err in completion(err == nil && !(req.results as? [VNContoursObservation] ?? []).isEmpty) }
        req.contrastAdjustment = 1.5; try? VNImageRequestHandler(cgImage: image, options: [:]).perform([req])
    }

    private func analyzeColor(image: UIImage) -> String {
        guard let cg = image.cgImage else { return "unknown" }
        let ci = CIImage(cgImage: cg)
        let ext = CIVector(x: ci.extent.origin.x, y: ci.extent.origin.y, z: ci.extent.size.width, w: ci.extent.size.height)
        guard let f = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: ext]), let out = f.outputImage else { return "unknown" }
        var bm = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: kCFNull as Any]).render(out, toBitmap: &bm, rowBytes: 4, bounds: CGRect(x:0,y:0,width:1,height:1), format: .RGBA8, colorSpace: nil)
        let r = bm[0]; let g = bm[1]; let b = bm[2]
        if r>200&&g>200&&b>200 { return "white" }; if r>150&&g<100&&b<100 { return "red" }
        if r<100&&g<100&&b>150 { return "blue" }; return "other"
    }

    private func calcConf(match: Bool, shape: Bool, color: String, terms: Bool) -> Double {
        var c = 0.2; if match { c += 0.5 } else if terms { c += 0.2 }; if shape { c += 0.2 }; if color != "unknown" { c += 0.1 }; return min(c, 1.0)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
