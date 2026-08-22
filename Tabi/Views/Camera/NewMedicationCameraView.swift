import SwiftUI

// MARK: - New Medication Camera View (scan prescription label to add a medication)

private struct CaptureResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let info: DetectedMedicationInfo
}

#if targetEnvironment(simulator)
private let kNewMedIsSimulator = true
#else
private let kNewMedIsSimulator = false
#endif

struct NewMedicationCameraView: View {
    @ObservedObject var medicationManager: MedicationStore
    @Binding var isPresented: Bool
    @ObservedObject private var cameraManager = CameraManager.shared
    @State private var captureResult: CaptureResult?
    @State private var hasAttemptedSetup = false
    @State private var simulatorImage: UIImage?
    @AppStorage("hasSeenGeminiDisclosure") private var hasSeenGeminiDisclosure = false
    @State private var showGeminiTooltip = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            Group {
                if kNewMedIsSimulator {
                    if let img = simulatorImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Color.red
                    }
                } else if cameraManager.isAuthorized {
                    CameraPreviewView(cameraManager: cameraManager)
                } else {
                    permissionView
                }
            }
            .ignoresSafeArea()

            if kNewMedIsSimulator || cameraManager.isAuthorized {
                scanOverlay
            }

            // Back button — rendered last so it sits above scanOverlay's gradient.
            // Shown in every state (including permission view) so the user can always exit.
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            .zIndex(1)
        }
        .onAppear {
            // Auto-opens the tooltip once, the first time this screen is
            // ever seen; the info icon stays available afterward so someone
            // can re-read it later, but it won't pop up unprompted again.
            if !hasSeenGeminiDisclosure {
                showGeminiTooltip = true
                hasSeenGeminiDisclosure = true
            }
            if kNewMedIsSimulator {
                let path = Bundle.main.path(forResource: "Med_Hydrocodone", ofType: "jpeg")
                simulatorImage = path.flatMap { UIImage(contentsOfFile: $0) }
                return
            }
            cameraManager.checkPermission()
            if cameraManager.isAuthorized && !hasAttemptedSetup { setupAndStartCamera() }
        }
        .onChange(of: cameraManager.isAuthorized) { _, v in
            guard !kNewMedIsSimulator, v, !hasAttemptedSetup else { return }
            setupAndStartCamera()
        }
        .onDisappear {
            guard !kNewMedIsSimulator else { return }
            cameraManager.stopSession()
            hasAttemptedSetup = false
        }
        .sheet(item: $captureResult) { result in
            DetectedMedicationView(image: result.image, detectedInfo: result.info,
                onSave: { finalInfo in
                    let idx = medicationManager.medications.count
                    let newMed = Medication(
                        name: finalInfo.brandName.isEmpty ? finalInfo.genericName : finalInfo.brandName,
                        genericName: finalInfo.genericName,
                        type: "Tablet", emoji: "💊",
                        dosage: finalInfo.dosage,
                        scheduleLabel: "Every Day",
                        points: 10,
                        frequencyPerDay: finalInfo.frequencyPerDay,
                        doseTimeMinutes: MedicationScheduleParser.defaultDoseTimeMinutes(for: finalInfo.frequencyPerDay),
                        takenToday: 0,
                        lastTaken: nil,
                        colorIndex: idx
                    )
                    medicationManager.add(newMed)
                    let schedule = MedicationScheduleParser.parse(info: finalInfo, medication: newMed)
                    CalendarStore.shared.save(schedule: schedule)
                    NotificationScheduler.shared.schedule(for: schedule)
                    captureResult = nil; isPresented = false
                },
                onCancel: { captureResult = nil })
        }
    }

    private var scanOverlay: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Scan Prescription Label")
                    .font(.headline).foregroundColor(.white)
                Text(kNewMedIsSimulator ? "Simulator — test image" : "Position label in frame")
                    .font(.caption)
                    .foregroundColor(kNewMedIsSimulator ? .tabiOrange : .white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [Color.black.opacity(0.8), Color.clear],
                               startPoint: .top, endPoint: .bottom)
            )

            Spacer()

            if !kNewMedIsSimulator {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.tabiOrange.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                    .frame(width: 300, height: 200)
                    .overlay(VStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 40)).foregroundColor(.tabiOrange.opacity(0.85))
                        Text("Position label here")
                            .font(.caption).foregroundColor(.white.opacity(0.8))
                    })
                Spacer()
            }

            if showGeminiTooltip {
                geminiTooltip
                    .padding(.bottom, 14)
            }

            // Explicit pixel width via UIScreen, same as geminiTooltip below -
            // this row's trailing Spacer did not actually bound the info
            // button to the screen edge under normal flexible HStack sizing
            // (it rendered mostly off the right edge of the screen), so this
            // sidesteps that by not depending on proposed-size propagation.
            HStack(spacing: 12) {
                // Balances the info button's width on the other side so the
                // shutter button stays visually centered.
                Color.clear.frame(width: 32, height: 32)
                Spacer()
                Button(action: kNewMedIsSimulator ? simulatorCapture : deviceCapture) {
                    ZStack {
                        Circle().fill(Color.tabiOrange).frame(width: 80, height: 80)
                        Circle().stroke(Color.tabiOrange.opacity(0.4), lineWidth: 6).frame(width: 100, height: 100)
                        Image(systemName: "camera.fill").font(.title2).foregroundColor(.white)
                    }
                }
                .accessibilityLabel("Capture photo")
                Spacer()
                Button {
                    withAnimation { showGeminiTooltip.toggle() }
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .accessibilityLabel("About AI label processing")
            }
            .frame(width: UIScreen.main.bounds.width - 48)
            .padding(.bottom, 50)
        }
    }

    private var geminiTooltip: some View {
        // Explicit pixel width via UIScreen rather than a flexible frame -
        // this view overflowed both screen edges on a single unwrapped line
        // under every flexible-frame/.overlay/GeometryReader approach tried,
        // so this sidesteps the ambiguity by not depending on any
        // proposed-size propagation at all.
        let bubbleWidth = UIScreen.main.bounds.width - 48

        return Text("Your label's text is sent to a secure AI service to identify the medication, dosage, and schedule. Tap the ⓘ anytime to see this again.")
            .font(.caption)
            .foregroundColor(.white)
            .padding(12)
            .frame(width: bubbleWidth, alignment: .leading)
            .background(Color.black.opacity(0.85))
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func simulatorCapture() {
        guard let image = simulatorImage else { return }
        LabelScanner.shared.scanLabel(image: image) { info in
            DispatchQueue.main.async { self.captureResult = CaptureResult(image: image, info: info) }
        }
    }

    private func setupAndStartCamera() {
        hasAttemptedSetup = true
        if cameraManager.isSetup { cameraManager.startSession() }
        else { cameraManager.setupSession { self.cameraManager.startSession() } }
    }

    private func deviceCapture() {
        cameraManager.capturePhoto { image in
            self.cameraManager.stopSession()
            if let image = image {
                LabelScanner.shared.scanLabel(image: image) { info in
                    DispatchQueue.main.async { self.captureResult = CaptureResult(image: image, info: info) }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cameraManager.startSession() }
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.fill").font(.system(size: 60)).foregroundColor(.tabiOrange)
            VStack(spacing: 16) {
                Text("Camera Access Required").font(.title2.bold()).foregroundColor(.white)
                Text("TABI needs camera access to scan your medication labels.")
                    .font(.body).foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Button("Enable Camera") { cameraManager.requestPermission() }
                .font(.headline).foregroundColor(.tabiOrange)
                .frame(maxWidth: .infinity).padding()
                .background(Color.white).cornerRadius(12).padding(.horizontal, 32)
        }
    }
}
