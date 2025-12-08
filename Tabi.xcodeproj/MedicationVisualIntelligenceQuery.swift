//
//  MedicationVisualIntelligenceQuery.swift
//  Tabi
//
//  Enhanced Visual Intelligence search with AI, fuzzy matching, and advanced image analysis
//

import AppIntents
import VisualIntelligence
import Vision
import CoreImage

/// Enhanced visual intelligence query for medications
struct MedicationIntentValueQuery: IntentValueQuery {
    
    private let imageAnalyzer = AdvancedImageAnalyzer()
    
    func values(for input: SemanticContentDescriptor) async throws -> [MedicationEntity] {
        // Get labels from Visual Intelligence
        let labels = input.labels
        
        // If we have a pixel buffer, use advanced image analysis
        if let pixelBuffer = input.pixelBuffer {
            return try await searchByImageAdvanced(pixelBuffer: pixelBuffer, labels: labels)
        }
        
        // Fall back to label-based search with fuzzy matching
        return await searchByLabelsAdvanced(labels)
    }
    
    // MARK: - Advanced Search
    
    /// Advanced image-based search with comprehensive analysis
    private func searchByImageAdvanced(pixelBuffer: CVReadOnlyPixelBuffer, labels: [String]) async throws -> [MedicationEntity] {
        // Perform comprehensive image analysis
        let analysisResult = try await imageAnalyzer.analyzeComprehensively(pixelBuffer: pixelBuffer)
        
        // Try AI analysis if available on iOS 18+
        var allSearchTerms = analysisResult.searchTerms + labels
        
        if #available(iOS 18.0, *) {
            let coordinator = MedicationAnalysisCoordinator()
            if let completeResult = try? await coordinator.analyzeCompletely(pixelBuffer: pixelBuffer) {
                allSearchTerms.append(contentsOf: completeResult.allSearchTerms)
            }
        }
        
        // Check for barcode match first (most accurate)
        if let barcode = analysisResult.barcode {
            if let barcodeMatch = searchByBarcode(barcode) {
                return [barcodeMatch]
            }
        }
        
        // Remove duplicates
        let uniqueTerms = Array(Set(allSearchTerms))
        
        // Search with relevance scoring
        return await searchByLabelsAdvanced(uniqueTerms)
    }
    
    /// Advanced label-based search with fuzzy matching and relevance scoring
    private func searchByLabelsAdvanced(_ labels: [String]) async -> [MedicationEntity] {
        let medications = loadMedications()
        
        // Calculate relevance scores for each medication
        var scoredMedications: [(medication: MedicationEntity, score: Double)] = []
        
        for medication in medications {
            // Load metadata if available
            let metadata = loadMetadata(for: medication.id)
            
            // Get medication model
            if let med = loadMedication(for: medication.id) {
                let score = med.relevanceScore(for: labels, with: metadata)
                if score > 0.1 { // Minimum relevance threshold
                    scoredMedications.append((medication, score))
                }
            }
        }
        
        // Sort by relevance score (highest first)
        let sortedMedications = scoredMedications
            .sorted { $0.score > $1.score }
            .map { $0.medication }
        
        // Return top 10 matches
        return Array(sortedMedications.prefix(10))
    }
    
    /// Search by NDC barcode
    private func searchByBarcode(_ barcode: String) -> MedicationEntity? {
        let medications = loadMedications()
        
        for medication in medications {
            if let metadata = loadMetadata(for: medication.id),
               metadata.ndcCode == barcode {
                return medication
            }
        }
        
        return nil
    }
    
    // MARK: - Data Loading
    
    /// Load medications from UserDefaults
    private func loadMedications() -> [MedicationEntity] {
        guard let data = UserDefaults.standard.data(forKey: "medications"),
              let medications = try? JSONDecoder().decode([Medication].self, from: data) else {
            return []
        }
        
        return medications.map { MedicationEntity(from: $0) }
    }
    
    /// Load metadata for a specific medication
    private func loadMetadata(for medicationId: UUID) -> Medication.EnhancedMetadata? {
        guard let data = UserDefaults.standard.data(forKey: "medication_metadata_\(medicationId.uuidString)"),
              let metadata = try? JSONDecoder().decode(Medication.EnhancedMetadata.self, from: data) else {
            return nil
        }
        
        return metadata
    }
    
    /// Load medication model for relevance scoring
    private func loadMedication(for medicationId: UUID) -> Medication? {
        guard let data = UserDefaults.standard.data(forKey: "medications"),
              let medications = try? JSONDecoder().decode([Medication].self, from: data) else {
            return nil
        }
        
        return medications.first { $0.id == medicationId }
    }
}

// MARK: - Medication Extension for Entity Conversion

extension MedicationEntity {
    /// Enhanced display with metadata
    func displayRepresentationWithMetadata(_ metadata: Medication.EnhancedMetadata?) -> DisplayRepresentation {
        var subtitle = "Take at \(dosageTime.formatted(date: .omitted, time: .shortened))"
        
        if let dosage = metadata?.dosageAmount {
            subtitle = "\(dosage) • " + subtitle
        }
        
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "\(emoji) \(name)"),
            subtitle: LocalizedStringResource(stringLiteral: subtitle),
            image: .init(systemName: "pills.fill")
        )
    }
}
