import SwiftUI

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
