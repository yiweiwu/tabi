import SwiftUI
import PhotosUI
import MapKit

// MARK: - User Profile Model

class UserProfile: ObservableObject {
    @Published var firstName: String {
        didSet { UserDefaults.standard.set(firstName, forKey: "profile.firstName") }
    }
    @Published var lastName: String {
        didSet { UserDefaults.standard.set(lastName, forKey: "profile.lastName") }
    }
    @Published var gender: Gender {
        didSet { UserDefaults.standard.set(gender.rawValue, forKey: "profile.gender") }
    }
    @Published var ageRange: AgeRange {
        didSet { UserDefaults.standard.set(ageRange.rawValue, forKey: "profile.ageRange") }
    }
    @Published var ethnicity: Ethnicity {
        didSet { UserDefaults.standard.set(ethnicity.rawValue, forKey: "profile.ethnicity") }
    }
    @Published var profileImageData: Data? {
        didSet { UserDefaults.standard.set(profileImageData, forKey: "profile.imageData") }
    }

    enum Gender: String, CaseIterable, Identifiable {
        case notSpecified = "Prefer not to say"
        case male         = "Male"
        case female       = "Female"
        case nonBinary    = "Non-binary"
        case other        = "Other"
        var id: String { rawValue }
    }

    enum AgeRange: String, CaseIterable, Identifiable {
        case notSpecified = "Prefer not to say"
        case under18      = "Under 18"
        case age18to24    = "18 – 24"
        case age25to34    = "25 – 34"
        case age35to44    = "35 – 44"
        case age45to54    = "45 – 54"
        case age55to64    = "55 – 64"
        case age65to74    = "65 – 74"
        case age75plus    = "75 and older"
        var id: String { rawValue }
    }

    enum Ethnicity: String, CaseIterable, Identifiable {
        case notSpecified              = "Prefer not to say"
        case americanIndian            = "American Indian or Alaska Native"
        case asian                     = "Asian"
        case blackOrAfricanAmerican    = "Black or African American"
        case hispanicOrLatino          = "Hispanic or Latino"
        case nativeHawaiian            = "Native Hawaiian or Pacific Islander"
        case whiteOrCaucasian          = "White or Caucasian"
        case middleEasternNorthAfrican = "Middle Eastern or North African"
        case multiracial               = "Multiracial or Mixed"
        case other                     = "Other"
        var id: String { rawValue }
    }

    init() {
        self.firstName    = UserDefaults.standard.string(forKey: "profile.firstName") ?? ""
        self.lastName     = UserDefaults.standard.string(forKey: "profile.lastName")  ?? ""
        let rawGender     = UserDefaults.standard.string(forKey: "profile.gender") ?? ""
        self.gender       = Gender(rawValue: rawGender) ?? .notSpecified
        let rawAgeRange   = UserDefaults.standard.string(forKey: "profile.ageRange") ?? ""
        self.ageRange     = AgeRange(rawValue: rawAgeRange) ?? .notSpecified
        let rawEthnicity  = UserDefaults.standard.string(forKey: "profile.ethnicity") ?? ""
        self.ethnicity    = Ethnicity(rawValue: rawEthnicity) ?? .notSpecified
        self.profileImageData = UserDefaults.standard.data(forKey: "profile.imageData")
    }

    var fullName: String {
        let parts = [firstName, lastName].filter { !$0.isEmpty }
        return parts.isEmpty ? "Your Name" : parts.joined(separator: " ")
    }

    var subtitleText: String {
        var parts: [String] = []
        if gender != .notSpecified    { parts.append(gender.rawValue) }
        if ageRange != .notSpecified  { parts.append(ageRange.rawValue) }
        return parts.joined(separator: " · ")
    }

    var profileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Allergy Model

struct Allergy: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: AllergyType
    var symptoms: String
    var dateAdded: Date
    
    init(id: UUID = UUID(), name: String, type: AllergyType, symptoms: String = "", dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.symptoms = symptoms
        self.dateAdded = dateAdded
    }
    
    enum AllergyType: String, CaseIterable, Codable, Identifiable {
        case medication = "Medication"
        case food = "Food"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .medication: return "pills.fill"
            case .food: return "fork.knife"
            }
        }
        
        var color: Color {
            switch self {
            case .medication: return .tabiOrange
            case .food: return .green
            }
        }
    }
}

// MARK: - Allergy Manager

class AllergyManager: ObservableObject {
    @Published var allergies: [Allergy] = []
    
    private let allergiesKey = "saved.allergies"
    
    init() {
        loadAllergies()
    }
    
    func addAllergy(_ allergy: Allergy) {
        allergies.append(allergy)
        saveAllergies()
    }
    
    func removeAllergy(_ allergy: Allergy) {
        allergies.removeAll { $0.id == allergy.id }
        saveAllergies()
    }
    
    func updateAllergy(_ allergy: Allergy) {
        if let index = allergies.firstIndex(where: { $0.id == allergy.id }) {
            allergies[index] = allergy
            saveAllergies()
        }
    }
    
    private func saveAllergies() {
        if let encoded = try? JSONEncoder().encode(allergies) {
            UserDefaults.standard.set(encoded, forKey: allergiesKey)
        }
    }
    
    private func loadAllergies() {
        if let data = UserDefaults.standard.data(forKey: allergiesKey),
           let decoded = try? JSONDecoder().decode([Allergy].self, from: data) {
            allergies = decoded
        }
    }
}

// MARK: - Pharmacy Model

struct Pharmacy: Identifiable, Codable {
    let id: UUID
    var name: String
    var address: String
    var phoneNumber: String
    var isPreferred: Bool
    var dateAdded: Date
    
    init(id: UUID = UUID(), name: String, address: String = "", phoneNumber: String = "", isPreferred: Bool = false, dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
        self.isPreferred = isPreferred
        self.dateAdded = dateAdded
    }
}

// MARK: - Pharmacy Search Result

struct PharmacySearchResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let phoneNumber: String
    let mapItem: MKMapItem
}

// MARK: - Pharmacy Manager

class PharmacyManager: ObservableObject {
    @Published var pharmacies: [Pharmacy] = []
    
    private let pharmaciesKey = "saved.pharmacies"
    
    init() {
        loadPharmacies()
    }
    
    func addPharmacy(_ pharmacy: Pharmacy) {
        pharmacies.append(pharmacy)
        savePharmacies()
    }
    
    func removePharmacy(_ pharmacy: Pharmacy) {
        pharmacies.removeAll { $0.id == pharmacy.id }
        savePharmacies()
    }
    
    func updatePharmacy(_ pharmacy: Pharmacy) {
        if let index = pharmacies.firstIndex(where: { $0.id == pharmacy.id }) {
            pharmacies[index] = pharmacy
            savePharmacies()
        }
    }
    
    func setPreferred(_ pharmacy: Pharmacy) {
        for index in pharmacies.indices {
            pharmacies[index].isPreferred = (pharmacies[index].id == pharmacy.id)
        }
        savePharmacies()
    }
    
    func extractPharmacyFromImage(_ image: UIImage) -> String? {
        // Common pharmacy chains to detect
        let commonPharmacies = [
            "CVS", "Walgreens", "Walmart", "Rite Aid", "Kroger",
            "Safeway", "Costco", "Sam's Club", "Target", "Publix",
            "HEB", "Albertsons", "Hy-Vee", "Meijer", "Giant"
        ]
        
        // Simulate OCR detection - in production, use Vision framework
        // For now, return a random pharmacy for demo
        return commonPharmacies.randomElement()
    }
    
    private func savePharmacies() {
        if let encoded = try? JSONEncoder().encode(pharmacies) {
            UserDefaults.standard.set(encoded, forKey: pharmaciesKey)
        }
    }
    
    private func loadPharmacies() {
        if let data = UserDefaults.standard.data(forKey: pharmaciesKey),
           let decoded = try? JSONDecoder().decode([Pharmacy].self, from: data) {
            pharmacies = decoded
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var medicationManager: MedicationManager
    @StateObject private var userProfile = UserProfile()
    @StateObject private var allergyManager = AllergyManager()
    @StateObject private var pharmacyManager = PharmacyManager()
    @State private var showingEditSheet = false
    @State private var showingAllergyProfile = false
    @State private var showingPharmacies = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Avatar + Name ─────────────────────────────────────
                    HStack(spacing: 16) {
                        Button(action: { showingEditSheet = true }) {
                            ZStack(alignment: .bottomTrailing) {
                                if let img = userProfile.profileImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.tabiLavLight)
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.title)
                                                .foregroundColor(.tabiLavender)
                                        )
                                }
                                Circle()
                                    .fill(Color.tabiOrange)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 2, y: 2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userProfile.fullName)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            if !userProfile.subtitleText.isEmpty {
                                Text(userProfile.subtitleText)
                                    .font(.subheadline)
                                    .foregroundColor(.tabiGray)
                            } else {
                                Text("Tap to set up profile")
                                    .font(.subheadline)
                                    .foregroundColor(.tabiOrange)
                            }
                            if userProfile.ethnicity != .notSpecified {
                                Text(userProfile.ethnicity.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.tabiGray)
                            }
                        }

                        Spacer()

                        Button(action: { showingEditSheet = true }) {
                            Text("Edit")
                                .font(.subheadline)
                                .foregroundColor(.tabiOrange)
                        }
                    }
                    .padding(.horizontal, 16)

                    // ── Stats ─────────────────────────────────────────────
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().fill(Color.tabiLavLight).frame(width: 110, height: 110)
                            VStack(spacing: 2) {
                                Text("\(medicationManager.medications.count)")
                                    .font(.system(size: 36, weight: .bold))
                                Text("Active Meds")
                                    .font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                        ZStack {
                            Circle()
                                .stroke(Color.tabiLavender.opacity(0.2), lineWidth: 10)
                                .frame(width: 110, height: 110)
                            Circle()
                                .trim(from: 0, to: CGFloat(medicationManager.gameStats.adherencePercent) / 100)
                                .stroke(Color.tabiLavender, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 110, height: 110)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(medicationManager.gameStats.adherencePercent)%")
                                    .font(.system(size: 26, weight: .bold))
                                Text("Adherence")
                                    .font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                    }

                    // ── Menu items ────────────────────────────────────────
                    VStack(spacing: 0) {
                        // Allergy Profile
                        Button(action: { showingAllergyProfile = true }) {
                            HStack(spacing: 12) {
                                Circle().fill(Color.tabiLavLight).frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "heart.text.square")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Allergy Profile").font(.subheadline.bold())
                                }
                                Spacer()
                                if !allergyManager.allergies.isEmpty {
                                    Text("\(allergyManager.allergies.count)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(minWidth: 20, minHeight: 20)
                                        .background(Circle().fill(Color.tabiOrange))
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.tabiGray).font(.caption)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(Color.tabiCard)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider().padding(.leading, 64)
                        
                        // My Pharmacies
                        Button(action: { showingPharmacies = true }) {
                            HStack(spacing: 12) {
                                Circle().fill(Color.tabiLavLight).frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "cross.case")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("My Pharmacies").font(.subheadline.bold())
                                }
                                Spacer()
                                if !pharmacyManager.pharmacies.isEmpty {
                                    Text("\(pharmacyManager.pharmacies.count)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(minWidth: 20, minHeight: 20)
                                        .background(Circle().fill(Color.tabiOrange))
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.tabiGray).font(.caption)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(Color.tabiCard)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider().padding(.leading, 64)
                        
                        // Setting
                        Button(action: {}) {
                            HStack(spacing: 12) {
                                Circle().fill(Color.tabiLavLight).frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "gearshape")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Setting").font(.subheadline.bold())
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.tabiGray).font(.caption)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(Color.tabiCard)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8).padding(.bottom, 32)
            }
            .background(Color.tabiBG)
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditSheet) {
                EditProfileSheet(userProfile: userProfile)
            }
            .sheet(isPresented: $showingAllergyProfile) {
                AllergyProfileView(allergyManager: allergyManager)
            }
            .sheet(isPresented: $showingPharmacies) {
                PharmaciesView(pharmacyManager: pharmacyManager)
            }
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @ObservedObject var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String  = ""
    @State private var gender: UserProfile.Gender       = .notSpecified
    @State private var ageRange: UserProfile.AgeRange   = .notSpecified
    @State private var ethnicity: UserProfile.Ethnicity = .notSpecified
    @State private var selectedItem: PhotosPickerItem?  = nil
    @State private var previewImage: UIImage?           = nil
    @State private var showingRemoveAlert               = false
    @State private var showingAvatarPicker              = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Photo ─────────────────────────────────────────────
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = previewImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.tabiOrange.opacity(0.4), lineWidth: 2))
                            } else {
                                Circle()
                                    .fill(Color.tabiLavLight)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 38))
                                            .foregroundColor(.tabiLavender)
                                    )
                            }
                            Circle()
                                .fill(Color.tabiOrange)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 4, y: 4)
                        }

                        HStack(spacing: 16) {
                            Button(action: { showingAvatarPicker = true }) {
                                Text("Choose Avatar")
                                    .font(.subheadline)
                                    .foregroundColor(.tabiOrange)
                            }
                            
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.tabiGray)
                            
                            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                Text("Upload Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.tabiOrange)
                            }
                            .onChange(of: selectedItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        previewImage = img
                                    }
                                }
                            }
                        }

                        if previewImage != nil {
                            Button("Remove Photo") { showingRemoveAlert = true }
                                .font(.caption)
                                .foregroundColor(.tabiRed)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // ── Section: Personal Info ────────────────────────────
                    SectionHeader(title: "PERSONAL INFO")

                    VStack(spacing: 0) {
                        ProfileTextField(
                            label: "First Name",
                            placeholder: "Enter first name",
                            text: $firstName,
                            icon: "person"
                        )
                        Divider().padding(.leading, 52)
                        ProfileTextField(
                            label: "Last Name",
                            placeholder: "Enter last name",
                            text: $lastName,
                            icon: "person"
                        )
                        Divider().padding(.leading, 52)

                        // ── Age Range dropdown ────────────────────────────
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.tabiLavLight)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.tabiLavender)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Age Range")
                                    .font(.caption)
                                    .foregroundColor(.tabiGray)
                                Menu {
                                    ForEach(UserProfile.AgeRange.allCases) { option in
                                        Button(action: { ageRange = option }) {
                                            HStack {
                                                Text(option.rawValue)
                                                if ageRange == option {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(ageRange.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(ageRange == .notSpecified ? .tabiGray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.tabiGray)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.tabiCard)
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // ── Section: Gender ───────────────────────────────────
                    SectionHeader(title: "GENDER")

                    VStack(spacing: 0) {
                        ForEach(UserProfile.Gender.allCases) { option in
                            Button(action: { gender = option }) {
                                HStack {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: gender == option ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(gender == option ? .tabiOrange : .tabiGray.opacity(0.4))
                                        .font(.body)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.tabiCard)
                            }
                            .buttonStyle(PlainButtonStyle())
                            if option != UserProfile.Gender.allCases.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // ── Section: Ethnicity ────────────────────────────────
                    SectionHeader(title: "ETHNICITY")

                    VStack(spacing: 0) {
                        ForEach(UserProfile.Ethnicity.allCases) { option in
                            Button(action: { ethnicity = option }) {
                                HStack {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Image(systemName: ethnicity == option ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(ethnicity == option ? .tabiOrange : .tabiGray.opacity(0.4))
                                        .font(.body)
                                        .padding(.leading, 8)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.tabiCard)
                            }
                            .buttonStyle(PlainButtonStyle())
                            if option != UserProfile.Ethnicity.allCases.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 16)
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.tabiGray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .font(.subheadline.bold())
                        .foregroundColor(.tabiOrange)
                }
            }
            .alert("Remove Photo", isPresented: $showingRemoveAlert) {
                Button("Remove", role: .destructive) { previewImage = nil; selectedItem = nil }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to remove your profile photo?")
            }
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet(selectedImage: $previewImage)
            }
        }
        .onAppear { loadCurrentValues() }
    }

    private func loadCurrentValues() {
        firstName    = userProfile.firstName
        lastName     = userProfile.lastName
        gender       = userProfile.gender
        ageRange     = userProfile.ageRange
        ethnicity    = userProfile.ethnicity
        previewImage = userProfile.profileImage
    }

    private func saveAndDismiss() {
        userProfile.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.lastName  = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.gender    = gender
        userProfile.ageRange  = ageRange
        userProfile.ethnicity = ethnicity
        if let img = previewImage {
            userProfile.profileImageData = img.jpegData(compressionQuality: 0.8)
        } else {
            userProfile.profileImageData = nil
        }
        dismiss()
    }
}

// MARK: - Avatar Picker Sheet

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedImage: UIImage?
    
    private let avatarOptions = AvatarGenerator.generateAvatars()
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose an avatar that represents you")
                        .font(.subheadline)
                        .foregroundColor(.tabiGray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(avatarOptions.indices, id: \.self) { index in
                            Button(action: {
                                selectedImage = avatarOptions[index]
                                dismiss()
                            }) {
                                Image(uiImage: avatarOptions[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.tabiOrange.opacity(0.3), lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer().frame(height: 32)
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.tabiGray)
                }
            }
        }
    }
}

// MARK: - Avatar Generator

struct AvatarGenerator {
    static func generateAvatars() -> [UIImage] {
        let colors: [(bg: UIColor, icon: UIColor)] = [
            (UIColor(red: 0.95, green: 0.92, blue: 1.0, alpha: 1.0), UIColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0)),   // Lavender
            (UIColor(red: 1.0, green: 0.93, blue: 0.9, alpha: 1.0), UIColor(red: 0.95, green: 0.5, blue: 0.2, alpha: 1.0)),   // Orange
            (UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0), UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)),    // Blue
            (UIColor(red: 0.95, green: 1.0, blue: 0.95, alpha: 1.0), UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0)),   // Green
            (UIColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 1.0), UIColor(red: 0.9, green: 0.3, blue: 0.4, alpha: 1.0)),   // Red
            (UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0), UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)),    // Yellow
            (UIColor(red: 0.95, green: 0.93, blue: 0.98, alpha: 1.0), UIColor(red: 0.7, green: 0.4, blue: 0.8, alpha: 1.0)),  // Purple
            (UIColor(red: 0.9, green: 0.98, blue: 0.98, alpha: 1.0), UIColor(red: 0.2, green: 0.7, blue: 0.7, alpha: 1.0)),   // Teal
        ]
        
        let icons = [
            "person.fill",
            "heart.fill",
            "star.fill",
            "leaf.fill",
            "sun.max.fill",
            "moon.fill",
            "cloud.fill",
            "bolt.fill",
            "flame.fill",
            "drop.fill",
            "pawprint.fill",
            "face.smiling.fill"
        ]
        
        var avatars: [UIImage] = []
        
        // Generate avatars with different color/icon combinations
        for (index, color) in colors.enumerated() {
            let icon = icons[index % icons.count]
            if let avatar = createAvatar(backgroundColor: color.bg, iconColor: color.icon, iconName: icon) {
                avatars.append(avatar)
            }
        }
        
        // Add more variations
        for i in 0..<8 {
            let colorIndex = (i + 3) % colors.count
            let iconIndex = (i + 4) % icons.count
            let color = colors[colorIndex]
            let icon = icons[iconIndex]
            if let avatar = createAvatar(backgroundColor: color.bg, iconColor: color.icon, iconName: icon) {
                avatars.append(avatar)
            }
        }
        
        return avatars
    }
    
    private static func createAvatar(backgroundColor: UIColor, iconColor: UIColor, iconName: String) -> UIImage? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Draw background circle
            backgroundColor.setFill()
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.fillEllipse(in: rect)
            
            // Draw icon
            let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .medium)
            if let icon = UIImage(systemName: iconName, withConfiguration: config) {
                let iconSize = icon.size
                let x = (size.width - iconSize.width) / 2
                let y = (size.height - iconSize.height) / 2
                
                iconColor.setFill()
                icon.withTintColor(iconColor, renderingMode: .alwaysOriginal)
                    .draw(at: CGPoint(x: x, y: y))
            }
        }
        
        return image
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.tabiGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.bottom, -16)
    }
}

// MARK: - Profile Text Field

struct ProfileTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.tabiLavLight)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.tabiLavender)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundColor(.tabiGray)
                TextField(placeholder, text: $text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.tabiCard)
    }
}
// MARK: - Allergy Profile View

struct AllergyProfileView: View {
    @ObservedObject var allergyManager: AllergyManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddAllergy = false
    @State private var allergyToDelete: Allergy?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.tabiBG.ignoresSafeArea()
                
                if allergyManager.allergies.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 60))
                            .foregroundColor(.tabiLavLight)
                        
                        Text("No Allergies Added")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Text("Keep track of your allergies to ensure safe medication management")
                            .font(.subheadline)
                            .foregroundColor(.tabiGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: { showingAddAllergy = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Allergy")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.tabiOrange)
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // List of allergies
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary card
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Total Allergies")
                                            .font(.caption)
                                            .foregroundColor(.tabiGray)
                                        Text("\(allergyManager.allergies.count)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.tabiOrange)
                                    }
                                    Spacer()
                                    Image(systemName: "heart.text.square.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.tabiLavLight)
                                }
                                .padding(16)
                                .background(Color.tabiCard)
                                .cornerRadius(14)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Group allergies by type
                            ForEach(Allergy.AllergyType.allCases) { type in
                                let allergiesOfType = allergyManager.allergies.filter { $0.type == type }
                                if !allergiesOfType.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.caption)
                                                .foregroundColor(type.color)
                                            Text(type.rawValue)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.primary)
                                            Text("(\(allergiesOfType.count))")
                                                .font(.caption)
                                                .foregroundColor(.tabiGray)
                                        }
                                        .padding(.horizontal, 16)
                                        
                                        VStack(spacing: 0) {
                                            ForEach(allergiesOfType) { allergy in
                                                AllergyRowView(allergy: allergy) {
                                                    allergyToDelete = allergy
                                                    showingDeleteAlert = true
                                                }
                                                if allergy.id != allergiesOfType.last?.id {
                                                    Divider().padding(.leading, 16)
                                                }
                                            }
                                        }
                                        .background(Color.tabiCard)
                                        .cornerRadius(14)
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 80)
                        }
                        .padding(.bottom, 16)
                    }
                    
                    // Floating add button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showingAddAllergy = true }) {
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.tabiOrange)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Allergy Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.tabiOrange)
                        .font(.subheadline.bold())
                }
            }
            .sheet(isPresented: $showingAddAllergy) {
                AddAllergySheet(allergyManager: allergyManager)
            }
            .alert("Delete Allergy", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let allergy = allergyToDelete {
                        allergyManager.removeAllergy(allergy)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(allergyToDelete?.name ?? "this allergy")?")
            }
        }
    }
}

// MARK: - Allergy Row View

struct AllergyRowView: View {
    let allergy: Allergy
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(allergy.type.color.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: allergy.type.icon)
                        .font(.caption)
                        .foregroundColor(allergy.type.color)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(allergy.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                if !allergy.symptoms.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.tabiOrange)
                        Text(allergy.symptoms)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Text("Added \(allergy.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.tabiGray)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.tabiRed)
                    .frame(width: 32, height: 32)
                    .background(Color.tabiRed.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.tabiCard)
    }
}

// MARK: - Add Allergy Sheet

struct AddAllergySheet: View {
    @ObservedObject var allergyManager: AllergyManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var allergyName: String = ""
    @State private var selectedType: Allergy.AllergyType = .medication
    @State private var symptoms: String = ""
    @FocusState private var isNameFieldFocused: Bool
    
    // Common medication allergies
    private let commonMedicationAllergies = [
        "Penicillin",
        "Amoxicillin",
        "Aspirin",
        "Ibuprofen",
        "Codeine",
        "Morphine",
        "Sulfa drugs",
        "Tetracycline",
        "Cephalosporins",
        "Erythromycin",
        "Naproxen",
        "Acetaminophen"
    ]
    
    // Common food allergies
    private let commonFoodAllergies = [
        "Peanuts",
        "Tree nuts",
        "Milk",
        "Eggs",
        "Wheat",
        "Soy",
        "Fish",
        "Shellfish",
        "Sesame",
        "Gluten"
    ]
    
    // Common allergy symptoms
    private let commonSymptoms = [
        "Rash or hives",
        "Itching",
        "Swelling",
        "Difficulty breathing",
        "Nausea or vomiting",
        "Diarrhea",
        "Anaphylaxis",
        "Dizziness",
        "Rapid heartbeat",
        "Stomach pain"
    ]
    
    private var currentAllergyOptions: [String] {
        selectedType == .medication ? commonMedicationAllergies : commonFoodAllergies
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Icon preview
                    VStack(spacing: 16) {
                        Circle()
                            .fill(selectedType.color.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: selectedType.icon)
                                    .font(.system(size: 36))
                                    .foregroundColor(selectedType.color)
                            )
                        
                        Text("Add New Allergy")
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    
                    // Allergy type (First)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ALLERGY TYPE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 0) {
                            ForEach(Allergy.AllergyType.allCases) { type in
                                Button(action: { 
                                    selectedType = type
                                    allergyName = "" // Clear name when type changes
                                }) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(type.color.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Image(systemName: type.icon)
                                                    .font(.caption)
                                                    .foregroundColor(type.color)
                                            )
                                        
                                        Text(type.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedType == type ? .tabiOrange : .tabiGray.opacity(0.4))
                                            .font(.body)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.tabiCard)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if type != Allergy.AllergyType.allCases.last {
                                    Divider().padding(.leading, 64)
                                }
                            }
                        }
                        .background(Color.tabiCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // Allergy name dropdown (Second)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ALLERGY NAME")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.tabiLavLight)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "text.cursor")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Name")
                                        .font(.caption)
                                        .foregroundColor(.tabiGray)
                                    
                                    HStack(spacing: 6) {
                                        TextField("Select or type allergy name", text: $allergyName)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .focused($isNameFieldFocused)
                                        
                                        Menu {
                                            ForEach(currentAllergyOptions, id: \.self) { option in
                                                Button(action: { allergyName = option }) {
                                                    Text(option)
                                                }
                                            }
                                            Divider()
                                            Button(action: { allergyName = ""; isNameFieldFocused = true }) {
                                                HStack {
                                                    Image(systemName: "pencil")
                                                    Text("Enter custom name")
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "chevron.down.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.tabiOrange)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.tabiCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // Reaction Symptoms dropdown (Third)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REACTION SYMPTOMS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.tabiLavLight)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Symptoms")
                                        .font(.caption)
                                        .foregroundColor(.tabiGray)
                                    
                                    HStack(alignment: .top, spacing: 6) {
                                        TextField("Select or type symptoms", text: $symptoms, axis: .vertical)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(3...5)
                                        
                                        Menu {
                                            ForEach(commonSymptoms, id: \.self) { symptom in
                                                Button(action: { 
                                                    if symptoms.isEmpty {
                                                        symptoms = symptom
                                                    } else {
                                                        symptoms += ", " + symptom
                                                    }
                                                }) {
                                                    Text(symptom)
                                                }
                                            }
                                            Divider()
                                            Button(action: { symptoms = "" }) {
                                                HStack {
                                                    Image(systemName: "pencil")
                                                    Text("Enter custom symptoms")
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "chevron.down.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.tabiOrange)
                                                .padding(.top, 2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.tabiCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer().frame(height: 16)
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Add Allergy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.tabiGray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAllergy() }
                        .font(.subheadline.bold())
                        .foregroundColor(allergyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .tabiGray : .tabiOrange)
                        .disabled(allergyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNameFieldFocused = false
            }
        }
    }
    
    private func saveAllergy() {
        let trimmedName = allergyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let trimmedSymptoms = symptoms.trimmingCharacters(in: .whitespacesAndNewlines)
        let newAllergy = Allergy(name: trimmedName, type: selectedType, symptoms: trimmedSymptoms)
        allergyManager.addAllergy(newAllergy)
        dismiss()
    }
}

// MARK: - Pharmacies View
struct PharmaciesView: View {
    @ObservedObject var pharmacyManager: PharmacyManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddPharmacy = false
    @State private var showingCamera = false
    @State private var pharmacyToDelete: Pharmacy?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.tabiBG.ignoresSafeArea()
                
                if pharmacyManager.pharmacies.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "cross.case")
                            .font(.system(size: 60))
                            .foregroundColor(.tabiLavLight)
                        
                        Text("No Pharmacies Added")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Text("Add your preferred pharmacies for easy medication refills")
                            .font(.subheadline)
                            .foregroundColor(.tabiGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        HStack(spacing: 12) {
                            Button(action: { showingCamera = true }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Scan Label")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.tabiOrange)
                                .cornerRadius(10)
                            }
                            
                            Button(action: { showingAddPharmacy = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Manually")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.tabiOrange)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.tabiOrange.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // List of pharmacies
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary card
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("My Pharmacies")
                                            .font(.caption)
                                            .foregroundColor(.tabiGray)
                                        Text("\(pharmacyManager.pharmacies.count)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.tabiOrange)
                                    }
                                    Spacer()
                                    Image(systemName: "cross.case.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.tabiLavLight)
                                }
                                .padding(16)
                                .background(Color.tabiCard)
                                .cornerRadius(14)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Pharmacies list
                            VStack(spacing: 12) {
                                ForEach(pharmacyManager.pharmacies) { pharmacy in
                                    PharmacyRowView(pharmacy: pharmacy, pharmacyManager: pharmacyManager) {
                                        pharmacyToDelete = pharmacy
                                        showingDeleteAlert = true
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            Spacer().frame(height: 80)
                        }
                        .padding(.bottom, 16)
                    }
                    
                    // Floating add buttons
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Spacer()
                            
                            Button(action: { showingCamera = true }) {
                                Image(systemName: "camera.fill")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.tabiLavender)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            
                            Button(action: { showingAddPharmacy = true }) {
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.tabiOrange)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("My Pharmacies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.tabiOrange)
                        .font(.subheadline.bold())
                }
            }
            .sheet(isPresented: $showingAddPharmacy) {
                AddPharmacySheet(pharmacyManager: pharmacyManager)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                PharmacyCameraView(pharmacyManager: pharmacyManager, isPresented: $showingCamera)
            }
            .alert("Delete Pharmacy", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let pharmacy = pharmacyToDelete {
                        pharmacyManager.removePharmacy(pharmacy)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(pharmacyToDelete?.name ?? "this pharmacy")?")
            }
        }
    }
}

// MARK: - Pharmacy Row View

struct PharmacyRowView: View {
    let pharmacy: Pharmacy
    @ObservedObject var pharmacyManager: PharmacyManager
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.tabiOrange.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "cross.case.fill")
                            .font(.title3)
                            .foregroundColor(.tabiOrange)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(pharmacy.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        if pharmacy.isPreferred {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text("Preferred")
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(.tabiOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.tabiOrange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    if !pharmacy.address.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.tabiGray)
                            Text(pharmacy.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    if !pharmacy.phoneNumber.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                                .foregroundColor(.tabiGray)
                            Text(pharmacy.phoneNumber)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Added \(pharmacy.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: { pharmacyManager.setPreferred(pharmacy) }) {
                        Image(systemName: pharmacy.isPreferred ? "star.fill" : "star")
                            .font(.body)
                            .foregroundColor(.tabiOrange)
                            .frame(width: 32, height: 32)
                            .background(Color.tabiOrange.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.tabiRed)
                            .frame(width: 32, height: 32)
                            .background(Color.tabiRed.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(16)
        }
        .background(Color.tabiCard)
        .cornerRadius(14)
    }
}

// MARK: - Add Pharmacy Sheet

struct AddPharmacySheet: View {
    @ObservedObject var pharmacyManager: PharmacyManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var pharmacyName: String = ""
    @State private var address: String = ""
    @State private var phoneNumber: String = ""
    @State private var isPreferred: Bool = false
    @State private var searchResults: [PharmacySearchResult] = []
    @State private var isSearching: Bool = false
    @State private var showingSearchResults: Bool = false
    @FocusState private var isNameFieldFocused: Bool
    
    // Search debounce timer
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Icon preview
                    Circle()
                        .fill(Color.tabiOrange.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.tabiOrange)
                        )
                        .padding(.top, 8)
                    
                    Text("Add New Pharmacy")
                        .font(.title3.bold())
                    
                    // Pharmacy name with search
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PHARMACY NAME")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.tabiLavLight)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: isSearching ? "magnifyingglass" : "text.cursor")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                
                                TextField("Search nearby pharmacies", text: $pharmacyName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .focused($isNameFieldFocused)
                                    .onChange(of: pharmacyName) { _, newValue in
                                        searchPharmacies(query: newValue)
                                    }
                                
                                if !pharmacyName.isEmpty {
                                    Button(action: {
                                        pharmacyName = ""
                                        address = ""
                                        phoneNumber = ""
                                        searchResults = []
                                        showingSearchResults = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.tabiGray)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            // Search results dropdown
                            if showingSearchResults && !searchResults.isEmpty {
                                Divider()
                                
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults) { result in
                                            Button(action: {
                                                selectPharmacy(result)
                                            }) {
                                                HStack(alignment: .top, spacing: 12) {
                                                    Image(systemName: "mappin.circle.fill")
                                                        .foregroundColor(.tabiOrange)
                                                        .font(.title3)
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(result.name)
                                                            .font(.subheadline.bold())
                                                            .foregroundColor(.primary)
                                                        
                                                        if !result.address.isEmpty {
                                                            Text(result.address)
                                                                .font(.caption)
                                                                .foregroundColor(.tabiGray)
                                                                .lineLimit(2)
                                                        }
                                                        
                                                        if !result.phoneNumber.isEmpty {
                                                            Text(result.phoneNumber)
                                                                .font(.caption)
                                                                .foregroundColor(.tabiGray)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            if result.id != searchResults.last?.id {
                                                Divider().padding(.leading, 60)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                            }
                        }
                        .background(Color.tabiCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADDRESS (OPTIONAL)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.tabiLavLight)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "location")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                
                                TextField("Enter address", text: $address)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.tabiCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // Phone number
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PHONE NUMBER (OPTIONAL)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.tabiLavLight)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "phone")
                                            .font(.caption)
                                            .foregroundColor(.tabiLavender)
                                    )
                                
                                TextField("Enter phone number", text: $phoneNumber)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .keyboardType(.phonePad)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.tabiCard)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // Preferred toggle
                    VStack(spacing: 0) {
                        Button(action: { isPreferred.toggle() }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.tabiOrange.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.tabiOrange)
                                    )
                                
                                Text("Set as Preferred Pharmacy")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: isPreferred ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isPreferred ? .tabiOrange : .tabiGray.opacity(0.4))
                                    .font(.body)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    
                    Spacer().frame(height: 16)
                }
            }
            .background(Color.tabiBG)
            .navigationTitle("Add Pharmacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.tabiGray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { savePharmacy() }
                        .font(.subheadline.bold())
                        .foregroundColor(pharmacyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .tabiGray : .tabiOrange)
                        .disabled(pharmacyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }
    
    private func savePharmacy() {
        let trimmedName = pharmacyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newPharmacy = Pharmacy(name: trimmedName, address: trimmedAddress, phoneNumber: trimmedPhone, isPreferred: isPreferred)
        pharmacyManager.addPharmacy(newPharmacy)
        dismiss()
    }
    
    private func searchPharmacies(query: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            showingSearchResults = false
            isSearching = false
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard !Task.isCancelled else { return }
            
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query + " pharmacy"
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            let results = response.mapItems.map { mapItem -> PharmacySearchResult in
                let placemark = mapItem.placemark
                
                // Format address
                var addressComponents: [String] = []
                if let street = placemark.thoroughfare {
                    addressComponents.append(street)
                }
                if let city = placemark.locality {
                    addressComponents.append(city)
                }
                if let state = placemark.administrativeArea {
                    addressComponents.append(state)
                }
                if let zip = placemark.postalCode {
                    addressComponents.append(zip)
                }
                let formattedAddress = addressComponents.joined(separator: ", ")
                
                // Get phone number
                let phoneNumber = mapItem.phoneNumber ?? ""
                
                return PharmacySearchResult(
                    name: mapItem.name ?? "Unknown Pharmacy",
                    address: formattedAddress,
                    phoneNumber: phoneNumber,
                    mapItem: mapItem
                )
            }
            
            await MainActor.run {
                searchResults = results
                showingSearchResults = !results.isEmpty
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                showingSearchResults = false
                isSearching = false
            }
        }
    }
    
    private func selectPharmacy(_ result: PharmacySearchResult) {
        pharmacyName = result.name
        address = result.address
        phoneNumber = result.phoneNumber
        showingSearchResults = false
        isNameFieldFocused = false
    }
}

// MARK: - Pharmacy Camera View

struct PharmacyCameraView: View {
    @ObservedObject var pharmacyManager: PharmacyManager
    @Binding var isPresented: Bool
    @StateObject private var cameraManager = CameraManager.shared
    @State private var capturedImage: UIImage?
    @State private var detectedPharmacyName: String = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        ZStack {
            if let image = capturedImage {
                // Show captured image with detected pharmacy
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding()
                    
                    VStack(spacing: 16) {
                        Text("Detected Pharmacy")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(detectedPharmacyName)
                            .font(.title2.bold())
                            .foregroundColor(.tabiOrange)
                        
                        HStack(spacing: 12) {
                            Button("Retake") {
                                capturedImage = nil
                                detectedPharmacyName = ""
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.tabiGray)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.tabiCard)
                            .cornerRadius(10)
                            
                            Button("Add Pharmacy") {
                                let newPharmacy = Pharmacy(name: detectedPharmacyName)
                                pharmacyManager.addPharmacy(newPharmacy)
                                isPresented = false
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.tabiOrange)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.tabiCard)
                    .cornerRadius(14)
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.tabiBG)
            } else {
                // Camera view
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Scan Medication Label")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Position the pharmacy name in the frame")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button(action: capturePhoto) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 4)
                                        .frame(width: 82, height: 82)
                                )
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            cameraManager.forceSetupAndStart()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            guard let image = image else { return }
            capturedImage = image
            
            // Extract pharmacy name from image
            if let extractedName = pharmacyManager.extractPharmacyFromImage(image) {
                detectedPharmacyName = extractedName
            } else {
                detectedPharmacyName = "Unknown Pharmacy"
            }
        }
    }
}

