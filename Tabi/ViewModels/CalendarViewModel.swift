import SwiftUI

// MARK: - Calendar View Model

class CalendarViewModel: ObservableObject {
    @Published var displayedMonth: Date = Date()
    @Published var selectedDate: Date?
    @Published var entriesForMonth: [DoseEntry] = []
    @Published var entriesForSelectedDay: [DoseEntry] = []
    @Published var showDaySheet = false
    @Published var viewMode: ViewMode = .month
    enum ViewMode: String, CaseIterable { case week = "Week", month = "Month", year = "Year" }
    private let p = CalendarStore.shared

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
}
