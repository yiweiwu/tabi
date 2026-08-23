import AVFoundation
import SwiftUI

// MARK: - Camera Manager (Singleton)

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()

    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var isSetup = false

    private var photoOutput: AVCapturePhotoOutput?
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    private var captureDevice: AVCaptureDevice?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    // Deployment target is iOS 18.5, so the rotation coordinator (iOS 17+) is
    // always available. A hardcoded videoRotationAngle is wrong: the angle
    // that maps the sensor's native (landscape) output to an upright portrait
    // photo depends on the camera's physical mounting and isn't a constant
    // like 0 - the coordinator computes the correct value.
    //
    // Binding the coordinator to the preview layer (instead of `nil`) is what
    // lets AVFoundation keep the preview's connection rotation angle in sync
    // going forward on its own. A one-time read only produced a value that
    // was correct at that instant - it went stale (and the preview rotated
    // 90°) as soon as the video device's active format changed, which
    // `capturePhoto` does internally for the still-image capture.
    func attachPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer) {
        // `makeUIView` can run before `setupSession`'s async block has
        // assigned `captureDevice` (it runs as soon as `isAuthorized` flips
        // true, independent of setup completing) — safe to no-op and let
        // `updateUIView` retry once the device is actually available.
        guard rotationCoordinator == nil, let captureDevice else { return }
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: captureDevice, previewLayer: previewLayer)
    }

    private override init() {
        super.init()
        print("🎬 ========== CameraManager SINGLETON INIT (only happens once!) ==========")
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
            DispatchQueue.main.async { self.isAuthorized = true }
        case .notDetermined:
            print("❓ Camera permission NOT DETERMINED - will request")
            requestPermission()
        case .denied:
            print("❌ Camera permission DENIED")
            DispatchQueue.main.async { self.isAuthorized = false }
        case .restricted:
            print("🚫 Camera permission RESTRICTED")
            DispatchQueue.main.async { self.isAuthorized = false }
        @unknown default:
            print("⚠️ Unknown camera permission status")
            DispatchQueue.main.async { self.isAuthorized = false }
        }
    }

    func requestPermission() {
        print("🔐 Requesting camera permission...")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("🔐 Permission result: \(granted ? "✅ GRANTED" : "❌ DENIED")")
            DispatchQueue.main.async {
                self.isAuthorized = granted
                print("🔐 Published isAuthorized updated - view should react via onChange")
            }
        }
    }

    func forceSetupAndStart() {
        print("🚀 ========== FORCE SETUP AND START ==========")
        guard isAuthorized else { print("❌ Not authorized - cannot start"); return }
        if !isSetup {
            setupSession { self.startSession() }
        } else {
            startSession()
        }
    }

    func startSession() {
        print("🎥 ========== START SESSION CALLED ==========")
        guard isAuthorized else { print("❌ Cannot start - not authorized"); return }

        if !isSetup {
            setupSession { self.startSession() }
            return
        }

        sessionQueue.async {
            if self.session.isRunning {
                print("⚠️ Session already running, skipping start")
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
                return
            }
            self.session.startRunning()
            // Give it a moment to actually start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let isRunning = self.session.isRunning
                print("🎥 Session.startRunning() completed. isRunning: \(isRunning)")
                self.isSessionRunning = isRunning
                print("✅ Published isSessionRunning updated to: \(isRunning)")
            }
        }
    }

    func stopSession() {
        print("🛑 ========== STOP SESSION CALLED ==========")
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("✅ Session stopped, published state updated to false")
            }
        }
    }

    func setupSession(completion: (() -> Void)? = nil) {
        print("⚙️ ========== SETUP SESSION CALLED ==========")
        if isSetup {
            DispatchQueue.main.async { completion?() }
            return
        }
        guard isAuthorized else { print("❌ Cannot setup - not authorized"); return }

        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.isSetup = true
            completion?()
        }
        return
        #endif

        sessionQueue.async {
            for input in self.session.inputs { self.session.removeInput(input) }
            for output in self.session.outputs { self.session.removeOutput(output) }

            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.photo) { self.session.sessionPreset = .photo }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ CRITICAL: No back camera found!")
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) { self.session.addInput(input) }
                self.captureDevice = camera
            } catch {
                print("❌ CRITICAL: Error creating camera input: \(error.localizedDescription)")
                self.session.commitConfiguration()
                return
            }

            let output = AVCapturePhotoOutput()
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
                if #available(iOS 16.0, *) {
                    output.maxPhotoDimensions = output.maxPhotoDimensions
                } else {
                    output.isHighResolutionCaptureEnabled = true
                }
                self.photoOutput = output
            }

            self.session.commitConfiguration()
            print("✅ Session configuration committed")

            DispatchQueue.main.async {
                self.isSetup = true
                print("⚙️ ========== SETUP COMPLETE ==========")
                completion?()
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        print("📸 ========== CAPTURE PHOTO CALLED ==========")
        guard let photoOutput = photoOutput else { print("❌ No photo output available"); completion(nil); return }
        guard session.isRunning else { print("❌ Session not running - cannot capture"); completion(nil); return }

        // Re-read the coordinator's angle on every capture rather than caching
        // it once — see the comment on `attachPreviewLayer` above.
        if let connection = photoOutput.connection(with: .video) {
            let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }

        currentPhotoDelegate = PhotoCaptureDelegate { image in
            completion(image)
        }
        photoOutput.capturePhoto(with: settings, delegate: currentPhotoDelegate!)
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
        cameraManager.attachPreviewLayer(previewLayer)
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            cameraManager.attachPreviewLayer(previewLayer)
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

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
