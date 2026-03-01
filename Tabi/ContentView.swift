import SwiftUI
import AVFoundation
import Vision

// MARK: - Design System

extension Color {
    static let tabiOrange      = Color(red: 0.91, green: 0.53, blue: 0.29)
    static let tabiOrangeLight = Color(red: 0.99, green: 0.93, blue: 0.87)
    static let tabiLavender    = Color(red: 0.65, green: 0.60, blue: 0.82)
    static let tabiLavLight    = Color(red: 0.94, green: 0.93, blue: 0.97)
    static let tabiBlue        = Color(red: 0.24, green: 0.60, blue: 0.90)
    static let tabiGreen       = Color(red: 0.20, green: 0.72, blue: 0.40)
    static let tabiRed         = Color(red: 0.92, green: 0.25, blue: 0.25)
    static let tabiAmber       = Color(red: 0.96, green: 0.64, blue: 0.12)
    static let tabiGray        = Color(UIColor.secondaryLabel)
    static let tabiCardBG      = Color(UIColor.systemBackground)
    static let tabiGroupedBG   = Color(UIColor.systemGroupedBackground)
    static let tabiSeparator   = Color(UIColor.separator)
}

let medColors: [Color] = [
    Color(red: 0.22, green: 0.38, blue: 0.60),
    Color(red: 0.52, green: 0.38, blue: 0.72),
    Color(red: 0.20, green: 0.50, blue: 0.55),
    Color(red: 0.91, green: 0.53, blue: 0.29),
    Color(red: 0.85, green: 0.30, blue: 0.35),
]

// MARK: - Models

enum DoseStatus { case taken, pending, skipped, missed }

struct DoseTime: Identifiable {
    let id = UUID()
    let timeLabel: String
    var doses: [DoseEntry]
}

struct DoseEntry: Identifiable {
    let id = UUID()
    let medId: UUID
    let name: String
    let form: String
    let strength: String
    let frequency: String
    let colorIndex: Int
    var status: DoseStatus
    var emoji: String

    var color: Color { medColors[colorIndex % medColors.count] }
    var subtitle: String { "\(form) · \(strength)" }
}

struct Medication: Identifiable {
    let id = UUID()
    let name: String
    let form: String
    let strength: String
    let frequency: String
    let colorIndex: Int
    var emoji: String
    var refillCount: Int? = nil
    var refillByDate: String? = nil
}

struct GameStats {
    var streak: Int = 7
    var points: Int = 420
    var level: Int = 3
    var levelPoints: Int = 120
    var levelGoal: Int = 150
}

struct CaregiverProfile: Identifiable {
    let id = UUID()
    let name: String
    let lastSeen: String
    let alertCount: Int
    let changeCount: Int
    let avatar: String
}

struct WeekDay: Identifiable {
    let id: Int           // 0-6
    let letter: String
    let dayNumber: Int
    let date: Date
    let isToday: Bool
}

struct ColorDot: Identifiable {
    let id: Int
    let color: Color
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var medications: [Medication] = [
        Medication(name: "Amoxicillin", form: "Capsule", strength: "500 MG",
                   frequency: "3x Daily", colorIndex: 0, emoji: "💊"),
        Medication(name: "Vitamin D3", form: "Soft Chew", strength: "2000 IU",
                   frequency: "Every Day", colorIndex: 1, emoji: "🟡"),
        Medication(name: "Cequa", form: "Eye Drops", strength: "0.09%",
                   frequency: "Twice Daily", colorIndex: 2, emoji: "💧",
                   refillCount: 10, refillByDate: "Mar 20"),
        Medication(name: "Cyanocobalamin (Vitamin B12)", form: "Tablet", strength: "1000 MCG",
                   frequency: "Every Day", colorIndex: 3, emoji: "💊"),
    ]

    @Published var doseTimes: [DoseTime] = []
    @Published var gameStats = GameStats()
    @Published var caregivers: [CaregiverProfile] = [
        CaregiverProfile(name: "Dad", lastSeen: "9:23 AM", alertCount: 1,
                         changeCount: 3, avatar: "👨"),
        CaregiverProfile(name: "Mom", lastSeen: "9:36 AM", alertCount: 0,
                         changeCount: 2, avatar: "👩"),
    ]

    init() { buildSchedule() }

    func buildSchedule() {
        let a = medications[0]; let v = medications[1]
        let c = medications[2]; let b = medications[3]
        doseTimes = [
            DoseTime(timeLabel: "8:00 AM", doses: [
                entry(a, .taken), entry(v, .taken), entry(c, .taken)
            ]),
            DoseTime(timeLabel: "2:00 PM", doses: [
                entry(a, .pending)
            ]),
            DoseTime(timeLabel: "8:00 PM", doses: [
                entry(a, .pending), entry(b, .pending), entry(c, .pending)
            ]),
        ]
    }

    private func entry(_ m: Medication, _ s: DoseStatus) -> DoseEntry {
        DoseEntry(medId: m.id, name: m.name, form: m.form, strength: m.strength,
                  frequency: m.frequency, colorIndex: m.colorIndex, status: s, emoji: m.emoji)
    }

    func markDose(timeIdx: Int, doseIdx: Int, status: DoseStatus) {
        doseTimes[timeIdx].doses[doseIdx].status = status
        if status == .taken {
            gameStats.points += 10
            gameStats.levelPoints += 10
            if gameStats.levelPoints >= gameStats.levelGoal {
                gameStats.level += 1
                gameStats.levelPoints = 0
            }
        }
    }

    var upcomingRefills: [Medication] { medications.filter { $0.refillCount != nil } }
}

// MARK: - App Entry

@main
struct TABIApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var showScan = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView(appState: appState, showScan: $showScan).tag(0)
                SharingView(appState: appState).tag(1)
                Color.clear.tag(2)
                CalendarView(appState: appState).tag(3)
                ProfileView(appState: appState).tag(4)
            }
            .tint(.tabiOrange)
            TABITabBar(selectedTab: $selectedTab, showScan: $showScan)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showScan) {
            ScanView(appState: appState, isPresented: $showScan)
        }
        .onAppear { UITabBar.appearance().isHidden = true }
    }
}

// MARK: - Custom Tab Bar

struct TabItemData: Identifiable {
    let id: Int
    let label: String
    let icon: String
    let tag: Int
}

let tabItems: [TabItemData] = [
    TabItemData(id: 0, label: "Today",    icon: "checklist",     tag: 0),
    TabItemData(id: 1, label: "Sharing",  icon: "person.2",      tag: 1),
    TabItemData(id: 2, label: "Calendar", icon: "calendar",      tag: 3),
    TabItemData(id: 3, label: "Profile",  icon: "person.circle", tag: 4),
]

struct TABITabBar: View {
    @Binding var selectedTab: Int
    @Binding var showScan: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                TabButton(item: tabItems[0], selectedTab: $selectedTab)
                TabButton(item: tabItems[1], selectedTab: $selectedTab)
                Spacer().frame(width: 80)
                TabButton(item: tabItems[2], selectedTab: $selectedTab)
                TabButton(item: tabItems[3], selectedTab: $selectedTab)
            }
            .frame(height: 56)
            .background(
                Color.tabiCardBG
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -2)
            )
            .padding(.bottom, bottomPad())

            Button(action: { showScan = true }) {
                ZStack {
                    Circle()
                        .fill(Color.tabiOrange)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.tabiOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                    VStack(spacing: 2) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Scan")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .offset(y: -16)
        }
        .frame(maxWidth: .infinity)
    }

    private func bottomPad() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

struct TabButton: View {
    let item: TabItemData
    @Binding var selectedTab: Int

    var body: some View {
        let active = selectedTab == item.tag
        Button(action: { selectedTab = item.tag }) {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(active ? .tabiOrange : .tabiGray)
                Text(item.label)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .foregroundColor(active ? .tabiOrange : .tabiGray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Today View

struct TodayView: View {
    @ObservedObject var appState: AppState
    @Binding var showScan: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    GameHeader(stats: appState.gameStats)
                    VStack(spacing: 16) {
                        WeekStrip()
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        MedicationsCard(appState: appState)
                        addMedButton
                        DrugInteractionBanner()
                            .padding(.horizontal, 16)
                        if !appState.upcomingRefills.isEmpty {
                            RefillsSection(medications: appState.upcomingRefills)
                                .padding(.horizontal, 16)
                        }
                        Spacer().frame(height: 90)
                    }
                }
            }
            .background(Color.tabiGroupedBG)
            .navigationBarHidden(true)
        }
    }

    private var addMedButton: some View {
        Button(action: { showScan = true }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.tabiOrangeLight)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundColor(.tabiOrange)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add New Medication")
                        .font(.subheadline.bold())
                        .foregroundColor(.tabiOrange)
                    Text("Take a photo of your prescription label")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.tabiCardBG)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(Color.tabiOrange.opacity(0.5))
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Medications Card
// Extracted to its own view to avoid complex nested closures

struct MedicationsCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Medications").font(.headline.bold())
                Spacer()
                Button("Edit") {}.font(.subheadline).foregroundColor(.tabiOrange)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(appState.doseTimes) { slot in
                    TimeSlotSection(slot: slot, appState: appState)
                }
            }
            .background(Color.tabiCardBG)
            .cornerRadius(14)
            .padding(.horizontal, 16)
        }
    }
}

struct TimeSlotSection: View {
    let slot: DoseTime
    @ObservedObject var appState: AppState

    private var timeIdx: Int {
        appState.doseTimes.firstIndex(where: { $0.id == slot.id }) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(slot.timeLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.tabiGray)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, timeIdx == 0 ? 4 : 16)
            .padding(.bottom, 8)

            ForEach(slot.doses) { dose in
                DoseRowWrapper(dose: dose, slot: slot, appState: appState)
            }
        }
    }
}

struct DoseRowWrapper: View {
    let dose: DoseEntry
    let slot: DoseTime
    @ObservedObject var appState: AppState

    private var timeIdx: Int {
        appState.doseTimes.firstIndex(where: { $0.id == slot.id }) ?? 0
    }
    private var doseIdx: Int {
        slot.doses.firstIndex(where: { $0.id == dose.id }) ?? 0
    }
    private var isLast: Bool {
        slot.doses.last?.id == dose.id
    }

    var body: some View {
        VStack(spacing: 0) {
            DoseRow(
                dose: dose,
                onTake: { appState.markDose(timeIdx: timeIdx, doseIdx: doseIdx, status: .taken) },
                onSkip: { appState.markDose(timeIdx: timeIdx, doseIdx: doseIdx, status: .skipped) }
            )
            if !isLast {
                Divider().padding(.leading, 80)
            }
        }
    }
}

// MARK: - Game Header

struct GameHeader: View {
    let stats: GameStats

    private var progress: Double {
        Double(stats.levelPoints) / Double(stats.levelGoal)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TABI")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Text("PillQuest")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Text("\(stats.level)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.tabiOrange)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
                Spacer()
                levelRing
            }
            Text(todayString())
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            Text("Level up your health game!")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            xpBar
            HStack(spacing: 10) {
                StatChip(value: "\(stats.streak)", label: "days",  subtitle: "Streak")
                StatChip(value: "\(stats.points)", label: "total", subtitle: "Points")
                StatChip(value: "\(stats.level)",  label: "rank",  subtitle: "Level")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color.tabiOrange, Color(red: 0.85, green: 0.40, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    private var levelRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 48, height: 48)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))
            Text("Lv\(stats.level)")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white)
        }
    }

    private var xpBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Level \(stats.level) Progress")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("\(stats.levelPoints)/\(stats.levelGoal) pts to next level")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25)).frame(height: 6)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.bottom, 12)
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

struct StatChip: View {
    let value: String
    let label: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
            }
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.18))
        .cornerRadius(12)
    }
}

// MARK: - Week Strip

struct WeekStrip: View {
    private let cal = Calendar.current

    private var weekDays: [WeekDay] {
        let today = Date()
        let wd = cal.component(.weekday, from: today)
        let start = cal.date(byAdding: .day, value: -(wd - 1),
                             to: cal.startOfDay(for: today)) ?? today
        let letters = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        return (0..<7).compactMap { i -> WeekDay? in
            guard let date = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            return WeekDay(
                id: i,
                letter: letters[i],
                dayNumber: cal.component(.day, from: date),
                date: date,
                isToday: cal.isDateInToday(date)
            )
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays) { day in
                WeekDayCell(day: day)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.tabiCardBG)
        .cornerRadius(14)
    }
}

struct WeekDayCell: View {
    let day: WeekDay

    var body: some View {
        VStack(spacing: 5) {
            Text(day.letter)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(day.isToday ? .tabiOrange : .tabiGray)
            ZStack {
                Circle()
                    .fill(day.isToday ? Color.tabiOrange : Color.clear)
                    .frame(width: 30, height: 30)
                Text("\(day.dayNumber)")
                    .font(.system(size: 13, weight: day.isToday ? .bold : .regular))
                    .foregroundColor(day.isToday ? .white : .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Dose Row

struct DoseRow: View {
    let dose: DoseEntry
    let onTake: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(dose.color)
                .frame(width: 52, height: 52)
                .overlay(Text(dose.emoji).font(.title3))
            VStack(alignment: .leading, spacing: 3) {
                Text(dose.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Text(dose.subtitle)
                    .font(.caption)
                    .foregroundColor(.tabiGray)
                HStack(spacing: 3) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(dose.frequency)
                }
                .font(.caption)
                .foregroundColor(.tabiGray)
            }
            Spacer()
            DoseActionView(status: dose.status, onTake: onTake, onSkip: onSkip)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.tabiCardBG)
    }
}

struct DoseActionView: View {
    let status: DoseStatus
    let onTake: () -> Void
    let onSkip: () -> Void

    var body: some View {
        switch status {
        case .taken:
            Label("Taken", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundColor(.tabiGreen)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.tabiGreen.opacity(0.12))
                .cornerRadius(8)
        case .skipped:
            Label("Skipped", systemImage: "forward.circle.fill")
                .font(.caption.bold())
                .foregroundColor(.tabiAmber)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.tabiAmber.opacity(0.12))
                .cornerRadius(8)
        case .missed:
            Label("Missed", systemImage: "xmark.circle.fill")
                .font(.caption.bold())
                .foregroundColor(.tabiRed)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.tabiRed.opacity(0.12))
                .cornerRadius(8)
        case .pending:
            HStack(spacing: 6) {
                Button(action: onTake) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.caption2.bold())
                        Text("Take").font(.caption.bold())
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.tabiGreen.opacity(0.12))
                    .foregroundColor(.tabiGreen)
                    .cornerRadius(8)
                }
                Button(action: onSkip) {
                    Text("Skip").font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(.tabiGray)
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Drug Interaction Banner

struct DrugInteractionBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.tabiGreen.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.tabiGreen)
                        .font(.system(size: 18))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Drug Interactions").font(.subheadline.bold())
                Text("No interactions detected")
                    .font(.caption).foregroundColor(.tabiGray)
            }
            Spacer()
            Text("😊").font(.title2)
        }
        .padding(16)
        .background(Color.tabiCardBG)
        .cornerRadius(14)
    }
}

// MARK: - Refills Section

struct RefillsSection: View {
    let medications: [Medication]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming Refills").font(.headline.bold())
            VStack(spacing: 0) {
                ForEach(medications) { med in
                    RefillRow(med: med)
                }
            }
            .cornerRadius(14)
        }
    }
}

struct RefillRow: View {
    let med: Medication

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(medColors[med.colorIndex % medColors.count])
                .frame(width: 40, height: 40)
                .overlay(Text(med.emoji).font(.body))
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).font(.subheadline.bold())
                if let count = med.refillCount {
                    Text("\(count) pills left").font(.caption).foregroundColor(.tabiGray)
                }
            }
            Spacer()
            if let by = med.refillByDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Refill by").font(.caption).foregroundColor(.tabiGray)
                    Text(by).font(.caption.bold()).foregroundColor(.tabiRed)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.tabiCardBG)
    }
}

// MARK: - Scan View

struct ScanView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var step: ScanStep = .choose
    @State private var showPicker = false
    @State private var capturedImage: UIImage?
    @State private var detected: DetectedMed?
    @State private var mName = ""
    @State private var mForm = "Tablet"
    @State private var mStrength = ""
    @State private var mSchedule = "Every Day"

    enum ScanStep { case choose, camera, processing, confirm, manual }

    struct DetectedMed {
        var name: String; var form: String; var strength: String; var schedule: String
    }

    var body: some View {
        NavigationView {
            Group {
                switch step {
                case .choose:     chooseView
                case .camera:     cameraView
                case .processing: processingView
                case .confirm:    confirmView
                case .manual:     manualView
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.tabiOrange)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $capturedImage) {
                if let img = capturedImage { processImage(img) }
            }
        }
    }

    private var chooseView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.tabiOrangeLight).frame(height: 180)
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 72)).foregroundColor(.tabiOrange)
                }
                .padding(.horizontal, 20).padding(.top, 20)

                VStack(spacing: 12) {
                    ScanOptionButton(icon: "camera.fill", title: "Take Photo",
                                     subtitle: "Scan label with camera", filled: true) {
                        step = .camera
                    }
                    ScanOptionButton(icon: "photo.on.rectangle", title: "Choose from Library",
                                     subtitle: "Upload existing photo", filled: false) {
                        showPicker = true
                    }
                    ScanOptionButton(icon: "pencil", title: "Enter Manually",
                                     subtitle: "Type details yourself", filled: false) {
                        step = .manual
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.tabiGroupedBG)
    }

    private var cameraView: some View {
        CameraCapture { image in
            capturedImage = image
            processImage(image)
        }
    }

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView().scaleEffect(1.8).tint(.tabiOrange)
            VStack(spacing: 8) {
                Text("Reading Label").font(.title3.bold())
                Text("Parsing English & Chinese text…")
                    .font(.subheadline).foregroundColor(.tabiGray)
            }
            Spacer()
        }
    }

    private var confirmView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let img = capturedImage {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                }
                if let d = detected {
                    ConfirmCard(detected: d)
                        .padding(.horizontal, 20)
                }
                VStack(spacing: 10) {
                    Button(action: saveMedication) {
                        Label("Save Medication", systemImage: "checkmark")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.tabiOrange).cornerRadius(12)
                    }
                    Button(action: { step = .choose }) {
                        Text("Re-scan")
                            .font(.subheadline.bold()).foregroundColor(.tabiGray)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(UIColor.systemGray5)).cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                Spacer().frame(height: 24)
            }
        }
        .background(Color.tabiGroupedBG)
    }

    private var manualView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ManualInputField(label: "Medication Name",
                                     placeholder: "e.g., Amoxicillin", text: $mName)
                    ManualPickerField(label: "Form", selection: $mForm,
                                      options: ["Tablet","Capsule","Soft Chew","Eye Drops","Liquid","Patch"])
                    ManualInputField(label: "Strength",
                                     placeholder: "e.g., 500 MG", text: $mStrength)
                    ManualPickerField(label: "Schedule", selection: $mSchedule,
                                      options: ["Every Day","Twice Daily","3x Daily","4x Daily","As Needed"])
                }
                .padding(.horizontal, 20)

                Button(action: {
                    detected = DetectedMed(name: mName, form: mForm,
                                           strength: mStrength, schedule: mSchedule)
                    step = .confirm
                }) {
                    Text("Review & Save")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(mName.isEmpty ? Color.tabiGray : Color.tabiOrange)
                        .cornerRadius(12)
                }
                .disabled(mName.isEmpty)
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
        }
        .background(Color.tabiGroupedBG)
    }

    private var stepTitle: String {
        switch step {
        case .choose:     return "Add Medication"
        case .camera:     return "Scan Label"
        case .processing: return "Scanning…"
        case .confirm:    return "Confirm Medication"
        case .manual:     return "Enter Manually"
        }
    }

    private func processImage(_ image: UIImage) {
        step = .processing
        guard let cg = image.cgImage else { step = .choose; return }
        let req = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                .compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async {
                self.detected = self.parseLabel(lines.joined(separator: "\n"))
                self.step = .confirm
            }
        }
        req.recognitionLanguages = ["en-US", "zh-Hant"]
        req.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
    }

    private func parseLabel(_ text: String) -> DetectedMed {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let dosePat = /\d+(\.\d+)?\s*(mg|mcg|mL|IU|%|units?)/
        let schedPat = /(once|twice|three times|3x|4x|daily|every|as needed)/
        var name = lines.first ?? "Unknown"
        var strength = "See label"
        var schedule = "As directed"
        for line in lines {
            if let m = line.firstMatch(of: dosePat) { strength = String(m.0) }
            if let _ = line.firstMatch(of: schedPat) { schedule = line }
        }
        if let better = lines.first(where: { $0.count > 3 && $0.first?.isLetter == true }) {
            name = better
        }
        return DetectedMed(name: name, form: inferForm(text),
                           strength: strength, schedule: schedule)
    }

    private func inferForm(_ text: String) -> String {
        let t = text.lowercased()
        if t.contains("eye drop") || t.contains("ophthalmic") { return "Eye Drops" }
        if t.contains("capsule") { return "Capsule" }
        if t.contains("chew") || t.contains("gummy") { return "Soft Chew" }
        if t.contains("liquid") || t.contains("syrup") { return "Liquid" }
        return "Tablet"
    }

    private func saveMedication() {
        guard let d = detected else { return }
        let idx = appState.medications.count
        appState.medications.append(Medication(
            name: d.name, form: d.form, strength: d.strength,
            frequency: d.schedule, colorIndex: idx, emoji: "💊"
        ))
        appState.buildSchedule()
        isPresented = false
    }
}

// MARK: - Scan sub-views

struct ScanOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(filled ? Color.white.opacity(0.2) : Color.tabiOrange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(filled ? .white : .tabiOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(filled ? .white : .tabiOrange)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(filled ? .white.opacity(0.75) : .tabiGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(filled ? .white.opacity(0.6) : .tabiGray)
            }
            .padding(16)
            .background(
                filled
                ? AnyView(LinearGradient(
                    colors: [Color.tabiOrange, Color.tabiOrange.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing))
                : AnyView(Color.tabiCardBG)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(filled ? Color.clear : Color.tabiOrange.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
}

struct ConfirmCard: View {
    let detected: ScanView.DetectedMed

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("RECOGNIZED INFORMATION", systemImage: "checkmark.circle.fill")
                .font(.caption.bold()).foregroundColor(.tabiGreen)
            VStack(spacing: 0) {
                ConfirmRow(label: "💊 Medication", value: detected.name)
                Divider()
                ConfirmRow(label: "📐 Form",       value: detected.form)
                Divider()
                ConfirmRow(label: "📊 Strength",   value: detected.strength)
                Divider()
                ConfirmRow(label: "⏰ Schedule",   value: detected.schedule)
            }
            .background(Color.tabiCardBG)
            .cornerRadius(12)
        }
    }
}

struct ConfirmRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.tabiGray)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct ManualInputField: View {
    let label: String; let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.tabiGray)
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color.tabiCardBG)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.tabiSeparator, lineWidth: 0.5))
        }
    }
}

struct ManualPickerField: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.tabiGray)
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.tabiCardBG)
            .cornerRadius(10)
        }
    }
}

// MARK: - Camera Capture

struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    func makeUIViewController(context: Context) -> CameraVC { CameraVC(onCapture: onCapture) }
    func updateUIViewController(_ uiViewController: CameraVC, context: Context) {}
}

class CameraVC: UIViewController {
    let onCapture: (UIImage) -> Void
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput = AVCapturePhotoOutput()
    var photoDelegate: PhotoDelegate?

    init(onCapture: @escaping (UIImage) -> Void) {
        self.onCapture = onCapture
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        addControls()
    }

    func setupCamera() {
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func addControls() {
        let guide = UIView()
        guide.translatesAutoresizingMaskIntoConstraints = false
        guide.layer.borderColor = UIColor(Color.tabiOrange).cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 12
        view.addSubview(guide)

        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = UIColor(Color.tabiOrange)
        btn.tintColor = .white
        let cfg = UIImage.SymbolConfiguration(pointSize: 32)
        btn.setImage(UIImage(systemName: "camera.circle.fill", withConfiguration: cfg), for: .normal)
        btn.layer.cornerRadius = 36
        btn.addTarget(self, action: #selector(capture), for: .touchUpInside)
        view.addSubview(btn)

        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guide.widthAnchor.constraint(equalToConstant: 280),
            guide.heightAnchor.constraint(equalToConstant: 160),
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            btn.widthAnchor.constraint(equalToConstant: 72),
            btn.heightAnchor.constraint(equalToConstant: 72),
        ])
    }

    @objc func capture() {
        photoDelegate = PhotoDelegate(onCapture: onCapture)
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: photoDelegate!)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
}

class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let onCapture: (UIImage) -> Void
    init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.onCapture(img) }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onSelected: () -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { self.parent.onSelected() }
        }
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var appState: AppState
    @StateObject private var vm = CalendarVM()
    private let cal = Calendar.current
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $vm.mode) {
                    ForEach(CalendarVM.Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 12)

                HStack(spacing: 10) {
                    Button { vm.shift(-1) } label: {
                        Image(systemName: "chevron.left").foregroundColor(.primary)
                    }
                    Menu {
                        ForEach(vm.monthItems) { item in
                            Button(item.name) { vm.setMonth(item.number) }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(vm.monthLabel).font(.subheadline.bold())
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray6)).cornerRadius(8)
                    }.foregroundColor(.primary)

                    Menu {
                        ForEach(vm.yearItems) { item in
                            Button("\(item.number)") { vm.setYear(item.number) }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(vm.yearLabel).font(.subheadline.bold())
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(UIColor.systemGray6)).cornerRadius(8)
                    }.foregroundColor(.primary)

                    Spacer()
                    Button { vm.shift(1) } label: {
                        Image(systemName: "chevron.right").foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                calendarGrid
                filterList(medications: appState.medications)
            }
            .background(Color.tabiGroupedBG)
            .navigationTitle("Calendar")
        }
    }

    private var calendarGrid: some View {
        let days = vm.calDays()
        let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { d in
                    Text(d).font(.caption2).foregroundColor(.tabiGray).frame(maxWidth: .infinity)
                }
            }.padding(.vertical, 8)

            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(days) { cell in
                    CalDayCell(cell: cell,
                               isSelected: vm.selected.map { cal.isDate($0, inSameDayAs: cell.date) } ?? false,
                               dotColors: dotColors(for: cell)) {
                        if !cell.isEmpty { vm.selected = cell.date }
                    }
                }
            }
            .padding(.horizontal, 4).padding(.bottom, 12)
        }
        .background(Color.tabiCardBG)
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.04), radius: 6)
    }

    private func filterList(medications: [Medication]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Filter by Medication")
                    .font(.caption).foregroundColor(.tabiGray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
                VStack(spacing: 0) {
                    ForEach(medications) { med in
                        CalFilterRow(name: med.name)
                        Divider().padding(.leading, 60)
                    }
                    CalFilterRow(name: "Refills")
                }
                .background(Color.tabiCardBG).cornerRadius(14)
                .padding(.horizontal, 16).padding(.bottom, 90)
            }
        }
    }

    private func dotColors(for cell: CalDay) -> [Color] {
        guard !cell.isEmpty else { return [] }
        if cal.isDateInToday(cell.date) { return [.tabiOrange, .tabiBlue] }
        if cell.date < Date()           { return [.tabiGreen] }
        return []
    }
}

// CalDay: Identifiable cell so ForEach needs no id parameter
struct CalDay: Identifiable {
    let id: Int
    let date: Date
    let isEmpty: Bool
    let dayNumber: Int
    let isToday: Bool
}

class CalendarVM: ObservableObject {
    @Published var displayedMonth = Date()
    @Published var selected: Date? = nil
    @Published var mode: Mode = .month

    enum Mode: String, CaseIterable { case week = "Week", month = "Month", year = "Year" }

    struct MonthItem: Identifiable { let id: Int; let number: Int; let name: String }
    struct YearItem:  Identifiable { let id: Int; let number: Int }

    var monthLabel: String { let f = DateFormatter(); f.dateFormat = "MMM";  return f.string(from: displayedMonth) }
    var yearLabel:  String { let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: displayedMonth) }

    var monthItems: [MonthItem] {
        let symbols = DateFormatter().monthSymbols ?? []
        return symbols.enumerated().map { MonthItem(id: $0.offset, number: $0.offset + 1, name: $0.element) }
    }
    var yearItems: [YearItem] {
        (2022...2028).map { YearItem(id: $0, number: $0) }
    }

    func shift(_ v: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: v, to: displayedMonth) ?? displayedMonth
    }
    func setMonth(_ m: Int) {
        var c = Calendar.current.dateComponents([.year, .month], from: displayedMonth); c.month = m
        if let d = Calendar.current.date(from: c) { displayedMonth = d }
    }
    func setYear(_ y: Int) {
        var c = Calendar.current.dateComponents([.year, .month], from: displayedMonth); c.year = y
        if let d = Calendar.current.date(from: c) { displayedMonth = d }
    }

    func calDays() -> [CalDay] {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let first = cal.date(from: c), let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let padCount = cal.component(.weekday, from: first) - 1
        let emptyDay = cal.date(byAdding: .day, value: -1, to: first) ?? first
        var result: [CalDay] = (0..<padCount).map { i in
            CalDay(id: -(i+1), date: emptyDay, isEmpty: true, dayNumber: 0, isToday: false)
        }
        let realDays: [CalDay] = range.compactMap { n -> CalDay? in
            guard let date = cal.date(byAdding: .day, value: n - 1, to: first) else { return nil }
            return CalDay(id: n, date: date, isEmpty: false,
                          dayNumber: n, isToday: cal.isDateInToday(date))
        }
        result.append(contentsOf: realDays)
        return result
    }
}

struct CalDayCell: View {
    let cell: CalDay
    let isSelected: Bool
    let dotColors: [Color]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if cell.isEmpty {
                    Color.clear.frame(width: 30, height: 30)
                } else {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary).frame(width: 30, height: 30)
                        } else if cell.isToday {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.tabiOrange, lineWidth: 1.5).frame(width: 30, height: 30)
                        }
                        Text("\(cell.dayNumber)")
                            .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                            .foregroundColor(
                                isSelected ? Color(UIColor.systemBackground)
                                : cell.isToday ? .tabiOrange : .primary
                            )
                    }
                }
                HStack(spacing: 2) {
                    ForEach(dotColors.prefix(3).enumerated().map { ColorDot(id: $0.offset, color: $0.element) }) { dot in
                        Circle().fill(dot.color).frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 44).frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct CalFilterRow: View {
    let name: String
    @State private var on = true
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.tabiLavLight).frame(width: 30, height: 30)
                .overlay(Image(systemName: "person.circle")
                    .font(.caption).foregroundColor(.tabiLavender))
            Text(name).font(.subheadline).lineLimit(1)
            Spacer()
            Toggle("", isOn: $on).labelsHidden().tint(.tabiOrange)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.tabiCardBG)
    }
}

// MARK: - Sharing View

struct SharingView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        ForEach(appState.caregivers) { cg in
                            CaregiverRow(cg: cg, isLast: cg.id == appState.caregivers.last?.id)
                        }
                    }
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    Button(action: {}) {
                        HStack(spacing: 12) {
                            Circle().fill(Color.tabiOrangeLight).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "plus").foregroundColor(.tabiOrange))
                            Text("Add Care Team Member")
                                .font(.subheadline.bold()).foregroundColor(.tabiOrange)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.tabiCardBG).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(Color.tabiOrange.opacity(0.5)))
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "doc.fill").font(.caption).foregroundColor(.tabiLavender))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export PDF Report").font(.subheadline.bold())
                            Text("Share your medication history").font(.caption).foregroundColor(.tabiGray)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up").foregroundColor(.tabiGray)
                    }
                    .padding(16)
                    .background(Color.tabiCardBG).cornerRadius(14)
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }
            .background(Color.tabiGroupedBG)
            .navigationTitle("Sharing")
        }
    }
}

struct CaregiverRow: View {
    let cg: CaregiverProfile
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.tabiLavender.opacity(0.6), Color.tabiBlue.opacity(0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Text(cg.avatar).font(.title2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(cg.name).font(.subheadline.bold())
                    if cg.alertCount > 0 {
                        Label("\(cg.alertCount) Alert", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundColor(.tabiAmber)
                    }
                    Label("\(cg.changeCount) Changes", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption).foregroundColor(.tabiGray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(cg.lastSeen).font(.caption).foregroundColor(.tabiGray)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.tabiCardBG)

            if !isLast {
                Divider().padding(.leading, 86)
            }
        }
    }
}

// MARK: - Profile View

struct ProfileMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct ProfileView: View {
    @ObservedObject var appState: AppState

    private let menuItems: [ProfileMenuItem] = [
        ProfileMenuItem(icon: "heart.text.square",   title: "Drug Interactions/Safety", subtitle: "Safety and Allergies"),
        ProfileMenuItem(icon: "cross.case.fill",      title: "My Pharmacies",           subtitle: ""),
        ProfileMenuItem(icon: "gearshape.fill",       title: "Settings",                subtitle: ""),
        ProfileMenuItem(icon: "questionmark.circle",  title: "Help & FAQ",              subtitle: ""),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    avatarRow
                    statsRow
                    menuCard
                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }
            .background(Color.tabiGroupedBG)
            .navigationTitle("Profile")
        }
    }

    private var avatarRow: some View {
        HStack(spacing: 16) {
            Circle().fill(Color.tabiLavLight).frame(width: 72, height: 72)
                .overlay(Image(systemName: "person.fill").font(.title).foregroundColor(.tabiLavender))
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.title2.bold())
                Text("Gender · Age").font(.subheadline).foregroundColor(.tabiGray)
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "pencil.circle.fill").font(.title2).foregroundColor(.tabiOrange)
            }
        }
        .padding(.horizontal, 16)
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.tabiLavLight).frame(width: 120, height: 120)
                VStack(spacing: 2) {
                    Text("\(appState.medications.count)").font(.system(size: 38, weight: .black))
                    Text("Active Meds").font(.caption).foregroundColor(.tabiGray)
                }
            }
            ZStack {
                Circle()
                    .stroke(Color.tabiLavender.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: 0.97)
                    .stroke(Color.tabiLavender, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("97%").font(.system(size: 28, weight: .black))
                    Text("Adherence").font(.caption).foregroundColor(.tabiGray)
                }
            }
        }
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            ForEach(menuItems) { item in
                ProfileMenuRow(item: item, isLast: item.id == menuItems.last?.id)
            }
        }
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }
}

struct ProfileMenuRow: View {
    let item: ProfileMenuItem
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Circle().fill(Color.tabiLavLight).frame(width: 38, height: 38)
                    .overlay(Image(systemName: item.icon).font(.caption).foregroundColor(.tabiLavender))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.subheadline.bold())
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle).font(.caption).foregroundColor(.tabiGray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.tabiCardBG)

            if !isLast {
                Divider().padding(.leading, 68)
            }
        }
    }
}

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}
