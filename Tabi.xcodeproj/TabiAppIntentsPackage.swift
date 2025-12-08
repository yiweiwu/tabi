//
//  TabiAppIntentsPackage.swift
//  Tabi
//
//  Registers all App Intents for the app
//

import AppIntents

/// Package that registers all app intents
struct TabiAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] = []
}
