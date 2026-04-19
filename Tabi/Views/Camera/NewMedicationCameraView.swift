import SwiftUI

// MARK: - New Medication Camera View (scan prescription label to add a medication)

private struct CaptureResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let info: DetectedMedicationInfo
}

struct NewMedicationCameraView: View {
    @ObservedObject var medicationManager: MedicationManager
    @Binding var isPresented: Bool
    @ObservedObject private var cameraManager = CameraManager.shared
    @State private var captureResult: CaptureResult?
    @State private var hasAttemptedSetup = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cameraManager.isAuthorized {
                CameraPreviewView(cameraManager: cameraManager).ignoresSafeArea()
                VStack {
                    HStack {
                        Button { isPresented = false } label: {
                            Image(systemName: "xmark").font(.title2).foregroundColor(.white)
                                .padding().background(Color.black.opacity(0.5)).clipShape(Circle())
                        }
                        Spacer()
                        VStack {
                            Text("Scan Prescription Label").font(.headline).foregroundColor(.white)
                            Text("Position label in frame").font(.caption).foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Circle().fill(Color.clear).frame(width: 44, height: 44)
                    }
                    .padding()
                    .background(LinearGradient(colors: [Color.black.opacity(0.7), Color.clear], startPoint: .top, endPoint: .bottom))
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.tabiOrange.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                        .frame(width: 300, height: 200)
                        .overlay(VStack(spacing: 8) {
                            Image(systemName: "doc.text.viewfinder").font(.system(size: 40)).foregroundColor(.tabiOrange.opacity(0.85))
                            Text("Position label here").font(.caption).foregroundColor(.white.opacity(0.8))
                        })
                    Spacer()
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle().fill(Color.tabiOrange).frame(width: 80, height: 80)
                            Circle().stroke(Color.tabiOrange.opacity(0.4), lineWidth: 6).frame(width: 100, height: 100)
                            Image(systemName: "camera.fill").font(.title2).foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 50)
                }
            } else {
                VStack(spacing: 30) {
                    Image(systemName: "camera.fill").font(.system(size: 60)).foregroundColor(.tabiOrange)
                    VStack(spacing: 16) {
                        Text("Camera Access Required").font(.title2.bold()).foregroundColor(.white)
                        Text("TABI needs camera access to scan your medication labels.")
                            .font(.body).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    Button("Enable Camera") { cameraManager.requestPermission() }
                        .font(.headline).foregroundColor(.tabiOrange)
                        .frame(maxWidth: .infinity).padding().background(Color.white).cornerRadius(12).padding(.horizontal, 32)
                }
            }
        }
        .onAppear { cameraManager.checkPermission(); if cameraManager.isAuthorized && !hasAttemptedSetup { setupAndStartCamera() } }
        .onChange(of: cameraManager.isAuthorized) { _, v in if v && !hasAttemptedSetup { setupAndStartCamera() } }
        .onDisappear { cameraManager.stopSession(); hasAttemptedSetup = false }
        .sheet(item: $captureResult) { result in
            DetectedMedicationView(image: result.image, detectedInfo: result.info,
                onSave: { finalInfo in
                    let idx = medicationManager.medications.count
                    let newMed = Medication(name: finalInfo.brandName.isEmpty ? finalInfo.genericName : finalInfo.brandName, genericName: finalInfo.genericName, type: "Tablet", emoji: "💊", dosageTime: finalInfo.scheduleTime, dosage: finalInfo.dosage, scheduleLabel: "Every Day", points: 10, colorIndex: idx)
                    medicationManager.medications.append(newMed)
                    let schedule = MedicationScheduleParser.parse(info: finalInfo, medication: newMed)
                    CalendarPersistenceManager.shared.save(schedule: schedule)
                    NotificationScheduler.shared.schedule(for: schedule)
                    captureResult = nil; isPresented = false
                },
                onCancel: { captureResult = nil })
        }
    }

    func setupAndStartCamera() {
        hasAttemptedSetup = true
        if cameraManager.isSetup { cameraManager.startSession() }
        else { cameraManager.setupSession { self.cameraManager.startSession() } }
    }

    func capturePhoto() {
        cameraManager.capturePhoto { image in
            self.cameraManager.stopSession()
            if let image = image {
                LabelScanner.shared.scanLabel(image: image) { info in
                    DispatchQueue.main.async {
                        self.captureResult = CaptureResult(image: image, info: info)
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cameraManager.startSession() }
            }
        }
    }
}
