import SwiftUI
import FirebaseFirestore
import UIKit

// MARK: - Medication Manager

class MedicationManager: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var gameStats = GameStats()
    @Published var userProfile = UserProfile()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var userId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "anonymous"
    }

    private var collection: CollectionReference {
        db.collection("users").document(userId).collection("medications")
    }

    init() { startListening() }

    deinit { listener?.remove() }

    private func startListening() {
        listener = collection.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let docs = snapshot?.documents else { return }
            DispatchQueue.main.async {
                self.medications = docs.compactMap { Self.decode($0.data()) }
                for med in self.medications {
                    CalendarPersistenceManager.shared.startListening(for: med.id)
                }
            }
        }
    }

    func add(_ medication: Medication) {
        medications.append(medication)
        save(medication)
    }

    private func save(_ medication: Medication) {
        guard let dict = Self.encode(medication) else { return }
        collection.document(medication.id.uuidString).setData(dict)
    }

    func remove(_ medication: Medication) {
        if medications.count == 1 {
            NotificationScheduler.shared.cancelAll()
        } else {
            NotificationScheduler.shared.cancel(for: medication.id)
        }
        medications.removeAll { $0.id == medication.id }
        collection.document(medication.id.uuidString).delete()
    }

    func recordMedicationTaken(_ medication: Medication, points: Int) {
        guard let i = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        var med = medications[i]
        let isNewDay = med.lastTaken.map { !Calendar.current.isDateInToday($0) } ?? true
        if isNewDay { med.takenToday = 0 }
        med.takenToday += 1
        med.lastTaken = Date()
        med.streak += 1
        medications[i] = med
        save(med)

        if med.takenToday >= med.frequencyPerDay {
            NotificationScheduler.shared.cancelRemainingToday(for: medication.id)
        } else {
            NotificationScheduler.shared.cancelNext(for: medication.id)
        }

        gameStats.totalPoints += points
        gameStats.currentStreak = medications.allSatisfy { !$0.isOverdue } ? gameStats.currentStreak + 1 : 0
        gameStats.level = gameStats.calculatedLevel
    }

    private static func encode(_ med: Medication) -> [String: Any]? { med.firestoreDict() }
    private static func decode(_ dict: [String: Any]) -> Medication? { Medication.decoded(from: dict) }
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


