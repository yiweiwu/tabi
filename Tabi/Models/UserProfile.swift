import SwiftUI

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

    init() {}

    // Custom instead of relying on synthesis: synthesized Decodable has no
    // fallback to a property's declared default when a key is missing - it
    // fails the whole decode instead. That would mean any `users/{uid}`
    // Firestore doc written before a field existed (e.g. before `settings`
    // was added) permanently fails to decode on every future fetch,
    // silently leaving the profile at UserProfile() - indistinguishable
    // from "never loaded". decodeIfPresent + `?? default` here lets an
    // older doc keep loading as fields get added later.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? ""
        age = try container.decodeIfPresent(String.self, forKey: .age) ?? ""
        height = try container.decodeIfPresent(String.self, forKey: .height) ?? ""
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        allergies = try container.decodeIfPresent([Allergy].self, forKey: .allergies) ?? []
        pharmacies = try container.decodeIfPresent([Pharmacy].self, forKey: .pharmacies) ?? []
        settings = try container.decodeIfPresent(UserSettings.self, forKey: .settings) ?? UserSettings()
    }

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

    init() {}

    // Same reasoning as UserProfile.init(from:) above - this is nested
    // inside a UserProfile document, so it's exposed to the same "doc
    // predates a field" decode failure.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unitSystem = try container.decodeIfPresent(UnitSystem.self, forKey: .unitSystem) ?? .imperial
        locationPermissionEnabled = try container.decodeIfPresent(Bool.self, forKey: .locationPermissionEnabled) ?? false
        countryOfResidence = try container.decodeIfPresent(String.self, forKey: .countryOfResidence) ?? "United States"
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress) ?? ""
        faceIDEnabled = try container.decodeIfPresent(Bool.self, forKey: .faceIDEnabled) ?? false
    }

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
