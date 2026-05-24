import SwiftUI

// MARK: - Camera View (pill verification — used when logging a dose for an existing medication)

#if targetEnvironment(simulator)
private let kIsSimulator = true
#else
private let kIsSimulator = false
#endif

struct CameraView: View {
    let medication: Medication
    @ObservedObject var medicationManager: MedicationManager
    @Binding var isPresented: Bool
    @State private var showingAnalysis = false
    @State private var capturedImage: UIImage?
    @State private var analysisResult: PillVerifier.AnalysisResult?
    @ObservedObject private var cameraManager = CameraManager.shared
    @State private var hasAttemptedSetup = false
    @State private var simulatorImage: UIImage?

    var body: some View {
        let _ = print(">>> CameraView body - kIsSimulator: \(kIsSimulator), isAuthorized: \(cameraManager.isAuthorized)")
        return ZStack {
            // Background layer
            Group {
                if kIsSimulator {
                    if let img = simulatorImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Color.red
                        Text("No image loaded").foregroundColor(.white).font(.title)
                    }
                } else if cameraManager.isAuthorized {
                    CameraPreviewView(cameraManager: cameraManager)
                } else {
                    permissionView
                }
            }
            .ignoresSafeArea()
            
            // Camera overlay (only when camera is ready)
            if kIsSimulator || cameraManager.isAuthorized {
                let _ = print(">>> Rendering overlay - condition met")
                cameraOverlay(onCapture: kIsSimulator ? simulatorCapture : deviceCapture)
            } else {
                let _ = print(">>> NOT rendering overlay")
            }
            
            // Back button - ALWAYS visible
            VStack {
                HStack {
                    Button(action: { 
                        print(">>> Back button tapped")
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
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            if kIsSimulator {
                let path = Bundle.main.path(forResource: "Med_Hydrocodone", ofType: "jpeg")
                simulatorImage = path.flatMap { UIImage(contentsOfFile: $0) }
                return
            }
            cameraManager.checkPermission()
            if cameraManager.isAuthorized && !hasAttemptedSetup { setupAndStartCamera() }
        }
        .onChange(of: cameraManager.isAuthorized) { _, newValue in
            guard !kIsSimulator, newValue, !hasAttemptedSetup else { return }
            setupAndStartCamera()
        }
        .onDisappear {
            guard !kIsSimulator else { return }
            cameraManager.stopSession()
            hasAttemptedSetup = false
        }
        .sheet(isPresented: $showingAnalysis) {
            if let image = capturedImage {
                AnalysisResultView(
                    capturedImage: image,
                    medicationName: medication.name,
                    medicationPoints: medication.points,
                    analysisResult: analysisResult,
                    onContinue: {
                        medicationManager.recordMedicationTaken(medication, points: medication.points)
                        showingAnalysis = false
                        isPresented = false
                    },
                    onRetake: { showingAnalysis = false; analysisResult = nil; capturedImage = nil },
                    onCancel: { showingAnalysis = false; isPresented = false }
                )
            }
        }
    }

    // MARK: - Simulator

    private func simulatorCapture() {
        guard let image = simulatorImage else { return }
        PillVerifier.shared.analyzePill(image: image, expectedMedication: medication) { result in
            DispatchQueue.main.async {
                self.capturedImage = image
                self.analysisResult = result
                self.showingAnalysis = true
            }
        }
    }

    // MARK: - Device

    private func setupAndStartCamera() {
        hasAttemptedSetup = true
        if cameraManager.isSetup { cameraManager.startSession() }
        else { cameraManager.setupSession { self.cameraManager.startSession() } }
    }

    private func deviceCapture() {
        cameraManager.capturePhoto { image in
            guard let image else { return }
            PillVerifier.shared.analyzePill(image: image, expectedMedication: self.medication) { result in
                DispatchQueue.main.async {
                    self.capturedImage = image
                    self.analysisResult = result
                    self.showingAnalysis = true
                }
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.fill").font(.system(size: 60)).foregroundColor(.white.opacity(0.7))
            VStack(spacing: 16) {
                Text("Camera Access Required").font(.title2.bold()).foregroundColor(.white)
                Text("PillQuest needs camera access to verify your medications and help you stay on track.")
                    .font(.body).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Button("Enable Camera") { cameraManager.requestPermission() }
                .font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).padding()
                .background(Color.white).cornerRadius(12).padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.subheadline).foregroundColor(.white.opacity(0.8))
            Button("Not Now") { isPresented = false }.font(.subheadline).foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Shared UI

    private func cameraOverlay(onCapture: @escaping () -> Void) -> some View {
        let _ = print(">>> cameraOverlay is being rendered")
        return VStack {
            HStack {
                Button(action: { 
                    print(">>> Back button tapped")
                    isPresented = false 
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))  // Changed to red for visibility
                        .clipShape(Circle())
                }
                .frame(width: 60, height: 60)  // Explicit size
                Spacer()
                VStack {
                    Text("Position pill in center").font(.headline).foregroundColor(.white)
                    Text(medication.name).font(.subheadline).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Circle().fill(Color.clear).frame(width: 44, height: 44)
            }
            .padding()
            .background(Color.blue.opacity(0.3))  // Debug background

            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                .frame(width: 220, height: 220)
                .overlay(VStack(spacing: 8) {
                    Image(systemName: "pills.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.7))
                    Text("Place pill here").font(.caption).foregroundColor(.white.opacity(0.8))
                })

            Spacer()

            Button(action: onCapture) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 80, height: 80)
                    Circle().stroke(Color.white, lineWidth: 6).frame(width: 100, height: 100)
                }
            }
            .padding(.bottom, 50)
        }
    }
}
