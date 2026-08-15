import SwiftUI
import UIKit

// MARK: - Medication Manager

class MedicationManager: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var gameStats = GameStats()

    // Read-only: UserProfileStore owns profile state (in-memory cache +
    // Firestore persistence). MedicationManager never fetches, caches, or
    // writes profile data itself - views that need to edit the profile
    // observe UserProfileStore directly (see ProfileView).
    var userProfile: UserProfile { UserProfileStore.shared.profile }

    private let userDefaults = UserDefaults.standard
    private let medicationsKey = "savedMedications"

    init() { 
        loadMedications()
    }

    private func loadMedications() {
        guard let data = userDefaults.data(forKey: medicationsKey),
              let decoded = try? JSONDecoder().decode([Medication].self, from: data) else {
            medications = []
            return
        }
        medications = decoded
    }
    
    private func saveMedications() {
        guard let encoded = try? JSONEncoder().encode(medications) else { return }
        userDefaults.set(encoded, forKey: medicationsKey)
    }

    func add(_ medication: Medication) {
        medications.append(medication)
        saveMedications()
    }

    private func save(_ medication: Medication) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
        }
        saveMedications()
    }

    // Persists an edited medication (name, dosage, frequency, dose times)
    // and regenerates its upcoming schedule/notifications so the new times
    // take effect immediately - past/resolved DoseEntry records are left
    // untouched (see CalendarPersistenceManager.save(schedule:)).
    func update(_ medication: Medication) {
        save(medication)
        let schedule = MedicationScheduleParser.schedule(for: medication, dosage: medication.dosage)
        CalendarPersistenceManager.shared.save(schedule: schedule)
        NotificationScheduler.shared.schedule(for: schedule)
    }

    func startMissedDoseMonitoring() {
        CalendarPersistenceManager.shared.startMonitoring { [weak self] in self?.medications ?? [] }
    }

    func remove(_ medication: Medication) {
        if medications.count == 1 {
            NotificationScheduler.shared.cancelAll()
        } else {
            NotificationScheduler.shared.cancel(for: medication.id)
        }
        medications.removeAll { $0.id == medication.id }
        saveMedications()
    }

    func recordMedicationTaken(_ medication: Medication, points: Int) {
        guard let i = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        var med = medications[i]
        let isNewDay = med.lastTaken.map { !Calendar.current.isDateInToday($0) } ?? true
        if isNewDay { med.takenToday = 0; med.skippedToday = 0 }
        med.takenToday += 1
        med.lastTaken = Date()
        med.streak += 1
        medications[i] = med
        save(med)

        if med.resolvedTodayCount >= med.frequencyPerDay {
            NotificationScheduler.shared.cancelRemainingToday(for: medication.id)
        } else {
            NotificationScheduler.shared.cancelNext(for: medication.id)
        }

        gameStats.totalPoints += points
        gameStats.currentStreak = medications.allSatisfy { !$0.isOverdue } ? gameStats.currentStreak + 1 : 0
        gameStats.level = gameStats.calculatedLevel

        markTodaysDoseTaken(for: med)
    }

    // Marks the earliest still-`.upcoming` DoseEntry for today as `.taken`
    // so the Calendar and Progress views actually reflect a real Taken tap,
    // instead of the entry silently staying `.upcoming` (or later flipping
    // to `.missed`) despite the user having taken the dose.
    private func markTodaysDoseTaken(for medication: Medication) {
        let todaysUpcoming = CalendarPersistenceManager.shared.loadAll(forMedicationId: medication.id)
            .filter { Calendar.current.isDateInToday($0.scheduledDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first { if case .upcoming = $0.status { return true }; return false }
        guard let entry = todaysUpcoming else { return }
        CalendarPersistenceManager.shared.updateStatus(entryId: entry.id, medicationId: medication.id, status: .taken(Date()))
    }

    func recordMedicationSkipped(_ medication: Medication) {
        guard let i = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        var med = medications[i]
        let isNewDay = med.lastTaken.map { !Calendar.current.isDateInToday($0) } ?? true
        if isNewDay { med.takenToday = 0; med.skippedToday = 0 }
        med.skippedToday += 1
        med.lastTaken = Date()
        med.streak = 0
        medications[i] = med
        save(med)

        if med.resolvedTodayCount >= med.frequencyPerDay {
            NotificationScheduler.shared.cancelRemainingToday(for: medication.id)
        } else {
            NotificationScheduler.shared.cancelNext(for: medication.id)
        }

        gameStats.currentStreak = 0

        markTodaysDoseSkipped(for: med)
    }

    // Marks the earliest still-`.upcoming` DoseEntry for today as `.skipped`
    // so the Calendar view reflects the skip and the missed-dose checker
    // doesn't later flip it to `.missed` and fire a false caretaker alert.
    private func markTodaysDoseSkipped(for medication: Medication) {
        let todaysUpcoming = CalendarPersistenceManager.shared.loadAll(forMedicationId: medication.id)
            .filter { Calendar.current.isDateInToday($0.scheduledDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first { if case .upcoming = $0.status { return true }; return false }
        guard let entry = todaysUpcoming else { return }
        CalendarPersistenceManager.shared.updateStatus(entryId: entry.id, medicationId: medication.id, status: .skipped(Date()))
    }

    // Clears everything stored on-device. Firestore-backed data (doses,
    // sharedPeople, the profile doc) is deleted separately via
    // AuthenticationManager.deleteAccountAndAllData() - this only covers what
    // MedicationManager itself owns in UserDefaults.
    func deleteAllLocalData() {
        NotificationScheduler.shared.cancelAll()
        medications = []
        userDefaults.removeObject(forKey: medicationsKey)
        gameStats = GameStats()
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var gender: String = ""
    var age: String = ""
    var height: String = ""
    var weight: String = ""
    var allergies: [Allergy] = []
    var pharmacies: [Pharmacy] = []
    var settings: UserSettings = UserSettings()
    
    var displayName: String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Name" : fullName
    }
    
    var displayInfo: String {
        var parts: [String] = []
        if !gender.isEmpty { parts.append(gender) }
        if !age.isEmpty { parts.append(age) }
        return parts.isEmpty ? "Gender, Age" : parts.joined(separator: ", ")
    }
}

// MARK: - User Settings

struct UserSettings: Codable {
    var unitSystem: UnitSystem = .imperial
    var locationPermissionEnabled: Bool = false
    var countryOfResidence: String = "United States"
    var emailAddress: String = ""
    var faceIDEnabled: Bool = false

    enum UnitSystem: String, CaseIterable, Codable {
        case imperial = "Imperial"
        case metric = "Metric"
    }
}

// MARK: - Pharmacy

struct Pharmacy: Identifiable, Equatable, Codable {
    let id = UUID()
    var name: String
    var address: String
    var pharmacistName: String
    var phoneNumber: String
    var notes: String
}

// MARK: - Allergy
struct Allergy: Identifiable, Equatable, Codable {
    let id = UUID()
    var name: String
    var type: AllergyType
    var severity: AllergySeverity
    var symptoms: [String]
    var notes: String

    enum AllergyType: String, CaseIterable, Codable {
        case food = "Food"
        case drug = "Drug"
        
        var icon: String {
            switch self {
            case .food: return "fork.knife"
            case .drug: return "pills"
            }
        }
        
        var commonItems: [String] {
            switch self {
            case .food:
                return [
                    "Peanuts",
                    "Tree Nuts (Almonds, Walnuts, etc.)",
                    "Milk",
                    "Eggs",
                    "Wheat",
                    "Soy",
                    "Fish",
                    "Shellfish (Shrimp, Crab, Lobster)",
                    "Sesame",
                    "Corn",
                    "Gluten",
                    "Strawberries",
                    "Tomatoes",
                    "Chocolate",
                    "Other"
                ]
            case .drug:
                return [
                    "Penicillin",
                    "Amoxicillin",
                    "Aspirin",
                    "Ibuprofen",
                    "Naproxen",
                    "Sulfa Drugs",
                    "Codeine",
                    "Morphine",
                    "Insulin",
                    "Tetracycline",
                    "Cephalosporins",
                    "Contrast Dye",
                    "Latex",
                    "Anesthesia",
                    "Other"
                ]
            }
        }
    }
    
    enum AllergySeverity: String, CaseIterable, Codable {
        case mild = "Mild"
        case moderate = "Moderate"
        case severe = "Severe"
        
        var color: Color {
            switch self {
            case .mild: return .yellow
            case .moderate: return .orange
            case .severe: return .red
            }
        }
    }
    
    static let commonSymptoms = [
        "Hives",
        "Itching",
        "Rash",
        "Swelling",
        "Difficulty Breathing",
        "Wheezing",
        "Coughing",
        "Sneezing",
        "Runny Nose",
        "Watery Eyes",
        "Nausea",
        "Vomiting",
        "Diarrhea",
        "Stomach Pain",
        "Dizziness",
        "Anaphylaxis",
        "Chest Tightness",
        "Throat Closing",
        "Low Blood Pressure"
    ]
}


