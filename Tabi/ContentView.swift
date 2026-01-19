import SwiftUI
import AVFoundation
import UIKit

// MARK: - Main Content View

struct ContentView: View {
    // We Wu testing
    @StateObject private var medicationManager = MedicationManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(medicationManager: medicationManager)
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Today")
                }
                .tag(0)
            
            ProgressView(medicationManager: medicationManager)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Progress")
                }
                .tag(1)
        }
        .accentColor(.green)
    }
}

// MARK: - Data Models

struct Medication: Identifiable, Codable {
    var id = UUID()
    let name: String
    let emoji: String
    let dosageTime: Date
    let points: Int
    var lastTaken: Date?
    var streak: Int = 0
    
    var isOverdue: Bool {
        guard let lastTaken = lastTaken else { return true }
        return Date().timeIntervalSince(lastTaken) > 86400 // 24 hours
    }
}

struct GameStats: Codable {
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var level: Int = 1
    var achievements: [Achievement] = []
    
    var calculatedLevel: Int {
        return max(1, totalPoints / 150 + 1)
    }
}

struct Achievement: Identifiable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let icon: String
    let pointsRequired: Int
    var isEarned: Bool = false
    let earnedDate: Date?
}

// MARK: - Medication Manager (Data Layer)

class MedicationManager: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var gameStats = GameStats()
    
    init() {
        loadSampleData()
    }
    
    func loadSampleData() {
        medications = [
            Medication(name: "Vitamin D", emoji: "💊", dosageTime: createTime(hour: 9), points: 10),
            Medication(name: "Blood Pressure Med", emoji: "🩺", dosageTime: createTime(hour: 14), points: 15)
        ]
        
        gameStats = GameStats(
            totalPoints: 420,
            currentStreak: 7,
            level: 3,
            achievements: [
                Achievement(title: "Week Warrior", description: "7 days perfect streak", icon: "🔥", pointsRequired: 70, isEarned: true, earnedDate: Date()),
                Achievement(title: "On-Time Hero", description: "Took 5 doses on time", icon: "⏰", pointsRequired: 50, isEarned: true, earnedDate: Date()),
                Achievement(title: "Photo Pro", description: "10 verified photos", icon: "📸", pointsRequired: 100, isEarned: true, earnedDate: Date())
            ]
        )
    }
    
    func createTime(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
    
    func recordMedicationTaken(_ medication: Medication, points: Int) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index].lastTaken = Date()
            medications[index].streak += 1
        }
        
        gameStats.totalPoints += points
        gameStats.currentStreak = calculateCurrentStreak()
        gameStats.level = gameStats.calculatedLevel
        
        checkForAchievements()
    }
    
    func calculateCurrentStreak() -> Int {
        return medications.allSatisfy { !$0.isOverdue } ? gameStats.currentStreak + 1 : 0
    }
    
    func checkForAchievements() {
        for i in 0..<gameStats.achievements.count {
            if !gameStats.achievements[i].isEarned && gameStats.totalPoints >= gameStats.achievements[i].pointsRequired {
                gameStats.achievements[i].isEarned = true
            }
        }
    }
}

// MARK: - Today View (FIXED!)

struct TodayView: View {
    @ObservedObject var medicationManager: MedicationManager
    @State private var cameraSheetMedication: Medication? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                HeaderView(gameStats: medicationManager.gameStats)
                
                // Medication list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(medicationManager.medications) { medication in
                            MedicationCard(
                                medication: medication,
                                onTakePhoto: {
                                    print("📸 Opening camera for: \(medication.name)")
                                    cameraSheetMedication = medication
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("PillQuest")
        }
        .fullScreenCover(item: $cameraSheetMedication) { medication in
            CameraView(
                medication: medication,
                medicationManager: medicationManager,
                isPresented: Binding(
                    get: { cameraSheetMedication != nil },
                    set: { if !$0 { cameraSheetMedication = nil } }
                )
            )
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let gameStats: GameStats
    
    var body: some View {
        VStack {
            HStack {
                Text("🏆 PillQuest")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text("Level up your health game!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            HStack {
                StatItem(value: "\(gameStats.currentStreak)", label: "Day Streak")
                StatItem(value: "\(gameStats.totalPoints)", label: "Points")
                StatItem(value: "\(gameStats.level)", label: "Level")
            }
            .padding(.top, 12)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Medication Card

struct MedicationCard: View {
    let medication: Medication
    let onTakePhoto: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(medication.emoji) \(medication.name)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Next dose: \(medication.dosageTime, style: .time)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Button(action: onTakePhoto) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo & Verify")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Text("✨ +\(medication.points) points for on-time dose")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// ENHANCED CAMERA VIEW - Replace your CameraView with this

struct CameraView: View {
    let medication: Medication
    @ObservedObject var medicationManager: MedicationManager
    @Binding var isPresented: Bool
    @ObservedObject private var cameraManager = CameraManager.shared  // Use singleton!
    @State private var showingAnalysis = false
    @State private var capturedImage: UIImage?
    
    init(medication: Medication, medicationManager: MedicationManager, isPresented: Binding<Bool>) {
        self.medication = medication
        self.medicationManager = medicationManager
        self._isPresented = isPresented
        print("✅ CameraView INIT for medication: \(medication.name)")
        print("   🔍 Using shared CameraManager - isAuthorized: \(CameraManager.shared.isAuthorized)")
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // ENHANCED DEBUG OVERLAY
            VStack(spacing: 4) {
                Text("🔍 DEBUG STATUS")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
                
                HStack {
                    Text("Auth:")
                    Text(cameraManager.isAuthorized ? "✅" : "❌")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Running:")
                    Text(cameraManager.isSessionRunning ? "✅" : "❌")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Setup:")
                    Text(cameraManager.isSetup ? "✅" : "❌")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Inputs:")
                    Text("\(cameraManager.session.inputs.count)")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                HStack {
                    Text("Outputs:")
                    Text("\(cameraManager.session.outputs.count)")
                }
                .font(.caption2)
                .foregroundColor(.white)
                
                // MANUAL START BUTTON
                Button(action: {
                    print("🔵 MANUAL START BUTTON TAPPED")
                    cameraManager.forceSetupAndStart()
                }) {
                    Text("🚀 START CAMERA")
                        .font(.caption2.bold())
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.yellow)
                        .cornerRadius(4)
                }
                .padding(.top, 4)
            }
            .padding(8)
            .background(Color.red.opacity(0.9))
            .cornerRadius(8)
            .position(x: UIScreen.main.bounds.width / 2, y: 100)
            .zIndex(1000)
            
            if cameraManager.isAuthorized {
                // Camera Preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer().frame(height: 150) // Space for debug box
                    
                    // Top header
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Position pill in center")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(medication.name)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Center overlay guide
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                        .frame(width: 220, height: 220)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Place pill here")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack {
                        Button(action: {}) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundColor(.white)
                                )
                        }
                        .disabled(true)
                        
                        Spacer()
                        
                        // Capture button
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 6)
                                    .frame(width: 100, height: 100)
                            }
                        }
                        
                        Spacer()
                        
                        // Restart button
                        Button(action: {
                            print("🔄 RESTART BUTTON TAPPED")
                            cameraManager.stopSession()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                cameraManager.startSession()
                            }
                        }) {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.yellow)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            } else {
                // Camera permission request
                VStack(spacing: 30) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(spacing: 16) {
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("PillQuest needs camera access to verify your medications and help you stay on track.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Button("Enable Camera") {
                        cameraManager.requestPermission()
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Button("Not Now") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            print("📱 ========== CameraView APPEARED ==========")
            print("📱 Medication: \(medication.name)")
            print("📱 Using SHARED CameraManager instance")
            print("📱 isAuthorized: \(cameraManager.isAuthorized)")
            print("📱 isSetup: \(cameraManager.isSetup)")
            print("📱 isRunning: \(cameraManager.isSessionRunning)")
            
            if cameraManager.isAuthorized {
                print("📱 Already authorized - starting session")
                // Since camera manager persists, just start the session
                cameraManager.startSession()
            } else {
                print("📱 Not authorized yet - checking permission")
                cameraManager.checkPermission()
            }
        }
        .onDisappear {
            print("📱 ========== CameraView DISAPPEARED ==========")
            print("📱 Stopping session (CameraManager persists)")
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingAnalysis) {
            if let image = capturedImage {
                AnalysisResultView(
                    capturedImage: image,
                    medicationName: medication.name,
                    medicationPoints: medication.points,
                    onContinue: {
                        medicationManager.recordMedicationTaken(medication, points: medication.points)
                        showingAnalysis = false
                        isPresented = false
                    },
                    onRetake: {
                        showingAnalysis = false
                    },
                    onCancel: {
                        showingAnalysis = false
                        isPresented = false
                    }
                )
            }
        }
    }
    
    func capturePhoto() {
        print("📸 Capture button tapped")
        cameraManager.capturePhoto { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.capturedImage = image
                    self.showingAnalysis = true
                }
            }
        }
    }
}

// ENHANCED CAMERA MANAGER - SINGLETON (persists across views!)

class CameraManager: NSObject, ObservableObject {
    // Singleton instance - shared across all views
    static let shared = CameraManager()
    
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var isSetup = false
    
    private var photoOutput: AVCapturePhotoOutput?
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Private init to enforce singleton
    private override init() {
        super.init()
        print("🎬 ========== CameraManager SINGLETON INIT (only happens once!) ==========")
        checkPermission()
    }
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔐 Camera permission status raw value: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("✅ Camera AUTHORIZED")
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            print("🔧 Calling setupSession from checkPermission")
            setupSession()
        case .notDetermined:
            print("❓ Camera permission NOT DETERMINED - will request")
            requestPermission()
        case .denied:
            print("❌ Camera permission DENIED")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        case .restricted:
            print("🚫 Camera permission RESTRICTED")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        @unknown default:
            print("⚠️ Unknown camera permission status")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    func requestPermission() {
        print("🔐 Requesting camera permission...")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("🔐 Permission result: \(granted ? "✅ GRANTED" : "❌ DENIED")")
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
            if granted {
                self.setupSession()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startSession()
                }
            }
        }
    }
    
    // NEW: Force setup and start (for manual button)
    func forceSetupAndStart() {
        print("🚀 ========== FORCE SETUP AND START ==========")
        print("🚀 Current state:")
        print("   - isAuthorized: \(isAuthorized)")
        print("   - isSetup: \(isSetup)")
        print("   - isRunning: \(session.isRunning)")
        print("   - inputs: \(session.inputs.count)")
        print("   - outputs: \(session.outputs.count)")
        
        if !isAuthorized {
            print("❌ Not authorized - cannot start")
            return
        }
        
        if !isSetup {
            print("🔧 Not setup - calling setupSession")
            setupSession()
            // Wait for setup to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("🔧 After setup delay, calling startSession")
                self.startSession()
            }
        } else {
            print("✅ Already setup - calling startSession")
            startSession()
        }
    }
    
    func startSession() {
        print("🎥 ========== START SESSION CALLED ==========")
        print("   - isAuthorized: \(isAuthorized)")
        print("   - isSetup: \(isSetup)")
        print("   - isRunning: \(session.isRunning)")
        
        guard isAuthorized else {
            print("❌ Cannot start - not authorized")
            return
        }
        
        if !isSetup {
            print("⚠️ Not setup yet - calling setupSession first")
            setupSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("⏰ Retry startSession after setup")
                self.startSession()
            }
            return
        }
        
        // Don't guard on isRunning - always try to start for reliability
        sessionQueue.async {
            if self.session.isRunning {
                print("⚠️ Session already running - stopping first")
                self.session.stopRunning()
                // Brief pause to ensure clean stop
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            print("🎥 Starting session on background queue...")
            self.session.startRunning()
            let isRunning = self.session.isRunning
            print("🎥 Session.startRunning() completed. isRunning: \(isRunning)")
            
            DispatchQueue.main.async {
                self.isSessionRunning = isRunning
                print("✅ Published isSessionRunning updated to: \(isRunning)")
            }
        }
    }
    
    func stopSession() {
        print("🛑 ========== STOP SESSION CALLED ==========")
        print("   - isRunning before: \(session.isRunning)")
        
        // Always try to stop, even if we think it's not running
        sessionQueue.async {
            if self.session.isRunning {
                print("🛑 Stopping session...")
                self.session.stopRunning()
            } else {
                print("🛑 Session already stopped")
            }
            
            // Always update state to ensure consistency
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("✅ Session stopped, state updated")
            }
        }
    }
    
    private func setupSession() {
        print("⚙️ ========== SETUP SESSION CALLED ==========")
        
        if isSetup {
            print("⚠️ Already setup - skipping")
            return
        }
        
        guard isAuthorized else {
            print("❌ Cannot setup - not authorized")
            return
        }
        
        sessionQueue.async {
            print("⚙️ Setting up session on background queue...")
            
            self.session.beginConfiguration()
            print("⚙️ Session configuration began")
            
            // Set preset
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
                print("✅ Session preset set to .photo")
            } else {
                print("⚠️ Cannot set preset to .photo")
            }
            
            // Get camera
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ CRITICAL: No back camera found!")
                self.session.commitConfiguration()
                return
            }
            
            print("📷 Found camera: \(camera.localizedName)")
            print("📷 Camera uniqueID: \(camera.uniqueID)")
            
            // Create input
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                print("✅ Created AVCaptureDeviceInput")
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    print("✅ Camera input added to session")
                    print("   Total inputs: \(self.session.inputs.count)")
                } else {
                    print("❌ CRITICAL: Cannot add camera input to session")
                }
            } catch {
                print("❌ CRITICAL: Error creating camera input: \(error.localizedDescription)")
                self.session.commitConfiguration()
                return
            }
            
            // Create output
            let output = AVCapturePhotoOutput()
            print("✅ Created AVCapturePhotoOutput")
            
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
                output.isHighResolutionCaptureEnabled = true
                self.photoOutput = output
                print("✅ Photo output added to session")
                print("   Total outputs: \(self.session.outputs.count)")
            } else {
                print("❌ CRITICAL: Cannot add photo output to session")
            }
            
            self.session.commitConfiguration()
            print("✅ Session configuration committed")
            
            print("📊 Final session state:")
            print("   - Inputs: \(self.session.inputs.count)")
            print("   - Outputs: \(self.session.outputs.count)")
            print("   - Preset: \(self.session.sessionPreset.rawValue)")
            
            DispatchQueue.main.async {
                self.isSetup = true
                print("✅ Published isSetup updated to: true")
                print("⚙️ ========== SETUP COMPLETE ==========")
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        print("📸 ========== CAPTURE PHOTO CALLED ==========")
        
        guard let photoOutput = photoOutput else {
            print("❌ No photo output available")
            completion(nil)
            return
        }
        
        guard session.isRunning else {
            print("❌ Session not running - cannot capture")
            completion(nil)
            return
        }
        
        print("📸 Creating photo settings...")
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        print("📸 Capturing photo with settings...")
        
        currentPhotoDelegate = PhotoCaptureDelegate { image in
            if image != nil {
                print("✅ Photo captured successfully!")
            } else {
                print("❌ Photo capture failed")
            }
            completion(image)
        }
        
        photoOutput.capturePhoto(with: settings, delegate: currentPhotoDelegate!)
        print("📸 capturePhoto called on photoOutput")
    }
}
// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Photo Capture Delegate

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo error: \(error)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        completion(image)
    }
}

// MARK: - Analysis Result View

struct AnalysisResultView: View {
    let capturedImage: UIImage
    let medicationName: String
    let medicationPoints: Int
    let onContinue: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnalyzing = true
    
    var body: some View {
        VStack(spacing: 24) {
            Text("📊 Analyzing Photo")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .cornerRadius(16)
            
            if isAnalyzing {
                VStack(spacing: 16) {
                    Text("🔄")
                        .font(.system(size: 40))
                        .rotationEffect(.degrees(isAnalyzing ? 360 : 0))
                        .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnalyzing)
                    
                    Text("AI is analyzing your medication...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Text("✅")
                            .font(.system(size: 50))
                        
                        Text("Pill Verified!")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("Successfully identified \(medicationName)")
                            .font(.body)
                            .multilineTextAlignment(.center)
                        
                        Text("Confidence: 94%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                    
                    Text("🎉 +\(medicationPoints) Points Earned!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            
            Spacer()
            
            if !isAnalyzing {
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Continue - Record Dose")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Retake Photo", action: onRetake)
                            .foregroundColor(.blue)
                        
                        Button("Cancel", action: onCancel)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Progress View

struct ProgressView: View {
    @ObservedObject var medicationManager: MedicationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🏅 Recent Achievements")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(medicationManager.gameStats.achievements.filter { $0.isEarned }) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                    .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("📊 This Week")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        WeeklyProgressView()
                        
                        Text("Perfect week so far! 🎉")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.yellow, Color.orange]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(achievement.icon)
                        .font(.title3)
                )
            
            VStack(alignment: .leading) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct WeeklyProgressView: View {
    let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack {
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    if index < 6 {
                        Text("✓")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(index < 6 ? Color.green : Color.yellow)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
