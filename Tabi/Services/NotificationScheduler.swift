import UserNotifications
import Foundation

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
