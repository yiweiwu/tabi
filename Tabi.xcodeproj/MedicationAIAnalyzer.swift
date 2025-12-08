//
//  MedicationAIAnalyzer.swift
//  Tabi
//
//  Uses Foundation Models (Apple Intelligence) for advanced medication analysis
//

import FoundationModels
import Vision
import UIKit

// MARK: - AI-Powered Medication Analyzer

@available(iOS 18.0, *)
class MedicationAIAnalyzer {
    
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    
    // MARK: - Model Availability
    
    /// Check if Apple Intelligence is available
    var isAvailable: Bool {
        switch model.availability {
        case .available:
            return true
        default:
            return false
        }
    }
    
    var unavailabilityReason: String? {
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Device not eligible for Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings"
        case .unavailable(.modelNotReady):
            return "Model is downloading or not ready"
        case .unavailable(let other):
            return "Model unavailable: \(other)"
        }
    }
    
    // MARK: - Medication Analysis
    
    /// Analyze medication from text using AI
    func analyzeMedicationFromText(_ text: String) async throws -> MedicationAnalysis {
        let instructions = """
        You are a medication identification assistant.
        Extract structured information from medication text.
        Be accurate and only extract information that is clearly present.
        If you're unsure, use null for that field.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let prompt = """
        Analyze this medication text and extract information:
        
        Text: "\(text)"
        
        Extract:
        - Medication name
        - Generic name (if mentioned)
        - Brand names (if mentioned)
        - Dosage amount (e.g., "500mg")
        - Active ingredient (if mentioned)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: MedicationAnalysis.self
        )
        
        return response.content
    }
    
    /// Analyze medication from recognized text elements
    func analyzeMedicationFromElements(_ elements: [AdvancedImageAnalyzer.RecognizedTextElement]) async throws -> MedicationAnalysis {
        // Combine high-confidence text
        let combinedText = elements
            .filter { $0.confidence > 0.7 }
            .map { $0.text }
            .joined(separator: " ")
        
        return try await analyzeMedicationFromText(combinedText)
    }
    
    /// Generate medication search queries from image
    func generateSearchQueries(from text: String) async throws -> [String] {
        let instructions = """
        You are a search query generator for medication identification.
        Generate multiple search queries that would help find a medication in a database.
        Include variations, generic names, brand names, and common misspellings.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let prompt = """
        Generate search queries for this medication text:
        
        Text: "\(text)"
        
        Generate 5-10 search queries that would match this medication.
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: SearchQueries.self
        )
        
        return response.content.queries
    }
    
    /// Suggest medication based on partial information
    func suggestMedication(partialInfo: String) async throws -> [String] {
        let instructions = """
        You are a medication suggestion assistant.
        Given partial information, suggest possible medications.
        Only suggest real, commonly used medications.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let prompt = """
        Suggest possible medications based on this partial information:
        
        "\(partialInfo)"
        
        Provide 5-10 likely medication names.
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: MedicationSuggestions.self
        )
        
        return response.content.suggestions
    }
    
    /// Explain medication interactions (educational purpose)
    func explainMedication(_ medicationName: String) async throws -> String {
        let instructions = """
        You are a medication information assistant.
        Provide brief, educational information about medications.
        Keep responses under 100 words.
        Always include a disclaimer to consult healthcare professionals.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        let prompt = """
        Provide brief information about \(medicationName):
        - What it's used for
        - Common dosage
        - Basic precautions
        
        Include disclaimer.
        """
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    // MARK: - Streaming Analysis
    
    /// Stream medication analysis results in real-time
    func streamMedicationAnalysis(from text: String) -> AsyncThrowingStream<PartialMedicationAnalysis, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let instructions = """
                    You are a medication identification assistant.
                    Extract structured information from medication text progressively.
                    """
                    
                    let session = LanguageModelSession(instructions: instructions)
                    
                    let prompt = "Analyze this medication: \(text)"
                    
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: MedicationAnalysis.self
                    )
                    
                    for try await partial in stream {
                        continuation.yield(PartialMedicationAnalysis(from: partial))
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Data Structures

@available(iOS 18.0, *)
@Generable(description: "Structured medication information")
struct MedicationAnalysis {
    @Guide(description: "The primary medication name")
    var name: String?
    
    @Guide(description: "Generic or scientific name")
    var genericName: String?
    
    @Guide(description: "List of brand names", .count(0...10))
    var brandNames: [String]?
    
    @Guide(description: "Dosage amount like '500mg' or '10ml'")
    var dosageAmount: String?
    
    @Guide(description: "Active ingredient")
    var activeIngredient: String?
    
    @Guide(description: "Pill color if mentioned")
    var pillColor: String?
    
    @Guide(description: "Pill shape if mentioned")
    var pillShape: String?
}

@available(iOS 18.0, *)
typealias PartialMedicationAnalysis = MedicationAnalysis.PartiallyGenerated

@available(iOS 18.0, *)
@Generable(description: "Search queries for medication identification")
struct SearchQueries {
    @Guide(description: "List of search queries", .count(5...10))
    var queries: [String]
}

@available(iOS 18.0, *)
@Generable(description: "Medication suggestions")
struct MedicationSuggestions {
    @Guide(description: "List of medication suggestions", .count(5...10))
    var suggestions: [String]
}

// MARK: - Integration Helper

@available(iOS 18.0, *)
class MedicationAnalysisCoordinator {
    private let imageAnalyzer = AdvancedImageAnalyzer()
    private let aiAnalyzer = MedicationAIAnalyzer()
    
    /// Perform complete analysis combining vision and AI
    func analyzeCompletely(pixelBuffer: CVPixelBuffer) async throws -> CompleteAnalysisResult {
        // Step 1: Vision analysis
        let visionResult = try await imageAnalyzer.analyzeComprehensively(pixelBuffer: pixelBuffer)
        
        // Step 2: If AI is available, enhance with AI analysis
        var aiResult: MedicationAnalysis?
        if aiAnalyzer.isAvailable {
            let combinedText = visionResult.textElements.map { $0.text }.joined(separator: " ")
            if !combinedText.isEmpty {
                aiResult = try? await aiAnalyzer.analyzeMedicationFromText(combinedText)
            }
        }
        
        return CompleteAnalysisResult(
            visionResult: visionResult,
            aiResult: aiResult
        )
    }
    
    struct CompleteAnalysisResult {
        let visionResult: AdvancedImageAnalyzer.ComprehensiveAnalysisResult
        let aiResult: MedicationAnalysis?
        
        /// Combined search terms from both analyses
        var allSearchTerms: [String] {
            var terms = visionResult.searchTerms
            
            if let ai = aiResult {
                if let name = ai.name { terms.append(name) }
                if let generic = ai.genericName { terms.append(generic) }
                if let brands = ai.brandNames { terms.append(contentsOf: brands) }
                if let dosage = ai.dosageAmount { terms.append(dosage) }
                if let ingredient = ai.activeIngredient { terms.append(ingredient) }
            }
            
            return Array(Set(terms)) // Remove duplicates
        }
        
        /// Best medication name guess
        var bestGuessName: String? {
            // Prefer AI result if available
            if let aiName = aiResult?.name {
                return aiName
            }
            
            // Fall back to vision analysis
            return visionResult.medicationNames.first
        }
    }
}
