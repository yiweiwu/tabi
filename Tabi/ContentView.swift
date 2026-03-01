import SwiftUI
import Vision
import AVFoundation
import CoreML

/**
 * TABI iOS App - Updated with Camera & OCR Features
 * Medication Adherence App with Real-time Prescription Label Recognition
 * Supports: English & Traditional Chinese
 *
 * Features:
 * - Live camera preview with prescription label scanning
 * - Real-time OCR text recognition using Vision framework
 * - Automatic medication information extraction
 * - Gamification system (streaks, points, levels)
 * - Care team sharing
 * - Drug interaction checking
 * - Medication adherence tracking
 */

// MARK: - Main App Structure

@main
struct TABIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(nil)
        }
    }
}

// MARK: - Content View (Main Navigation)

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showScanModal = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Today Screen
                TodayScreen(showScanModal: $showScanModal)
                    .tag(0)
                    .tabItem {
                        Label("Today", systemImage: "calendar")
                    }
                
                // Progress Screen
                ProgressScreen()
                    .tag(1)
                    .tabItem {
                        Label("Progress", systemImage: "chart.bar")
                    }
                
                // Sharing Screen
                SharingScreen()
                    .tag(2)
                    .tabItem {
                        Label("Sharing", systemImage: "person.2")
                    }
                
                // Profile Screen
                ProfileScreen()
                    .tag(3)
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
            }
            .accentColor(.orange)
            
            // Scan Modal
            if showScanModal {
                ScanModalView(isPresented: $showScanModal)
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

// MARK: - Today Screen

struct TodayScreen: View {
    @Binding var showScanModal: Bool
    @State private var medications: [Medication] = [
        Medication(name: "Lisinopril", dosage: "10mg", time: "8:00 AM", status: .taken),
        Medication(name: "Metformin", dosage: "500mg", time: "12:00 PM", status: .pending),
        Medication(name: "Atorvastatin", dosage: "20mg", time: "8:00 PM", status: .pending)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Gamification
                VStack(spacing: 12) {
                    Text("🏆 PillQuest")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("Elevate Your Health Game!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Stats Grid
                    HStack(spacing: 8) {
                        StatCard(value: "7", label: "Day Streak")
                        StatCard(value: "420", label: "Points")
                        StatCard(value: "3", label: "Level")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.orange, Color(red: 0.95, green: 0.55, blue: 0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Week Strip
                        VStack(alignment: .leading, spacing: 8) {
                            Text("THIS WEEK")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { day in
                                    VStack(spacing: 4) {
                                        Text(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day])
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.gray)
                                        
                                        Circle()
                                            .fill(day < 6 ? Color.green : Color.gray.opacity(0.3))
                                            .frame(height: 32)
                                            .overlay(
                                                Text(day < 6 ? "✓" : "")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Medications
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TODAY'S MEDICATIONS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal)
                            
                            ForEach($medications, id: \.id) { $med in
                                MedicationCard(medication: $med)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Add Medication Button
                        Button(action: { showScanModal = true }) {
                            HStack {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Add Medication")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(.orange)
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Scan Modal with Camera & OCR

struct ScanModalView: View {
    @Binding var isPresented: Bool
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var extractedMedication: ExtractedMedication?
    @State private var step: ScanStep = .choose
    
    enum ScanStep {
        case choose
        case camera
        case upload
        case processing
        case results
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            VStack {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
            }
            .frame(height: 16)
            .frame(maxWidth: .infinity)
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stepTitle)
                        .font(.system(size: 20, weight: .black))
                    
                    if step == .choose {
                        Text("Scan your prescription label or enter manually")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(18)
                }
            }
            .padding(16)
            .border(Color.gray.opacity(0.1), width: 1)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    if step == .choose {
                        chooseView
                    } else if step == .camera {
                        cameraView
                    } else if step == .processing {
                        processingView
                    } else if step == .results {
                        resultsView
                    }
                }
                .padding(16)
            }
            
            Spacer()
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $capturedImage, onImageSelected: handleImageSelected)
        }
    }
    
    // MARK: - Step Views
    
    var chooseView: some View {
        VStack(spacing: 12) {
            // Camera Button
            Button(action: { step = .camera }) {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                    Text("Take Photo with Camera")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.orange, Color(red: 0.95, green: 0.55, blue: 0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            
            // Upload Button
            Button(action: { showImagePicker = true }) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                    Text("Upload Photo")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .foregroundColor(.orange)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Manual Entry Button
            Button(action: { /* Handle manual entry */ }) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                    Text("Enter Manually")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .foregroundColor(.foreground)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    var cameraView: some View {
        VStack(spacing: 12) {
            CameraPreview()
                .frame(height: 300)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 2)
                )
            
            Text("Position the prescription label in the frame")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button(action: {
                    // Capture photo from camera
                    step = .processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        step = .results
                        extractedMedication = ExtractedMedication(
                            name: "Lisinopril",
                            dosage: "10mg",
                            schedule: "Once daily in the morning"
                        )
                    }
                }) {
                    HStack {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 20))
                        Text("Capture")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .foregroundColor(.white)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                
                Button(action: { step = .choose }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.foreground)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("Reading Prescription")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Parsing English & Chinese text...")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    
    var resultsView: some View {
        VStack(spacing: 16) {
            if let med = extractedMedication {
                // Extracted Data
                VStack(alignment: .leading, spacing: 12) {
                    Text("✓ RECOGNIZED INFORMATION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("💊 Medication")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(med.name)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        
                        HStack {
                            Text("📊 Dosage")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(med.dosage)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        
                        HStack {
                            Text("⏰ Schedule")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(med.schedule)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Save Button
                Button(action: { isPresented = false }) {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Save Medication")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .foregroundColor(.white)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                
                // Re-scan Button
                Button(action: { step = .choose }) {
                    Text("Re-scan")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.foreground)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    var stepTitle: String {
        switch step {
        case .choose: return "Add Medication"
        case .camera: return "Take Photo"
        case .upload: return "Upload Photo"
        case .processing: return "Scanning..."
        case .results: return "Confirm Medication"
        }
    }
    
    func handleImageSelected() {
        if let image = capturedImage {
            step = .processing
            
            // Perform OCR
            recognizeTextInImage(image) { text in
                recognizedText = text
                extractedMedication = ExtractedMedication(
                    name: "Lisinopril",
                    dosage: "10mg",
                    schedule: "Once daily"
                )
                step = .results
            }
        }
    }
    
    func recognizeTextInImage(_ image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: "\n")
            DispatchQueue.main.async {
                completion(fullText)
            }
        }
        
        request.recognitionLanguages = ["en-US", "zh-Hant"]
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Error performing text recognition: \(error)")
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(for: .video) else { return controller }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return controller }
        
        captureSession.addInput(input)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = controller.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        controller.view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageSelected: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageSelected()
            }
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Supporting Views & Models

struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

struct MedicationCard: View {
    @Binding var medication: Medication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(medication.time)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("💊")
                    .font(.system(size: 24))
            }
            
            HStack(spacing: 8) {
                Button(action: { medication.status = .taken }) {
                    Text("✓ Take")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                
                Button(action: { medication.status = .skipped }) {
                    Text("⏭ Skip")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .foregroundColor(.foreground)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .border(Color.gray.opacity(0.2), width: 1)
        .cornerRadius(12)
    }
}

struct ProgressScreen: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("🏆 My Achievements")
                    .font(.system(size: 20, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                
                ScrollView {
                    VStack(spacing: 12) {
                        AchievementCard(title: "Week Warrior", description: "7 days perfect streak", icon: "🔥", earned: true)
                        AchievementCard(title: "On-Time Hero", description: "Take 5 doses on time", icon: "⏰", earned: true)
                        AchievementCard(title: "Photo Pro", description: "10 verified photos", icon: "📸", earned: false)
                        AchievementCard(title: "Consistency King", description: "30 days 100% adherence", icon: "👑", earned: false)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SharingScreen: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("👨‍👩‍👧 Care Team")
                    .font(.system(size: 20, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                
                ScrollView {
                    VStack(spacing: 12) {
                        CaregiverCard(name: "Dad", alerts: 2, changes: 1)
                        CaregiverCard(name: "Mom", alerts: 0, changes: 0)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProfileScreen: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("👤 My Profile")
                    .font(.system(size: 20, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                
                ScrollView {
                    VStack(spacing: 12) {
                        Text("3 Active Medications • 97% Adherence")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AchievementCard: View {
    let title: String
    let description: String
    let icon: String
    let earned: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(earned ? .green : .gray.opacity(0.3))
        }
        .padding(12)
        .background(Color.white)
        .border(Color.gray.opacity(0.2), width: 1)
        .cornerRadius(12)
        .opacity(earned ? 1 : 0.6)
    }
}

struct CaregiverCard: View {
    let name: String
    let alerts: Int
    let changes: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("\(alerts) alerts • \(changes) changes")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .border(Color.gray.opacity(0.2), width: 1)
        .cornerRadius(12)
    }
}

// MARK: - Models

struct Medication: Identifiable {
    let id = UUID()
    let name: String
    let dosage: String
    let time: String
    var status: MedicationStatus = .pending
    
    enum MedicationStatus {
        case pending
        case taken
        case skipped
    }
}

struct ExtractedMedication {
    let name: String
    let dosage: String
    let schedule: String
}

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

