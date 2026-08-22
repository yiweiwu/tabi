import SwiftUI

// MARK: - Medication Progress View

struct MedicationProgressView: View {
    @ObservedObject var medicationManager: MedicationStore

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

                        WeeklyProgressView(medicationManager: medicationManager)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

// MARK: - Achievement Row

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

// MARK: - Weekly Progress View

struct WeeklyProgressView: View {
    @ObservedObject var medicationManager: MedicationStore
    @ObservedObject private var calendarStore = CalendarPersistenceManager.shared
    private let cal = Calendar.current
    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    private var weekDays: [Date] {
        let today = cal.startOfDay(for: Date())
        let daysSinceMonday = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    // A day counts as "perfect" only if every medication active that day
    // has every one of its DoseEntry records for that day actually marked
    // `.taken` - never inferred just because the day has passed.
    private func isPerfectDay(_ day: Date) -> Bool {
        let entriesByMed = medicationManager.medications.map { med in
            calendarStore.loadAll(forMedicationId: med.id)
                .filter { cal.isDate($0.scheduledDate, inSameDayAs: day) }
        }
        let activeEntries = entriesByMed.filter { !$0.isEmpty }
        guard !activeEntries.isEmpty else { return false }
        return activeEntries.allSatisfy { entries in
            entries.allSatisfy { if case .taken = $0.status { return true }; return false }
        }
    }

    private var todayStart: Date { cal.startOfDay(for: Date()) }

    private var isPerfectWeekSoFar: Bool {
        weekDays.filter { $0 <= todayStart }.allSatisfy { isPerfectDay($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                    let isFuture = day > todayStart
                    let perfect = !isFuture && isPerfectDay(day)
                    VStack {
                        Text(dayLabels[index])
                            .font(.caption2)
                            .foregroundColor(.white)
                        if !isFuture {
                            Text(perfect ? "✓" : "–")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isFuture ? Color(UIColor.systemGray4) : (perfect ? Color.tabiGreen : Color.tabiRed))
                    .cornerRadius(8)
                }
            }

            if isPerfectWeekSoFar {
                Text("Perfect week so far! 🎉")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
    }
}
