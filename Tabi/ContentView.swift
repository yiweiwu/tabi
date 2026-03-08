import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var medicationManager = MedicationManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(medicationManager: medicationManager)
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(0)

            SharingView()
                .tabItem { Label("Sharing", systemImage: "person.2") }
                .tag(1)

            CalendarView(medicationManager: medicationManager)
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(2)

            ProfileView(medicationManager: medicationManager)
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(3)
        }
        .tint(.tabiOrange)
        .onAppear { NotificationScheduler.shared.requestPermission() }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
