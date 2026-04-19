import SwiftUI

// MARK: - Camera View (pill verification — used when logging a dose for an existing medication)

struct CameraView: View {
    let medication: Medication
    @ObservedObject var medicationManager: MedicationManager
    @Binding var isPresented: Bool
    @ObservedObject private var cameraManager = CameraManager.shared
    @State private var showingAnalysis = false
    @State private var capturedImage: UIImage?
    @State private var analysisResult: PillVerifier.AnalysisResult?
    @State private var hasAttemptedSetup = false

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

            // DEBUG OVERLAY
            VStack(spacing: 4) {
                Text("🔍 DEBUG STATUS").font(.caption.bold()).foregroundColor(.yellow)
                HStack { Text("Auth:"); Text(cameraManager.isAuthorized ? "✅" : "❌") }.font(.caption2).foregroundColor(.white)
                HStack { Text("Running:"); Text(cameraManager.isSessionRunning ? "✅" : "❌") }.font(.caption2).foregroundColor(.white)
                HStack { Text("Setup:"); Text(cameraManager.isSetup ? "✅" : "❌") }.font(.caption2).foregroundColor(.white)
                HStack { Text("Inputs:"); Text("\(cameraManager.session.inputs.count)") }.font(.caption2).foregroundColor(.white)
                HStack { Text("Outputs:"); Text("\(cameraManager.session.outputs.count)") }.font(.caption2).foregroundColor(.white)
                Button(action: { print("🔵 MANUAL START BUTTON TAPPED"); cameraManager.forceSetupAndStart() }) {
                    Text("🚀 START CAMERA").font(.caption2.bold()).foregroundColor(.black).padding(4).background(Color.yellow).cornerRadius(4)
                }
                .padding(.top, 4)
            }
            .padding(8)
            .background(Color.red.opacity(0.9))
            .cornerRadius(8)
            .position(x: UIScreen.main.bounds.width / 2, y: 100)
            .zIndex(1000)

            if cameraManager.isAuthorized {
                CameraPreviewView(cameraManager: cameraManager).ignoresSafeArea()

                VStack {
                    Spacer().frame(height: 150)

                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark").font(.title2).foregroundColor(.white)
                                .padding().background(Color.black.opacity(0.5)).clipShape(Circle())
                        }
                        Spacer()
                        VStack {
                            Text("Position pill in center").font(.headline).foregroundColor(.white)
                            Text(medication.name).font(.subheadline).foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Circle().fill(Color.clear).frame(width: 44, height: 44)
                    }
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]), startPoint: .top, endPoint: .bottom))

                    Spacer()

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                        .frame(width: 220, height: 220)
                        .overlay(VStack(spacing: 8) {
                            Image(systemName: "pills.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.7))
                            Text("Place pill here").font(.caption).foregroundColor(.white.opacity(0.8))
                        })

                    Spacer()

                    HStack {
                        Button(action: {}) {
                            RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2).frame(width: 50, height: 50)
                                .overlay(Image(systemName: "photo.on.rectangle").foregroundColor(.white))
                        }
                        .disabled(true)

                        Spacer()

                        Button(action: capturePhoto) {
                            ZStack {
                                Circle().fill(Color.white).frame(width: 80, height: 80)
                                Circle().stroke(Color.white, lineWidth: 6).frame(width: 100, height: 100)
                            }
                        }

                        Spacer()

                        Button(action: {
                            print("🔄 RESTART BUTTON TAPPED")
                            cameraManager.stopSession()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { cameraManager.startSession() }
                        }) {
                            Circle().stroke(Color.yellow, lineWidth: 2).frame(width: 50, height: 50)
                                .overlay(Image(systemName: "arrow.clockwise").foregroundColor(.yellow))
                        }
                    }
                    .padding(.horizontal, 40).padding(.bottom, 50)
                }
            } else {
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
        }
        .onAppear {
            print("📱 CameraView APPEARED for: \(medication.name)")
            cameraManager.checkPermission()
            if cameraManager.isAuthorized && !hasAttemptedSetup { setupAndStartCamera() }
        }
        .onChange(of: cameraManager.isAuthorized) { _, newValue in
            if newValue && !hasAttemptedSetup { setupAndStartCamera() }
        }
        .onDisappear {
            print("📱 CameraView DISAPPEARED")
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

    func setupAndStartCamera() {
        print("📱 setupAndStartCamera CALLED")
        hasAttemptedSetup = true
        if cameraManager.isSetup { cameraManager.startSession() }
        else { cameraManager.setupSession { self.cameraManager.startSession() } }
    }

    func capturePhoto() {
        print("📸 Capture button tapped")
        cameraManager.capturePhoto { image in
            if let image = image {
                PillVerifier.shared.analyzePill(image: image, expectedMedication: self.medication) { result in
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
