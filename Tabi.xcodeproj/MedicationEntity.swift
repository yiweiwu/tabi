//
//  MedicationEntity.swift
//  Tabi
//
//  Visual Intelligence Support for Medications
//

import AppIntents
import Foundation

/// App Entity representing a medication that can be discovered through Visual Intelligence
struct MedicationEntity: AppEntity, Identifiable {
    var id: UUID
    
    @Property(title: "Name")
    var name: String
    
    @Property(title: "Emoji")
    var emoji: String
    
    @Property(title: "Dosage Time")
    var dosageTime: Date
    
    @Property(title: "Points")
    var points: Int
    
    @Property(title: "Current Streak")
    var streak: Int
    
    // Required for AppEntity
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Medication"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) medications")
        )
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "\(emoji) \(name)"),
            subtitle: LocalizedStringResource(stringLiteral: "Take at \(dosageTime.formatted(date: .omitted, time: .shortened))"),
            image: .init(systemName: "pills.fill")
        )
    }
    
    /// URL for deep linking to this medication
    var url: URL? {
        URL(string: "tabi://medication/\(id.uuidString)")
    }
    
    // Convert from your existing Medication model
    init(from medication: Medication) {
        self.id = medication.id
        self.name = medication.name
        self.emoji = medication.emoji
        self.dosageTime = medication.dosageTime
        self.points = medication.points
        self.streak = medication.streak
    }
    
    // Required initializer
    init(id: UUID, name: String, emoji: String, dosageTime: Date, points: Int, streak: Int) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.dosageTime = dosageTime
        self.points = points
        self.streak = streak
    }
}
