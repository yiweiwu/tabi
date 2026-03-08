import SwiftUI

// MARK: - Core Medication Models

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
