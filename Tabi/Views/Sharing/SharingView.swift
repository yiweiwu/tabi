import SwiftUI
import Contacts
import ContactsUI
import MessageUI
import FirebaseFirestore
import UIKit

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

// MARK: - Mail Compose View Controller

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Environment(\.dismiss) var dismiss
    var onComplete: ((MFMailComposeResult) -> Void)?
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.onComplete?(result)
            parent.dismiss()
        }
    }
    
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
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

// MARK: - Share With Someone View

struct ShareWithSomeoneView: View {
    @ObservedObject var medicationManager: MedicationManager
    var onConnectionAdded: ((SharedPerson) -> Void)?
    @Environment(\.dismiss) var dismiss
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var showMailCompose = false
    @State private var showContactPicker = false
    @State private var selectedContact: CNContact?
    @State private var selectedContactName: String = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    @State private var connectionWasAdded = false
    
    private var confirmationMessage: String {
        let userName = medicationManager.userProfile.firstName.isEmpty ? "the user" : medicationManager.userProfile.firstName
        let contactName = selectedContactName.isEmpty ? "there" : selectedContactName.components(separatedBy: " ").first ?? selectedContactName

        return """
        Hi \(contactName), it's Tabi. You're now subscribed to \(userName)'s medication schedule.

        Remember: You'll be notified if \(userName) misses a pill so you can send a reminder.
        """
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
        
        // Save contact name
        let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        selectedContactName = fullName.isEmpty ? "Contact" : fullName
    }

    // Saves the connection to Firestore first, then attempts a best-effort
    // confirmation. A phone number gets a confirmation SMS via the same
    // Firestore -> Cloud Function -> AWS SNS pipeline the missed-dose alerts
    // use, so it works from the Simulator and doesn't depend on the device's
    // own Messages app. Email still uses the native Mail compose sheet since
    // there's no server-side email pipeline. Neither confirmation blocks the
    // connection from being added.
    private func addConnectionAndConfirm() {
        guard !phoneNumber.isEmpty || !email.isEmpty else {
            successMessage = "This contact has no phone number or email address."
            showSuccessAlert = true
            return
        }

        let newConnection = SharedPerson(
            name: selectedContactName.isEmpty ? (phoneNumber.isEmpty ? email : phoneNumber) : selectedContactName,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            email: email.isEmpty ? nil : email
        )
        onConnectionAdded?(newConnection)
        connectionWasAdded = true

        if !phoneNumber.isEmpty {
            ConnectionConfirmationService.shared.sendConfirmation(phone: phoneNumber, message: confirmationMessage)
            finish("Added \(newConnection.name) to your shared connections. A confirmation text is on its way.")
        } else if MailComposeView.canSendMail {
            showMailCompose = true
        } else {
            finish("Added \(newConnection.name) to your shared connections.")
        }
    }

    private func finish(_ message: String) {
        successMessage = message
        showSuccessAlert = true
        clearFields()
    }

    private func clearFields() {
        phoneNumber = ""
        email = ""
        selectedContactName = ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Button(action: {
                    showContactPicker = true
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(.tabiLavender)
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
                
                Text("Tap the contact icon to select a contact")
                    .font(.subheadline)
                    .foregroundColor(.tabiGray)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.tabiCard)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
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
            Button(action: addConnectionAndConfirm) {
                Text("Add Connection")
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
        }
        .background(Color.tabiBG)
        .navigationTitle("Share with")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(recipients: [email], subject: "Medication Schedule Subscription", body: confirmationMessage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .sent:
                        finish("Added to your shared connections and sent a confirmation email.")
                    case .failed:
                        finish("Added to your shared connections, but the confirmation email failed to send.")
                    case .cancelled:
                        finish("Added to your shared connections. Confirmation email not sent.")
                    case .saved:
                        finish("Added to your shared connections. Confirmation email saved as draft.")
                    @unknown default:
                        finish("Added to your shared connections.")
                    }
                }
            }
        }
        .sheet(isPresented: $showContactPicker, onDismiss: {
            // This runs after the contact picker is fully dismissed
            if let contact = selectedContact {
                updateFromContact(contact)
                // Wait for picker sheet to fully close before adding the connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    addConnectionAndConfirm()
                }
            }
        }) {
            ContactPicker(selectedContact: $selectedContact)
        }
        .alert("Connection Status", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                if connectionWasAdded { dismiss() }
            }
        } message: {
            Text(successMessage)
        }
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

struct SharedPerson: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String?
    let email: String?
    let dateAdded: Date
    
    init(id: UUID = UUID(), name: String, phoneNumber: String? = nil, email: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.dateAdded = dateAdded
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dateAdded)
    }
}

// MARK: - Scan QR Code View

struct ScanQRCodeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Scan QR Code
            VStack(spacing: 14) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.tabiLavender)
                Text("Scan QR Code")
                    .font(.title2.bold())
                Text("Point your camera at someone's Tabi QR code to connect with them.")
                    .font(.subheadline)
                    .foregroundColor(.tabiGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Divider().padding(.horizontal, 40).padding(.vertical, 36)

            // My QR Code
            VStack(spacing: 14) {
                Image(systemName: "qrcode")
                    .font(.system(size: 70))
                    .foregroundColor(.tabiLavender)
                Text("My QR Code")
                    .font(.title2.bold())
                Text("Share your QR code so others can scan it to connect with you.")
                    .font(.subheadline)
                    .foregroundColor(.tabiGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .background(Color.tabiBG)
        .navigationTitle("Scan QR Code")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sharing View

struct SharingView: View {
    @ObservedObject var medicationManager: MedicationManager
    @State private var sharingPeople: [SharedPerson] = []
    @State private var showDeleteConfirmation = false
    @State private var personToDelete: SharedPerson?
    @State private var isEditMode = false
    @State private var listener: ListenerRegistration?

    // Requires a signed-in user - no anonymous/device-ID fallback, since that
    // would reintroduce unscoped access to another installation's data.
    private var collection: CollectionReference? {
        guard let userId = AuthenticationManager.shared.uid else { return nil }
        return Firestore.firestore().collection("users").document(userId).collection("sharedPeople")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Sharing Options
                    VStack(spacing: 0) {
                        // Share with Someone
                        NavigationLink(destination: ShareWithSomeoneView(medicationManager: medicationManager, onConnectionAdded: addConnection)) {
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

                        // Scan QR Code
                        NavigationLink(destination: ScanQRCodeView()) {
                            HStack(spacing: 14) {
                                Circle().fill(Color.tabiLavLight).frame(width: 50, height: 50)
                                    .overlay(Image(systemName: "qrcode.viewfinder").font(.title3).foregroundColor(.tabiLavender))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scan QR Code").font(.headline).foregroundColor(.primary)
                                    Text("Scan someone's QR code to connect").font(.caption).foregroundColor(.tabiGray)
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
                    if !sharingPeople.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Shared Connections").font(.headline).foregroundColor(.primary)
                                Spacer()
                                Button(isEditMode ? "Done" : "Edit") {
                                    withAnimation {
                                        isEditMode.toggle()
                                    }
                                }
                                .foregroundColor(.tabiLavender)
                                .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                ForEach(sharingPeople) { person in
                                    VStack(spacing: 0) {
                                        HStack(spacing: 14) {
                                            // Delete button on left (edit mode)
                                            if isEditMode {
                                                Button(action: {
                                                    personToDelete = person
                                                    showDeleteConfirmation = true
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundColor(.red)
                                                        .font(.title3)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(LinearGradient(colors: [Color.tabiLavender.opacity(0.7), Color.tabiBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 52, height: 52)
                                                .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(person.name).font(.subheadline.bold())
                                                if let phone = person.phoneNumber {
                                                    Label(phone, systemImage: "phone.fill")
                                                        .font(.caption).foregroundColor(.tabiGray)
                                                }
                                                if let email = person.email {
                                                    Label(email, systemImage: "envelope.fill")
                                                        .font(.caption).foregroundColor(.tabiGray)
                                                }
                                            }
                                            Spacer()
                                            
                                            if !isEditMode {
                                                Text(person.displayTime).font(.caption).foregroundColor(.tabiGray)
                                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                        .background(Color.tabiCard)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                removeConnection(person)
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
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color.tabiBG)
            .navigationTitle("Sharing")
        }
        .onAppear {
            listener = collection?.addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                sharingPeople = docs.compactMap { Self.decodePerson($0.data()) }.sorted { $0.dateAdded > $1.dateAdded }
            }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .alert("Remove Connection", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let person = personToDelete {
                    withAnimation {
                        removeConnection(person)
                    }
                    isEditMode = false
                }
            }
        } message: {
            if let person = personToDelete {
                Text("Are you sure you want to remove \(person.name) from your shared connections?")
            }
        }
    }
    
    private func addConnection(_ person: SharedPerson) {
        guard let dict = Self.encodePerson(person), let collection else { return }
        collection.document(person.id.uuidString).setData(dict)
    }

    private func removeConnection(_ person: SharedPerson) {
        collection?.document(person.id.uuidString).delete()
    }

    private static func encodePerson(_ person: SharedPerson) -> [String: Any]? { person.firestoreDict() }
    private static func decodePerson(_ dict: [String: Any]) -> SharedPerson? { SharedPerson.decoded(from: dict) }
}

// MARK: - Previews

#Preview("Sharing View") {
    SharingView(medicationManager: MedicationManager())
}

#Preview("Share With Someone") {
    NavigationView {
        ShareWithSomeoneView(medicationManager: MedicationManager(), onConnectionAdded: { person in
            print("Added connection: \(person.name)")
        })
    }
}

#Preview("Ask Someone to Share") {
    NavigationView {
        AskSomeoneToShareView()
    }
}


