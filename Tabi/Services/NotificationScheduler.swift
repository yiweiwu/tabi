import UserNotifications
import Foundation

// MARK: - Notification Scheduler

class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    func requestPermission() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in } }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancel(for medicationId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: self.pendingIds(reqs, for: medicationId))
        }
    }

    func cancelNext(for medicationId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let prefix = self.notificationPrefix(for: medicationId) + "."
            let now = Date().timeIntervalSince1970
            let nextId = reqs
                .compactMap { req -> (String, Double)? in
                    guard req.identifier.hasPrefix(prefix),
                          let ts = Double(req.identifier.dropFirst(prefix.count)),
                          ts > now else { return nil }
                    return (req.identifier, ts)
                }
                .min(by: { $0.1 < $1.1 })
                .map { $0.0 }
            guard let id = nextId else { return }
            center.removePendingNotificationRequests(withIdentifiers: [id])
        }
    }

    func cancelRemainingToday(for medicationId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let prefix = self.notificationPrefix(for: medicationId) + "."
            let cal = Calendar.current
            let todayIds = reqs
                .filter { req in
                    guard req.identifier.hasPrefix(prefix),
                          let ts = Double(req.identifier.dropFirst(prefix.count)) else { return false }
                    return cal.isDateInToday(Date(timeIntervalSince1970: ts))
                }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: todayIds)
        }
    }

    func schedule(for s: DoseSchedule) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: self.pendingIds(reqs, for: s.medicationId))
            let cal = Calendar.current
            var current = cal.startOfDay(for: s.startDate)
            let end = cal.startOfDay(for: s.endDate)
            var count = 0
            while current <= end && count < 60 {
                for t in s.scheduledTimes {
                    guard count < 60 else { break }
                    let comps = cal.dateComponents([.hour, .minute], from: t)
                    guard let date = cal.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: current), date > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "Time for \(s.medicationEmoji) \(s.medicationName)"
                    content.body = "\(s.dosage.isEmpty ? "Your dose" : s.dosage) — tap to log."
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
                    center.add(UNNotificationRequest(identifier: "\(self.notificationPrefix(for: s.medicationId)).\(date.timeIntervalSince1970)", content: content, trigger: trigger), withCompletionHandler: nil)
                    count += 1
                }
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
        }
    }

    private func notificationPrefix(for id: UUID) -> String { "tabi.\(id)" }

    private func pendingIds(_ reqs: [UNNotificationRequest], for medicationId: UUID) -> [String] {
        reqs.filter { $0.identifier.hasPrefix(notificationPrefix(for: medicationId)) }.map { $0.identifier }
    }
}
