import Foundation

// MARK: - Medication Timeline Provider

// The Calendar tab's schedule view reads through this protocol rather than
// talking to `MockMedicationTimelineProvider` directly - swapping in a real
// backend later means writing one conforming type and changing the default
// passed into `CalendarView`, with no view code to touch.
protocol MedicationTimelineProviding {
    func fetchMedications() -> [ScheduledMedication]
}

struct MockMedicationTimelineProvider: MedicationTimelineProviding {
    func fetchMedications() -> [ScheduledMedication] {
        let everyDay = Set(Weekday.allCases)
        let weekdaysOnly: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let mwf: Set<Weekday> = [.monday, .wednesday, .friday]

        // Two distinct pharmacies, deliberately assigned so the two
        // low-supply medications (Omeprazole, Aspirin) land at different
        // ones - that's the case that actually needs the refill sheet to
        // group by pharmacy rather than assume a single shared one.
        let mainStreetPharmacy = MedicationPharmacy(name: "Main Street Pharmacy", address: "123 Main St, Your City", phone: "(555) 123-4567")
        let riverside = MedicationPharmacy(name: "Riverside Pharmacy", address: "456 Riverside Ave, Your City", phone: "(555) 987-6543")

        return [
            ScheduledMedication(name: "Metformin", dose: "500mg", timesOfDay: ["AM", "PM"],
                                 scheduleDays: everyDay, daysOfSupplyRemaining: 12, colorIndex: 0, pharmacy: mainStreetPharmacy),
            ScheduledMedication(name: "Lisinopril", dose: "10mg", timesOfDay: ["AM"],
                                 scheduleDays: everyDay, daysOfSupplyRemaining: 25, colorIndex: 1, pharmacy: mainStreetPharmacy),
            ScheduledMedication(name: "Atorvastatin", dose: "20mg", timesOfDay: ["PM"],
                                 scheduleDays: everyDay, daysOfSupplyRemaining: 18, colorIndex: 2, pharmacy: riverside),
            ScheduledMedication(name: "Vitamin D3", dose: "2000 IU", timesOfDay: ["AM"],
                                 scheduleDays: everyDay, daysOfSupplyRemaining: 40, colorIndex: 3, pharmacy: mainStreetPharmacy),
            ScheduledMedication(name: "Omeprazole", dose: "20mg", timesOfDay: ["AM"],
                                 scheduleDays: mwf, daysOfSupplyRemaining: 5, colorIndex: 4, pharmacy: riverside),
            ScheduledMedication(name: "Aspirin", dose: "81mg", timesOfDay: ["PM"],
                                 scheduleDays: weekdaysOnly, daysOfSupplyRemaining: 3, colorIndex: 0, pharmacy: mainStreetPharmacy)
        ]
    }
}
