//
//  TabiApp.swift
//  Tabi
//
//  Created by Annie on 9/21/25.
//
import SwiftUI
import UserNotifications

@main
struct PillQuestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationPermissions()
                }
        }
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            }
        }
    }
}
