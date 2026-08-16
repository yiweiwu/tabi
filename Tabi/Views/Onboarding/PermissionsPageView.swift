import SwiftUI
import UserNotifications
import AVFoundation

// MARK: - Permissions Page

struct PermissionsPageView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var cameraStatus: PermissionStatus = .notDetermined
    @State private var notificationStatus: PermissionStatus = .notDetermined
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentPage = .completion
                    }
                }
                .foregroundColor(.tabiGray)
                .font(.body)
                .padding(.top, 16)
                .padding(.trailing, 24)
            }
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.tabiLavender)

                    Text("Enable Permissions")
                        .font(.title.bold())
                        .foregroundColor(.primary)

                    Text("Allow Tabi to help you stay on track")
                        .font(.body)
                        .foregroundColor(.tabiGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                // Permission Items
                VStack(spacing: 20) {
                    PermissionItemView(
                        icon: "camera.fill",
                        title: "Camera Access",
                        description: "Scan medication labels to quickly add them to your list",
                        status: cameraStatus,
                        action: requestCameraPermission
                    )

                    PermissionItemView(
                        icon: "bell.fill",
                        title: "Push Notifications",
                        description: "Get reminders so you never miss taking your medications",
                        status: notificationStatus,
                        action: requestNotificationPermission
                    )
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 12)

                // Info text
                Text("You can change these permissions anytime in Settings")
                    .font(.caption)
                    .foregroundColor(.tabiGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 132)
            }
            .padding(.top, 8)
        }
        .onAppear {
            checkPermissionStatuses()
        }
    }
    
    // MARK: - Permission Handlers
    
    private func checkPermissionStatuses() {
        // Check camera status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraStatus = .granted
        case .denied, .restricted:
            cameraStatus = .denied
        case .notDetermined:
            cameraStatus = .notDetermined
        @unknown default:
            cameraStatus = .notDetermined
        }
        
        // Check notification status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    notificationStatus = .granted
                case .denied:
                    notificationStatus = .denied
                case .notDetermined:
                    notificationStatus = .notDetermined
                @unknown default:
                    notificationStatus = .notDetermined
                }
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraStatus = granted ? .granted : .denied
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                    notificationStatus = .denied
                } else {
                    notificationStatus = granted ? .granted : .denied
                }
            }
        }
    }
}

// MARK: - Permission Status Enum

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

// MARK: - Permission Item View

struct PermissionItemView: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(iconColor)
                    )
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.tabiGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            // Action button
            if status == .notDetermined {
                Button(action: action) {
                    Text("Allow")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.tabiOrange)
                        )
                }
            } else {
                HStack {
                    Image(systemName: statusIcon)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                    
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    if status == .denied {
                        Button("Settings") {
                            openSettings()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.tabiOrange)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(statusBackgroundColor)
                )
            }
        }
        .padding()
        .background(Color.tabiCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var iconBackgroundColor: Color {
        switch status {
        case .granted:
            return Color.tabiGreen.opacity(0.2)
        case .denied:
            return Color.tabiRed.opacity(0.2)
        case .notDetermined:
            return Color.tabiLavLight
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .granted:
            return .tabiGreen
        case .denied:
            return .tabiRed
        case .notDetermined:
            return .tabiLavender
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return ""
        }
    }
    
    private var statusText: String {
        switch status {
        case .granted:
            return "Enabled"
        case .denied:
            return "Denied - Enable in Settings"
        case .notDetermined:
            return ""
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .tabiGreen
        case .denied:
            return .tabiRed
        case .notDetermined:
            return .clear
        }
    }
    
    private var statusBackgroundColor: Color {
        switch status {
        case .granted:
            return Color.tabiGreen.opacity(0.1)
        case .denied:
            return Color.tabiRed.opacity(0.1)
        case .notDetermined:
            return .clear
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionsPageView()
        .environment(OnboardingCoordinator())
}
