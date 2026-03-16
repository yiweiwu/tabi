import SwiftUI
import Contacts
import ContactsUI

// MARK: - Contact Picker

struct ContactPicker: UIViewControllerRepresentable {
    @Binding var selectedContact: CNContact?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        
        init(_ parent: ContactPicker) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.selectedContact = contact
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Handle cancel
        }
    }
}

// MARK: - Ask Someone to Share View

struct AskSomeoneToShareView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var showRequestSheet = false
    @State private var showContactPicker = false
    @State private var selectedContact: CNContact?
    
    private var requestMessage: String {
        var message = "I'd like to request access to view your medication list via Tabi.\n\n"
        
        if !phoneNumber.isEmpty {
            message += "Phone: \(phoneNumber)\n"
        }
        if !email.isEmpty {
            message += "Email: \(email)\n"
        }
        
        message += "\nPlease share your medication information with me."
        return message
    }
    
    private func updateFromContact(_ contact: CNContact) {
        // Extract phone number
        if let phone = contact.phoneNumbers.first {
            phoneNumber = phone.value.stringValue
        }
        
        // Extract email
        if let emailAddress = contact.emailAddresses.first {
            email = String(emailAddress.value)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.tabiGray)
                        .frame(width: 20, height: 20)
                    
                    TextField("Search contacts by name", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.tabiGray)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        showContactPicker = true
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.tabiLavender)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.tabiCard)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            Spacer()
            
            // Bottom options section
            VStack(spacing: 0) {
                // Enter Phone Number
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.tabiLavender)
                            .frame(width: 24)
                        TextField("Enter Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.tabiCard)
                
                Divider().padding(.leading, 56)
                
                // Enter Email
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.tabiLavender)
                            .frame(width: 24)
                        TextField("Enter Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.tabiCard)
            }
            .background(Color.tabiCard)
            .cornerRadius(14)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            
            // Send Button
            Button(action: {
                showRequestSheet = true
            }) {
                Text("Send Request")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.tabiLavender)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(phoneNumber.isEmpty && email.isEmpty)
            .opacity((phoneNumber.isEmpty && email.isEmpty) ? 0.5 : 1.0)
            .sheet(isPresented: $showRequestSheet) {
                ActivityViewController(activityItems: [requestMessage])
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPicker(selectedContact: $selectedContact)
            }
            .onChange(of: selectedContact) { _, newContact in
                if let contact = newContact {
                    updateFromContact(contact)
                }
            }
        }
        .background(Color.tabiBG)
        .navigationTitle("Ask to Share")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contact Search Result

struct ContactSearchResult: Identifiable {
    let id = UUID()
    let contact: CNContact
    let name: String
    let email: String?
    let phoneNumber: String?
}

// MARK: - Share With Someone View

struct ShareWithSomeoneView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var showShareSheet = false
    @State private var showContactPicker = false
    @State private var selectedContact: CNContact?
    @State private var searchResults: [ContactSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    
    private var shareMessage: String {
        var message = "I'd like to share my medication list with you via Tabi.\n\n"
        
        if !phoneNumber.isEmpty {
            message += "Phone: \(phoneNumber)\n"
        }
        if !email.isEmpty {
            message += "Email: \(email)\n"
        }
        
        message += "\nAccept this invitation to view my medication information."
        return message
    }
    
    private func updateFromContact(_ contact: CNContact) {
        // Extract phone number
        if let phone = contact.phoneNumbers.first {
            phoneNumber = phone.value.stringValue
        }
        
        // Extract email
        if let emailAddress = contact.emailAddresses.first {
            email = String(emailAddress.value)
        }
    }
    
    private func searchContacts() {
        guard !searchText.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        Task {
            let store = CNContactStore()
            let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            
            var results: [ContactSearchResult] = []
            
            do {
                // First try name search
                let predicate = CNContact.predicateForContacts(matchingName: searchText)
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                
                for contact in contacts {
                    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    let result = ContactSearchResult(
                        contact: contact,
                        name: fullName.isEmpty ? "No Name" : fullName,
                        email: contact.emailAddresses.first.map { String($0.value) },
                        phoneNumber: contact.phoneNumbers.first?.value.stringValue
                    )
                    results.append(result)
                }
            } catch {
                print("Error searching contacts by name: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    private func selectSearchResult(_ result: ContactSearchResult) {
        updateFromContact(result.contact)
        searchText = ""
        searchResults = []
        isSearchFocused = false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.tabiGray)
                    .frame(width: 20, height: 20)
                
                TextField("Search contacts by name, email, or phone", text: $searchText)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit {
                        searchTask?.cancel()
                        searchContacts()
                    }
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second debounce
                            if !Task.isCancelled {
                                searchContacts()
                            }
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchTask?.cancel()
                        searchText = ""
                        searchResults = []
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.tabiGray)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    showContactPicker = true
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(.tabiLavender)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.tabiCard)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Search Results
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults) { result in
                            Button(action: {
                                selectSearchResult(result)
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.tabiLavLight)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(result.name.isEmpty ? "?" : String(result.name.prefix(1)))
                                                .font(.headline)
                                                .foregroundColor(.tabiLavender)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        if let email = result.email {
                                            Text(email)
                                                .font(.caption)
                                                .foregroundColor(.tabiGray)
                                        }
                                        
                                        if let phone = result.phoneNumber {
                                            Text(phone)
                                                .font(.caption)
                                                .foregroundColor(.tabiGray)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if result.id != searchResults.last?.id {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color.tabiCard)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .frame(maxHeight: 300)
            }
            
            Spacer()
                .allowsHitTesting(false)
            
            // Bottom options section
            VStack(spacing: 0) {
                // Enter Phone Number
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.tabiLavender)
                            .frame(width: 24)
                        TextField("Enter Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.tabiCard)
                
                Divider().padding(.leading, 56)
                
                // Enter Email
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.tabiLavender)
                            .frame(width: 24)
                        TextField("Enter Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.tabiCard)
            }
            .background(Color.tabiCard)
            .cornerRadius(14)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            
            // Send Button
            Button(action: {
                showShareSheet = true
            }) {
                Text("Send Invitation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.tabiLavender)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(phoneNumber.isEmpty && email.isEmpty)
            .opacity((phoneNumber.isEmpty && email.isEmpty) ? 0.5 : 1.0)
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: [shareMessage])
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPicker(selectedContact: $selectedContact)
            }
            .onChange(of: selectedContact) { _, newContact in
                if let contact = newContact {
                    updateFromContact(contact)
                }
            }
        }
        .background(Color.tabiBG)
        .navigationTitle("Share with")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Activity View Controller for Share Sheet

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Shared Person Model

struct SharedPerson: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let hasAlert: Bool
}

// MARK: - Sharing View

struct SharingView: View {
    @State private var sharingPeople: [SharedPerson] = [
        SharedPerson(name: "Dad", time: "9:23 AM", hasAlert: true),
        SharedPerson(name: "Mom", time: "9:36 AM", hasAlert: false)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Sharing Options
                    VStack(spacing: 0) {
                        // Share with Someone
                        NavigationLink(destination: ShareWithSomeoneView()) {
                            HStack(spacing: 14) {
                                Circle().fill(Color.tabiLavLight).frame(width: 50, height: 50)
                                    .overlay(Image(systemName: "person.badge.plus").font(.title3).foregroundColor(.tabiLavender))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Share with Someone").font(.headline).foregroundColor(.primary)
                                    Text("Share your medication list").font(.caption).foregroundColor(.tabiGray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 16)
                        }
                        .background(Color.tabiCard)
                        
                        Divider().padding(.leading, 80)
                        
                        // Ask Someone to Share
                        NavigationLink(destination: AskSomeoneToShareView()) {
                            HStack(spacing: 14) {
                                Circle().fill(Color.tabiLavLight).frame(width: 50, height: 50)
                                    .overlay(Image(systemName: "person.2.fill").font(.title3).foregroundColor(.tabiLavender))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ask Someone to Share").font(.headline).foregroundColor(.primary)
                                    Text("Request access to their medications").font(.caption).foregroundColor(.tabiGray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 16)
                        }
                        .background(Color.tabiCard)
                    }
                    .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16)
                    
                    // Shared Connections
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared Connections").font(.headline).foregroundColor(.primary)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 0) {
                            ForEach(sharingPeople) { person in
                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(person.hasAlert
                                                  ? LinearGradient(colors: [Color.tabiLavender.opacity(0.7), Color.tabiBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                  : LinearGradient(colors: [Color.tabiOrange.opacity(0.5), Color.tabiAmber.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 52, height: 52)
                                            .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(person.name).font(.subheadline.bold())
                                            if person.hasAlert {
                                                Label("1 Alert", systemImage: "exclamationmark.triangle.fill")
                                                    .font(.caption).foregroundColor(.tabiAmber)
                                                Label("3 Changes", systemImage: "arrow.triangle.2.circlepath")
                                                    .font(.caption).foregroundColor(.tabiGray)
                                            } else {
                                                Label("2 Changes", systemImage: "arrow.triangle.2.circlepath")
                                                    .font(.caption).foregroundColor(.tabiGray)
                                            }
                                        }
                                        Spacer()
                                        Text(person.time).font(.caption).foregroundColor(.tabiGray)
                                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .background(Color.tabiCard)
                                    
                                    // Remove button for Dad
                                    if person.name == "Dad" {
                                        Button(action: {
                                            withAnimation {
                                                if let index = sharingPeople.firstIndex(where: { $0.id == person.id }) {
                                                    sharingPeople.remove(at: index)
                                                }
                                            }
                                        }) {
                                            Text("Remove this contact")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.red)
                                                .cornerRadius(8)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.tabiCard)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            if let index = sharingPeople.firstIndex(where: { $0.id == person.id }) {
                                                sharingPeople.remove(at: index)
                                            }
                                        }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                
                                if person.id != sharingPeople.last?.id { 
                                    Divider().padding(.leading, 82) 
                                }
                            }
                        }
                        .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16)
                    }

                    // Export PDF
                    HStack(spacing: 12) {
                        Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "doc.fill").font(.caption).foregroundColor(.tabiLavender))
                        Text("Export PDF").font(.subheadline)
                        Spacer()
                        Image(systemName: "square.and.arrow.up").foregroundColor(.tabiGray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.tabiCard).cornerRadius(14)
                    .padding(.horizontal, 16)
                    
                    // Share with your doctor
                    Button(action: {
                        // Share with doctor action
                    }) {
                        HStack(spacing: 12) {
                            Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "stethoscope").font(.caption).foregroundColor(.tabiLavender))
                            Text("Share with your doctor").font(.subheadline).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.tabiGray).font(.caption)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.tabiCard).cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color.tabiBG)
            .navigationTitle("Sharing")
        }
    }
}
