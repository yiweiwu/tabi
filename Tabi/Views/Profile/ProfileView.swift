import SwiftUI
import MapKit
import LocalAuthentication
import CoreLocation

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var medicationManager: MedicationManager
    @ObservedObject private var profileStore = UserProfileStore.shared
    @State private var showingEditSheet = false
    @State private var showingAllergyProfile = false
    @State private var showingPharmacies = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + Name
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.tabiLavLight)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.tabiLavender)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.tabiLavender.opacity(0.3), lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileStore.profile.displayName)
                                .font(.title2.bold())
                            Text(profileStore.profile.displayInfo)
                                .font(.subheadline)
                                .foregroundColor(.tabiGray)
                        }
                        Spacer()

                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.tabiLavender)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Stats
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().fill(Color.tabiLavLight).frame(width: 110, height: 110)
                            VStack(spacing: 2) {
                                Text("\(medicationManager.medications.count)").font(.system(size: 36, weight: .bold))
                                Text("Active Meds").font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                        ZStack {
                            Circle().stroke(Color.tabiLavender.opacity(0.2), lineWidth: 10).frame(width: 110, height: 110)
                            Circle().trim(from: 0, to: CGFloat(medicationManager.gameStats.adherencePercent) / 100)
                                .stroke(Color.tabiLavender, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 110, height: 110).rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(medicationManager.gameStats.adherencePercent)%").font(.system(size: 26, weight: .bold))
                                Text("Adherence").font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                    }

                    // Menu items
                    VStack(spacing: 0) {
                        let menuItems: [(String, String, String)] = [
                            ("heart.text.square", "Allergy", ""),
                            ("cross.case",         "My Pharmacies",            ""),
                            ("gearshape",          "Setting",                  ""),
                        ]
                        ForEach(menuItems, id: \.1) { item in
                            let icon = item.0; let title = item.1; let subtitle = item.2
                            Button {
                                if title == "Allergy" {
                                    showingAllergyProfile = true
                                } else if title == "My Pharmacies" {
                                    showingPharmacies = true
                                } else if title == "Setting" {
                                    showingSettings = true
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Circle().fill(Color.tabiLavLight).frame(width: 36, height: 36)
                                        .overlay(Image(systemName: icon).font(.caption).foregroundColor(.tabiLavender))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(title).font(.subheadline.bold())
                                        if !subtitle.isEmpty { 
                                            Text(subtitle).font(.caption).foregroundColor(.tabiGray) 
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.tabiGray).font(.caption)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14).background(Color.tabiCard)
                            }
                            .buttonStyle(.plain)
                            if title != "Setting" { Divider().padding(.leading, 64) }
                        }
                    }
                    .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16)
                }
                .padding(.top, 8).padding(.bottom, 32)
            }
            .background(Color.tabiBG)
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProfileSheet(userProfile: $profileStore.profile)
        }
        .sheet(isPresented: $showingAllergyProfile) {
            AllergyProfileView(userProfile: $profileStore.profile)
        }
        .sheet(isPresented: $showingPharmacies) {
            PharmaciesView(userProfile: $profileStore.profile)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(medicationManager: medicationManager)
        }
    }
}
// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var gender: String = ""
    @State private var age: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""
    
    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                Section("Details") {
                    Picker("Gender", selection: $gender) {
                        Text("Select...").tag("")
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                }
                
                Section("Physical Measurements") {
                    HStack {
                        TextField("Height", text: $height)
                            .keyboardType(.decimalPad)
                        Text("in").foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Text("lbs").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                }
            }
            .onAppear {
                firstName = userProfile.firstName
                lastName = userProfile.lastName
                gender = userProfile.gender
                age = userProfile.age
                height = userProfile.height
                weight = userProfile.weight
            }
        }
    }
    
    private func saveProfile() {
        userProfile.firstName = firstName
        userProfile.lastName = lastName
        userProfile.gender = gender
        userProfile.age = age
        userProfile.height = height
        userProfile.weight = weight
    }
}

// MARK: - Allergy Profile View
struct AllergyProfileView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddAllergy = false
    
    var body: some View {
        NavigationView {
            List {
                if userProfile.allergies.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 60))
                            .foregroundColor(.tabiLavender.opacity(0.5))
                        Text("No Allergies Recorded")
                            .font(.headline)
                        Text("Tap + to add your allergies for safety")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(userProfile.allergies) { allergy in
                        AllergyRowView(allergy: allergy)
                    }
                    .onDelete { indexSet in
                        userProfile.allergies.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("Allergy Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAllergy = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.tabiLavender)
                    }
                }
            }
            .sheet(isPresented: $showingAddAllergy) {
                AddAllergySheet(userProfile: $userProfile)
            }
        }
    }
}

// MARK: - Allergy Row View

struct AllergyRowView: View {
    let allergy: Allergy
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.tabiLavLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: allergy.type.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.tabiLavender)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(allergy.name)
                        .font(.headline)
                    Spacer()
                    Text(allergy.severity.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(allergy.severity.color.opacity(0.2))
                        .foregroundColor(allergy.severity.color)
                        .cornerRadius(8)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: allergy.type.icon)
                        .font(.caption2)
                    Text(allergy.type.rawValue)
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
                
                if !allergy.symptoms.isEmpty {
                    Text("Symptoms: \(allergy.symptoms.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if !allergy.notes.isEmpty {
                    Text(allergy.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Allergy Sheet

struct AddAllergySheet: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var type: Allergy.AllergyType = .food
    @State private var selectedItem: String = ""
    @State private var customItemName: String = ""
    @State private var severity: Allergy.AllergySeverity = .mild
    @State private var selectedSymptoms: Set<String> = []
    @State private var notes: String = ""
    
    var allergyName: String {
        if selectedItem == "Other" {
            return customItemName
        }
        return selectedItem
    }
    
    var isValid: Bool {
        if selectedItem.isEmpty {
            return false
        }
        if selectedItem == "Other" {
            return !customItemName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Allergy Information") {
                    Picker("Type", selection: $type) {
                        ForEach(Allergy.AllergyType.allCases, id: \.self) { allergyType in
                            HStack {
                                Image(systemName: allergyType.icon)
                                Text(allergyType.rawValue)
                            }
                            .tag(allergyType)
                        }
                    }
                    .onChange(of: type) { _, _ in
                        selectedItem = ""
                        customItemName = ""
                    }
                }
                
                Section(type == .food ? "Food Item" : "Drug Name") {
                    Picker(type == .food ? "Select Food" : "Select Drug", selection: $selectedItem) {
                        Text("Select...").tag("")
                        ForEach(type.commonItems, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                    
                    if selectedItem == "Other" {
                        TextField("Enter \(type == .food ? "food" : "drug") name", text: $customItemName)
                    }
                }
                
                Section("Severity") {
                    Picker("Severity Level", selection: $severity) {
                        ForEach(Allergy.AllergySeverity.allCases, id: \.self) { level in
                            HStack {
                                Circle()
                                    .fill(level.color)
                                    .frame(width: 12, height: 12)
                                Text(level.rawValue)
                            }
                            .tag(level)
                        }
                    }
                }
                
                Section("Symptoms") {
                    ForEach(Allergy.commonSymptoms, id: \.self) { symptom in
                        Button {
                            if selectedSymptoms.contains(symptom) {
                                selectedSymptoms.remove(symptom)
                            } else {
                                selectedSymptoms.insert(symptom)
                            }
                        } label: {
                            HStack {
                                Text(symptom)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedSymptoms.contains(symptom) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.tabiLavender)
                                }
                            }
                        }
                    }
                }
                
                Section("Additional Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Allergy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAllergy()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func addAllergy() {
        let finalName = allergyName.trimmingCharacters(in: .whitespaces)
        let newAllergy = Allergy(
            name: finalName,
            type: type,
            severity: severity,
            symptoms: Array(selectedSymptoms).sorted(),
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        userProfile.allergies.append(newAllergy)
        dismiss()
    }
}

// MARK: - Pharmacies View

struct PharmaciesView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddPharmacy = false
    
    var body: some View {
        NavigationView {
            List {
                if userProfile.pharmacies.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cross.case")
                            .font(.system(size: 60))
                            .foregroundColor(.tabiLavender.opacity(0.5))
                        Text("No Pharmacies Added")
                            .font(.headline)
                        Text("Tap + to add your pharmacy")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(userProfile.pharmacies) { pharmacy in
                        PharmacyRowView(pharmacy: pharmacy)
                    }
                    .onDelete { indexSet in
                        userProfile.pharmacies.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("My Pharmacies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPharmacy = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.tabiLavender)
                    }
                }
            }
            .sheet(isPresented: $showingAddPharmacy) {
                AddPharmacySheet(userProfile: $userProfile)
            }
        }
    }
}

// MARK: - Pharmacy Row View

struct PharmacyRowView: View {
    let pharmacy: Pharmacy
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.tabiLavLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.tabiLavender)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pharmacy.name)
                    .font(.headline)
                
                if !pharmacy.address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(pharmacy.address)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                }
                
                if !pharmacy.pharmacistName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(pharmacy.pharmacistName)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if !pharmacy.phoneNumber.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.caption2)
                        Text(pharmacy.phoneNumber)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if !pharmacy.notes.isEmpty {
                    Text(pharmacy.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Pharmacy Sheet

struct AddPharmacySheet: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationSearchService = LocationSearchService()
    
    @State private var pharmacyNameAndAddress: String = ""
    @State private var pharmacistName: String = ""
    @State private var phoneNumber: String = ""
    @State private var notes: String = ""
    
    var isValid: Bool {
        !pharmacyNameAndAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Pharmacy Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Pharmacy Name & Address", text: $pharmacyNameAndAddress)
                            .onChange(of: pharmacyNameAndAddress) { _, newValue in
                                if newValue.count >= 2 {
                                    locationSearchService.updateQuery(newValue)
                                } else {
                                    locationSearchService.results = []
                                }
                            }
                        
                        if !pharmacyNameAndAddress.isEmpty && !locationSearchService.results.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(locationSearchService.results.prefix(5), id: \.self) { result in
                                    Button {
                                        pharmacyNameAndAddress = result.title + ", " + result.subtitle
                                        locationSearchService.results = []
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                    }
                                    
                                    if result != locationSearchService.results.prefix(5).last {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section("Contact Information") {
                    TextField("Pharmacist Name", text: $pharmacistName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("Additional Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Pharmacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPharmacy()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func addPharmacy() {
        // Parse the combined field - everything before the last comma is the name, after is the address
        let components = pharmacyNameAndAddress.components(separatedBy: ", ")
        let name: String
        let address: String
        
        if components.count > 1 {
            name = components.first ?? pharmacyNameAndAddress
            address = components.dropFirst().joined(separator: ", ")
        } else {
            name = pharmacyNameAndAddress
            address = ""
        }
        
        let newPharmacy = Pharmacy(
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            pharmacistName: pharmacistName.trimmingCharacters(in: .whitespaces),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        userProfile.pharmacies.append(newPharmacy)
        dismiss()
    }
}

// MARK: - Location Search Service

class LocationSearchService: NSObject, ObservableObject {
    @Published var searchQuery = ""
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        // Restrict to United States only
        let usRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of US
            span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
        )
        completer.region = usRegion
        
        // Further optimize by limiting point of interest filter
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.pharmacy, .hospital, .store])
    }
    
    func updateQuery(_ query: String) {
        searchQuery = query
        if query.isEmpty {
            results = []
        } else {
            completer.queryFragment = query
        }
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            // Filter to only show US results (results with state abbreviations)
            self.results = completer.results.filter { result in
                let subtitle = result.subtitle
                // Check if subtitle contains US state pattern or "United States"
                return subtitle.contains("United States") || 
                       subtitle.range(of: ", [A-Z]{2}( |,|$)", options: .regularExpression) != nil
            }
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Error searching for location: \(error.localizedDescription)")
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var medicationManager: MedicationManager
    @ObservedObject private var profileStore = UserProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showResetAlert = false
    @State private var showingPrivacyPolicy = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    let countries = [
        "United States", "Canada", "United Kingdom", "Australia",
        "Germany", "France", "Spain", "Italy", "Japan", "Other"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Preferences") {
                    Picker("Units", selection: $profileStore.profile.settings.unitSystem) {
                        ForEach(UserSettings.UnitSystem.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }

                Section("Location") {
                    HStack {
                        Text("Location Permission")
                        Spacer()
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(locationManager.authorizationStatus == .authorizedWhenInUse ||
                                 locationManager.authorizationStatus == .authorizedAlways ? "Enabled" : "Disabled")
                                .foregroundColor(locationManager.authorizationStatus == .authorizedWhenInUse ||
                                               locationManager.authorizationStatus == .authorizedAlways ? .green : .red)
                        }
                    }

                    Picker("Country of Residence", selection: $profileStore.profile.settings.countryOfResidence) {
                        ForEach(countries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                }

                Section("Account") {
                    TextField("Email Address", text: $profileStore.profile.settings.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Security") {
                    Toggle("Face ID / Touch ID", isOn: $profileStore.profile.settings.faceIDEnabled)
                        .onChange(of: profileStore.profile.settings.faceIDEnabled) { _, newValue in
                            if newValue {
                                authenticateWithBiometrics { success in
                                    if !success {
                                        profileStore.profile.settings.faceIDEnabled = false
                                    }
                                }
                            }
                        }

                    if profileStore.profile.settings.faceIDEnabled {
                        Text("Biometric authentication is enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Privacy") {
                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                        }
                    }

                    if isDeletingAccount {
                        HStack {
                            ProgressView()
                            Text("Deleting your account…")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(role: .destructive) {
                            showDeleteAccountAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete My Account & Data")
                            }
                        }
                    }

                    if let deleteAccountError {
                        Text(deleteAccountError)
                            .font(.caption)
                            .foregroundColor(.tabiRed)
                    }
                }

                Section {
                    Text("App Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Developer") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset Onboarding")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Reset Onboarding?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    hasCompletedOnboarding = false
                    // App will restart and show onboarding
                }
            } message: {
                Text("The app will restart and show the onboarding flow again. This is for testing purposes only.")
            }
            .alert("Delete Account & Data?", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This permanently deletes your medications, dose history, and shared connections. This can't be undone.")
            }
        }
        .onAppear {
            locationManager.checkAuthorization()
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        deleteAccountError = nil
        Task {
            do {
                try await AuthenticationManager.shared.deleteAccountAndAllData()
                isDeletingAccount = false
                hasCompletedOnboarding = false
                dismiss()
            } catch {
                isDeletingAccount = false
                deleteAccountError = error.localizedDescription
            }
        }
    }

    private func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Enable biometric authentication for Tabi"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // Biometrics not available
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func checkAuthorization() {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

