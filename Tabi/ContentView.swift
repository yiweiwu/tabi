import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject private var medicationManager = MedicationStore.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(medicationManager: medicationManager)
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(0)

            SharingView(medicationManager: medicationManager)
                .tabItem { Label("Sharing", systemImage: "person.2") }
                .tag(1)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(2)

            ProfileView(medicationManager: medicationManager)
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(3)
        }
        .tint(.tabiOrange)
        .preferredColorScheme(.light) // Force light mode
        .onAppear {
            NotificationScheduler.shared.requestPermission()
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

