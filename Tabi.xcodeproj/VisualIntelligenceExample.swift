//
//  VisualIntelligenceExample.swift
//  Tabi
//
//  Example implementation showing how Visual Intelligence works
//

import SwiftUI
import AppIntents
import VisualIntelligence

/*
 
 HOW VISUAL INTELLIGENCE WORKS IN TABI
 ======================================
 
 1. USER ACTION:
    - User opens Visual Intelligence camera (Camera Control button)
    - Points camera at a medication bottle or pill
    - Circles the medication
 
 2. SYSTEM PROCESSING:
    - Visual Intelligence analyzes the image
    - Detects text using OCR
    - Identifies objects and provides labels
    - Creates a SemanticContentDescriptor with:
      * labels: ["Aspirin", "Medicine", "Pill"]
      * pixelBuffer: The actual image data
 
 3. YOUR APP IS CALLED:
    - System calls MedicationIntentValueQuery.values(for:)
    - Passes the SemanticContentDescriptor
 
 4. YOUR APP SEARCHES:
    - Uses Vision framework to read text from the image
    - Combines OCR results with provided labels
    - Searches your medication database
    - Returns matching MedicationEntity objects
 
 5. RESULTS DISPLAYED:
    - Visual Intelligence shows your results
    - Each result shows:
      * Emoji + Name (from displayRepresentation.title)
      * Dosage time (from displayRepresentation.subtitle)
      * Pills icon (from displayRepresentation.image)
 
 6. USER TAPS RESULT:
    - OpenMedicationIntent is called
    - Deep link URL is opened: "tabi://medication/{uuid}"
    - Your app opens to that specific medication
 
 SEARCH ALGORITHM
 ================
 
 The search happens in MedicationIntentValueQuery:
 
 1. Try to get pixel buffer from SemanticContentDescriptor
 2. If available, use Vision framework OCR to read text
 3. Combine OCR text with provided labels
 4. Search medications where name contains any search term
 5. Return top 10 unique matches
 
 Example:
 - Image shows: "ASPIRIN 500mg"
 - OCR detects: ["ASPIRIN", "500mg"]
 - Labels provided: ["Medicine", "Pill", "Pain Reliever"]
 - Search terms: ["ASPIRIN", "500mg", "Medicine", "Pill", "Pain Reliever"]
 - Results: Any medication with "aspirin" in the name
 
 EXTENDING THE IMPLEMENTATION
 ============================
 
 You can enhance the search by:
 
 1. Adding more metadata to Medication:
    - Generic names
    - Brand names
    - Active ingredients
    - Pill shape/color descriptions
 
 2. Using more advanced Vision:
    - Image classification for pill shape
    - Color detection
    - Barcode scanning for medication codes
 
 3. Adding fuzzy matching:
    - Levenshtein distance for typos
    - Soundex for phonetic matching
 
 4. Using Foundation Models:
    - Describe the medication image with LLM
    - Extract structured information
    - Understand context better
 
 Example enhancement with Foundation Models:
 
 ```swift
 import FoundationModels
 
 private func analyzeImageWithLLM(_ pixelBuffer: CVReadOnlyPixelBuffer) async throws -> [String] {
     let session = LanguageModelSession(instructions: """
         You are a medication identification assistant.
         Analyze the image and extract:
         - Medication name
         - Dosage
         - Active ingredients
         Return as a JSON array of strings.
         """)
     
     // Convert pixel buffer to image and analyze
     // This is a simplified example
     let response = try await session.respond(to: "Analyze this medication image")
     
     // Parse and return search terms
     return []
 }
 ```
 
 TESTING TIPS
 ============
 
 1. Add test medications with common names
 2. Test with photos of medication bottles
 3. Test with handwritten medication names
 4. Try circling just the name vs the whole bottle
 5. Test in different lighting conditions
 
 */

// MARK: - Example Test Data

extension MedicationManager {
    /// Add example medications for testing Visual Intelligence
    func addExampleMedications() {
        let examples = [
            Medication(name: "Aspirin", emoji: "💊", dosageTime: Date(), points: 10),
            Medication(name: "Ibuprofen", emoji: "💊", dosageTime: Date(), points: 10),
            Medication(name: "Acetaminophen", emoji: "💊", dosageTime: Date(), points: 10),
            Medication(name: "Vitamin D", emoji: "☀️", dosageTime: Date(), points: 5),
            Medication(name: "Multivitamin", emoji: "🌈", dosageTime: Date(), points: 5),
            Medication(name: "Fish Oil", emoji: "🐟", dosageTime: Date(), points: 5),
        ]
        
        for medication in examples {
            addMedication(medication)
        }
    }
}
