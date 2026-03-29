import SwiftUI

// MARK: - Medication Manager

class MedicationManager: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var gameStats = GameStats()
    @Published var userProfile = UserProfile()

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

// MARK: - User Profile

struct UserProfile {
    var firstName: String = ""
    var lastName: String = ""
    var gender: String = ""
    var age: String = ""
    var height: String = ""
    var weight: String = ""
    var profileImageData: Data?
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

struct UserSettings {
    var unitSystem: UnitSystem = .imperial
    var locationPermissionEnabled: Bool = false
    var countryOfResidence: String = "United States"
    var emailAddress: String = ""
    var faceIDEnabled: Bool = false
    
    enum UnitSystem: String, CaseIterable {
        case imperial = "Imperial"
        case metric = "Metric"
    }
}

// MARK: - Pharmacy

struct Pharmacy: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var address: String
    var pharmacistName: String
    var phoneNumber: String
    var notes: String
}

// MARK: - Allergy
struct Allergy: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var type: AllergyType
    var severity: AllergySeverity
    var symptoms: [String]
    var notes: String
    
    enum AllergyType: String, CaseIterable {
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
    
    enum AllergySeverity: String, CaseIterable {
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


