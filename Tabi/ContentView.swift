import SwiftUI
import AVFoundation
import UIKit
import Vision

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
            
            MedicationProgressView(medicationManager: medicationManager)
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
    
    var formattedDosageTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dosageTime)
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
            Medication(name: "Doxycycline Hyclate", emoji: "🩺", dosageTime: createTime(hour: 14), points: 15)
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
    @State private var analysisResult: MedicationAnalyzer.AnalysisResult?  // Store analysis result
    @State private var hasAttemptedSetup = false  // Track if we've tried to setup
    
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
            
            // Always check permission status
            cameraManager.checkPermission()
            
            // If already authorized, proceed immediately
            if cameraManager.isAuthorized && !hasAttemptedSetup {
                print("📱 Already authorized on appear - setting up")
                setupAndStartCamera()
            }
        }
        .onChange(of: cameraManager.isAuthorized) { oldValue, newValue in
            print("📱 ========== isAuthorized CHANGED to: \(newValue) ==========")
            if newValue && !hasAttemptedSetup {
                print("📱 Authorization granted - setting up camera")
                setupAndStartCamera()
            }
        }
        .onDisappear {
            print("📱 ========== CameraView DISAPPEARED ==========")
            print("📱 Stopping session (CameraManager persists)")
            cameraManager.stopSession()
            hasAttemptedSetup = false  // Reset for next time
        }
        .sheet(isPresented: $showingAnalysis) {
            if let image = capturedImage {
                AnalysisResultView(
                    capturedImage: image,
                    medicationName: medication.name,
                    medicationPoints: medication.points,
                    analysisResult: analysisResult,  // Pass the analysis result
                    onContinue: {
                        medicationManager.recordMedicationTaken(medication, points: medication.points)
                        showingAnalysis = false
                        isPresented = false
                    },
                    onRetake: {
                        showingAnalysis = false
                        analysisResult = nil
                        capturedImage = nil
                    },
                    onCancel: {
                        showingAnalysis = false
                        isPresented = false
                    }
                )
            }
        }
    }
    
    func setupAndStartCamera() {
        print("📱 ========== setupAndStartCamera CALLED ==========")
        hasAttemptedSetup = true
        
        if cameraManager.isSetup {
            print("📱 Already setup - just starting session")
            cameraManager.startSession()
        } else {
            print("📱 Not setup yet - setting up then starting")
            cameraManager.setupSession {
                print("📱 Setup completed - now starting session")
                self.cameraManager.startSession()
            }
        }
    }
    
    func capturePhoto() {
        print("📸 Capture button tapped")
        cameraManager.capturePhoto { image in
            if let image = image {
                print("📸 Photo captured - starting AI analysis...")
                
                // Perform real AI analysis
                MedicationAnalyzer.shared.analyzePill(image: image, expectedMedication: self.medication) { result in
                    print("✅ Analysis complete:")
                    print("   - Match: \(result.isMatch)")
                    print("   - Confidence: \(Int(result.confidence * 100))%")
                    print("   - Detected text count: \(result.detectedText.count)")
                    print("   - Detected text: \(result.detectedText)")
                    print("   - Valid medication detected: \(result.validMedicationDetected)")
                    print("   - Matched terms: \(result.matchedTerms)")
                    print("   - Color: \(result.colorProfile)")
                    print("   - Shape detected: \(result.shapeDetected)")
                    
                    DispatchQueue.main.async {
                        self.capturedImage = image
                        self.analysisResult = result
                        self.showingAnalysis = true
                    }
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
        // DON'T call checkPermission here - let the view control the lifecycle
        // Just check the permission status and update the published property
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔐 Initial camera permission status: \(status.rawValue)")
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized)
            print("🔐 Initial isAuthorized set to: \(self.isAuthorized)")
        }
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
            // DON'T auto-setup here - let the caller handle it
            print("✅ Permission check complete - caller should handle setup/start")
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
                // Let the view's onChange handler take care of setup/start
                print("🔐 Published isAuthorized updated - view should react via onChange")
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
            setupSession {
                print("✅ Setup completed in forceSetupAndStart - now starting session")
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
        print("   - Published isSessionRunning: \(isSessionRunning)")
        
        guard isAuthorized else {
            print("❌ Cannot start - not authorized")
            return
        }
        
        if !isSetup {
            print("⚠️ Not setup yet - calling setupSession first")
            setupSession {
                print("✅ Setup completed in startSession - now starting")
                self.startSession()
            }
            return
        }
        
        sessionQueue.async {
            // Always check the actual session state, not just our published property
            if self.session.isRunning {
                print("⚠️ Session already running - stopping first for clean restart")
                self.session.stopRunning()
                // Brief pause to ensure clean stop
                Thread.sleep(forTimeInterval: 0.2)
            }
            
            print("🎥 Starting session on background queue...")
            print("   - Inputs before start: \(self.session.inputs.count)")
            print("   - Outputs before start: \(self.session.outputs.count)")
            
            self.session.startRunning()
            
            // Small delay to let the session actually start
            Thread.sleep(forTimeInterval: 0.1)
            
            let isRunning = self.session.isRunning
            print("🎥 Session.startRunning() completed. isRunning: \(isRunning)")
            
            if !isRunning {
                print("❌ WARNING: Session failed to start! Debugging info:")
                print("   - Inputs: \(self.session.inputs.count)")
                print("   - Outputs: \(self.session.outputs.count)")
                print("   - Preset: \(self.session.sessionPreset.rawValue)")
                
                // Try to diagnose the issue
                if self.session.inputs.isEmpty {
                    print("❌ PROBLEM: No inputs configured!")
                }
                if self.session.outputs.isEmpty {
                    print("❌ PROBLEM: No outputs configured!")
                }
            }
            
            DispatchQueue.main.async {
                self.isSessionRunning = isRunning
                print("✅ Published isSessionRunning updated to: \(isRunning)")
            }
        }
    }
    
    func stopSession() {
        print("🛑 ========== STOP SESSION CALLED ==========")
        print("   - isRunning before: \(session.isRunning)")
        print("   - Published isSessionRunning before: \(isSessionRunning)")
        
        // Always try to stop, even if we think it's not running
        sessionQueue.async {
            if self.session.isRunning {
                print("🛑 Stopping session...")
                self.session.stopRunning()
                
                // Wait a bit to ensure it's fully stopped
                Thread.sleep(forTimeInterval: 0.2)
                
                let stillRunning = self.session.isRunning
                print("🛑 After stop, isRunning: \(stillRunning)")
            } else {
                print("🛑 Session already stopped")
            }
            
            // Always update state to ensure consistency
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("✅ Session stopped, published state updated to false")
            }
        }
    }
    
    func setupSession(completion: (() -> Void)? = nil) {
        print("⚙️ ========== SETUP SESSION CALLED ==========")
        
        if isSetup {
            print("⚠️ Already setup - calling completion immediately on main thread")
            // Important: Call completion on main thread asynchronously to maintain consistency
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        
        guard isAuthorized else {
            print("❌ Cannot setup - not authorized")
            return
        }
        
        sessionQueue.async {
            print("⚙️ Setting up session on background queue...")
            
            // Remove any existing inputs/outputs to start fresh
            for input in self.session.inputs {
                self.session.removeInput(input)
                print("🗑️ Removed existing input")
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
                print("🗑️ Removed existing output")
            }
            
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
                
                // Call completion handler after state is updated
                completion?()
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

// MARK: - Medication Analyzer (AI Vision)

class MedicationAnalyzer {
    static let shared = MedicationAnalyzer()
    
    struct AnalysisResult {
        let isMatch: Bool
        let confidence: Double
        let detectedText: [String]
        let colorProfile: String
        let shapeDetected: Bool
        let validMedicationDetected: Bool
        let matchedTerms: [String]
    }
    
    func analyzePill(image: UIImage, expectedMedication: Medication, completion: @escaping (AnalysisResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(AnalysisResult(
                isMatch: false,
                confidence: 0.0,
                detectedText: [],
                colorProfile: "unknown",
                shapeDetected: false,
                validMedicationDetected: false,
                matchedTerms: []
            ))
            return
        }
        
        var detectedTexts: [String] = []
        var hasShape = false
        
        let dispatchGroup = DispatchGroup()
        
        // 1. Text Recognition (for pill markings/imprints)
        dispatchGroup.enter()
        recognizeText(in: cgImage) { texts in
            detectedTexts = texts
            dispatchGroup.leave()
        }
        
        // 2. Shape Detection (detect pill-like shapes)
        dispatchGroup.enter()
        detectPillShape(in: cgImage) { detected in
            hasShape = detected
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            // Analyze results
            let colorProfile = self.analyzeColor(image: image)
            
            // Enhanced matching with medication validation
            let validationResult = self.validateMedicationText(
                detectedTexts: detectedTexts,
                expectedMedication: expectedMedication
            )
            
            let confidence = self.calculateConfidence(
                textMatch: validationResult.isMatch,
                hasShape: hasShape,
                colorProfile: colorProfile,
                hasValidMedTerms: validationResult.hasValidTerms
            )
            
            let result = AnalysisResult(
                isMatch: confidence > 0.5,
                confidence: confidence,
                detectedText: detectedTexts,
                colorProfile: colorProfile,
                shapeDetected: hasShape,
                validMedicationDetected: validationResult.hasValidTerms,
                matchedTerms: validationResult.matchedTerms
            )
            
            completion(result)
        }
    }
    
    private func validateMedicationText(detectedTexts: [String], expectedMedication: Medication) -> (isMatch: Bool, hasValidTerms: Bool, matchedTerms: [String]) {
        let medKeywords = [
            "mg", "mcg", "tablet", "capsule", "pill", "dose",
            "rx", "vitamin", "daily", "once", "twice", "extended"
        ]
        
        var matchedTerms: [String] = []
        var hasValidTerms = false
        var isExactMatch = false
        
        // Combine all detected text for analysis
        let allText = detectedTexts.joined(separator: " ").lowercased()
        let expectedName = expectedMedication.name.lowercased()
        
        // Split medication name into individual words for multi-word matching
        let medicationWords = expectedName
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 } // Filter out short words like "mg", "d", etc.
        
        print("🔍 Medication words to match: \(medicationWords)")
        print("🔍 All detected text: \(allText)")
        
        // Categorize detected text by likelihood of being a pill imprint
        struct ScoredText {
            let text: String
            let score: Int
            let matchReason: String
        }
        
        var scoredTexts: [ScoredText] = []
        
        // Score each detected text
        for text in detectedTexts {
            var score = 0
            var reasons: [String] = []
            let lowerText = text.lowercased()
            
            // Check if contains medication name - HIGHEST PRIORITY
            let containsMedWord = medicationWords.contains { lowerText.contains($0) }
            if containsMedWord {
                score += 20 // Highest priority - always show medication name
                reasons.append("contains med name")
                isExactMatch = true
            }
            
            // Check for exact match
            if lowerText.contains(expectedName) {
                score += 25 // Even higher for exact match
                reasons.append("exact match")
                isExactMatch = true
            }
            
            // Contains medication keywords
            let containsKeyword = medKeywords.contains { lowerText.contains($0) }
            if containsKeyword {
                score += 8
                reasons.append("has med keyword")
                hasValidTerms = true
            }
            
            // Pill imprints are usually short (under 20 characters)
            if text.count < 20 {
                score += 2
                reasons.append("short")
            }
            
            // Often contain numbers (like dosage)
            if text.rangeOfCharacter(from: .decimalDigits) != nil {
                score += 3
                reasons.append("has numbers")
            }
            
            // Often in all caps or mostly caps
            let uppercaseCount = text.filter { $0.isUppercase }.count
            if Double(uppercaseCount) / Double(text.count) > 0.7 {
                score += 2
                reasons.append("mostly caps")
            }
            
            if score > 0 {
                scoredTexts.append(ScoredText(text: text, score: score, matchReason: reasons.joined(separator: ", ")))
                print("📊 Scored '\(text)': \(score) points (\(reasons.joined(separator: ", ")))")
            }
        }
        
        // Sort by score (highest first) and take top 5 most relevant (increased from 3)
        let topMatches = scoredTexts
            .sorted { $0.score > $1.score }
            .prefix(5)
        
        matchedTerms = topMatches.map { $0.text }
        
        // Also check combined text for medication words if we haven't found a match
        if !isExactMatch {
            for medWord in medicationWords {
                if allText.contains(medWord) {
                    isExactMatch = true
                    print("✅ Found medication word '\(medWord)' in combined text")
                    break
                }
            }
        }
        
        print("📊 Top matched terms: \(matchedTerms)")
        print("📊 Validation result: isMatch=\(isExactMatch), hasValidTerms=\(hasValidTerms)")
        
        return (isExactMatch, hasValidTerms, matchedTerms)
    }
    
    private func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            // Sort observations by vertical position (top to bottom)
            let sortedObservations = observations.sorted { obs1, obs2 in
                // Higher Y value = lower on screen (Vision uses bottom-left origin)
                obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
            }
            
            print("📝 === Text Detection (Top to Bottom) ===")
            
            var allTexts: [(text: String, position: Int, isBold: Bool)] = []
            
            for (index, observation) in sortedObservations.enumerated() {
                let candidates = observation.topCandidates(3)
                
                // Check if text appears bold
                let isBold = self.isBoldText(observation: observation, in: image)
                
                for candidate in candidates {
                    let text = candidate.string
                    let position = index
                    
                    allTexts.append((text, position, isBold))
                    
                    // Enhanced logging
                    let boldIndicator = isBold ? "📌 BOLD" : "📄 normal"
                    print("📝 Line \(position): '\(text)' [\(boldIndicator)]")
                }
            }
            
            // Remove duplicates and filter empty strings
            let uniqueTexts = Array(Set(allTexts.map { $0.text }))
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted()
            
            print("📝 Total unique texts detected: \(uniqueTexts.count)")
            completion(uniqueTexts)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }
    
    // Helper function to detect bold text based on pixel density
    private func isBoldText(observation: VNRecognizedTextObservation, in image: CGImage) -> Bool {
        let boundingBox = observation.boundingBox
        
        // Convert normalized coordinates to pixel coordinates
        let imageHeight = CGFloat(image.height)
        let imageWidth = CGFloat(image.width)
        
        let rect = CGRect(
            x: boundingBox.origin.x * imageWidth,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )
        
        // Crop to text region
        guard let croppedImage = image.cropping(to: rect) else { return false }
        
        // Analyze pixel density - bold text has more dark pixels
        let density = calculatePixelDensity(in: croppedImage)
        
        // Threshold: bold text typically has density > 0.35
        return density > 0.35
    }
    
    private func calculatePixelDensity(in image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0.0
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0.0 }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var darkPixels = 0
        let sampleRate = 2 // Check every 2nd pixel for performance
        
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let offset = (y * width + x) * bytesPerPixel
                let r = Int(buffer[offset])
                let g = Int(buffer[offset + 1])
                let b = Int(buffer[offset + 2])
                
                // Calculate brightness
                let brightness = (r + g + b) / 3
                
                // Dark pixels (likely text)
                if brightness < 128 {
                    darkPixels += 1
                }
            }
        }
        
        let sampledPixels = (width / sampleRate) * (height / sampleRate)
        return Double(darkPixels) / Double(sampledPixels)
    }
    
    private func detectPillShape(in image: CGImage, completion: @escaping (Bool) -> Void) {
        let request = VNDetectContoursRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNContoursObservation] else {
                completion(false)
                return
            }
            
            // If we detect any contours, it's likely a pill
            let hasContours = !observations.isEmpty
            print("🔍 Shape detected: \(hasContours)")
            completion(hasContours)
        }
        
        request.contrastAdjustment = 1.5
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }
    
    private func analyzeColor(image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "unknown" }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                   y: ciImage.extent.origin.y,
                                   z: ciImage.extent.size.width,
                                   w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                   parameters: [kCIInputImageKey: ciImage,
                                              kCIInputExtentKey: extentVector]) else {
            return "unknown"
        }
        
        guard let outputImage = filter.outputImage else { return "unknown" }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        // Simple color classification
        let r = bitmap[0]
        let g = bitmap[1]
        let b = bitmap[2]
        
        let color: String
        if r > 200 && g > 200 && b > 200 {
            color = "white"
        } else if r > 150 && g < 100 && b < 100 {
            color = "red"
        } else if r < 100 && g < 100 && b > 150 {
            color = "blue"
        } else if r > 150 && g > 150 && b < 100 {
            color = "yellow"
        } else if r > 150 && g > 100 && b < 100 {
            color = "orange"
        } else {
            color = "other"
        }
        
        print("🎨 Detected color: \(color)")
        return color
    }
    
    private func calculateConfidence(textMatch: Bool, hasShape: Bool, colorProfile: String, hasValidMedTerms: Bool) -> Double {
        var confidence = 0.2 // Base confidence for taking a photo
        
        if textMatch { confidence += 0.5 }  // Exact medication name match - strongest indicator
        else if hasValidMedTerms { confidence += 0.2 }  // Has medication-related terms
        
        if hasShape { confidence += 0.2 }    // Shape detected
        if colorProfile != "unknown" { confidence += 0.1 }  // Color identified
        
        return min(confidence, 1.0)
    }
}

// MARK: - Analysis Result View

struct AnalysisResultView: View {
    let capturedImage: UIImage
    let medicationName: String
    let medicationPoints: Int
    let analysisResult: MedicationAnalyzer.AnalysisResult?
    let onContinue: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnalyzing = true
    @State private var showScheduleInfo = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text(isAnalyzing ? "📊 Analyzing Photo" : "Results")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isAnalyzing ? Color.gray : (analysisResult?.isMatch == true ? Color.green : Color.orange), lineWidth: 3)
                )
            
            if isAnalyzing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("AI is analyzing your medication...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Checking pill shape, color, and markings")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            } else if let result = analysisResult {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Text(result.isMatch ? "✅" : "⚠️")
                            .font(.system(size: 50))
                        
                        Text(result.isMatch ? "Pill Verified!" : "Needs Review")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(result.isMatch ? .green : .orange)
                        
                        if result.isMatch && result.validMedicationDetected {
                            Text("Successfully identified \(medicationName)")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text("Valid medication markings detected")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if result.isMatch {
                            Text("Successfully identified \(medicationName)")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else if result.validMedicationDetected {
                            Text("Medication detected but please verify")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text("Markings don't exactly match \(medicationName)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("Please verify this is \(medicationName)")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Confidence bar
                        VStack(spacing: 4) {
                            HStack {
                                Text("Confidence:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(result.confidence * 100))%")
                                    .font(.caption.bold())
                                    .foregroundColor(result.isMatch ? .green : .orange)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(result.isMatch ? Color.green : Color.orange)
                                        .frame(width: geometry.size.width * CGFloat(result.confidence), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.horizontal)
                        
                        // Detection details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.shapeDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.shapeDetected ? .green : .gray)
                                    .font(.caption)
                                Text("Pill shape detected")
                                    .font(.caption)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.colorProfile != "unknown" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.colorProfile != "unknown" ? .green : .gray)
                                    .font(.caption)
                                Text("Color: \(result.colorProfile.capitalized)")
                                    .font(.caption)
                                Spacer()
                            }
                            
                            Divider()
                            
                            // Text detection with multi-line support
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: !result.detectedText.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(!result.detectedText.isEmpty ? .green : .gray)
                                        .font(.caption)
                                    Text("Detected Text:")
                                        .font(.caption.bold())
                                    Spacer()
                                }
                                
                                if result.detectedText.isEmpty {
                                    Text("No text markings detected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                } else {
                                    ForEach(result.detectedText.prefix(5), id: \.self) { text in
                                        HStack(spacing: 4) {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(text)
                                                .font(.caption)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.leading, 20)
                                    }
                                    
                                    if result.detectedText.count > 5 {
                                        Text("+ \(result.detectedText.count - 5) more")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 24)
                                    }
                                }
                            }
                            
                            // Show matched medication terms if any
                            if !result.matchedTerms.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Matched Terms:")
                                            .font(.caption.bold())
                                            .foregroundColor(.green)
                                    }
                                    
                                    ForEach(result.matchedTerms.prefix(3), id: \.self) { term in
                                        Text("✓ \(term)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(.leading, 24)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(result.isMatch ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    
                    if result.isMatch {
                        Text("🎉 +\(medicationPoints) Points Earned!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    } else {
                        Text("You can still record if you're confident this is the right medication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            if !isAnalyzing {
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text(analysisResult?.isMatch == true ? "Continue - Record Dose ✓" : "Record Anyway")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(analysisResult?.isMatch == true ? Color.green : Color.orange)
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
            // Simulate processing time for AI analysis
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Medication Progress View

struct MedicationProgressView: View {
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
