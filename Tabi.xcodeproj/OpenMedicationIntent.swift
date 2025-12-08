//
//  OpenMedicationIntent.swift
//  Tabi
//
//  Opens a medication detail when tapped from Visual Intelligence
//

import AppIntents
import SwiftUI
import UIKit

/// Intent to open a specific medication in the app
struct OpenMedicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Medication"
    static var description = IntentDescription("Opens a medication in Tabi")
    
    @Parameter(title: "Medication")
    var target: MedicationEntity
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Open the app using the deep link URL
        if let url = target.url {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// Intent to view more medication search results
struct ViewMoreMedicationsIntent: AppIntent, VisualIntelligenceSearchIntent {
    static var title: LocalizedStringResource = "View More Medications"
    static var description = IntentDescription("View more medication search results in Tabi")
    
    @Parameter(title: "Semantic Content")
    var semanticContent: SemanticContentDescriptor
    
    func perform() async throws -> some IntentResult {
        // Open the app to show full search results
        // You could pass the semantic content to show filtered results
        return .result()
    }
}
