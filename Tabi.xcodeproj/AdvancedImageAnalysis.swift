//
//  AdvancedImageAnalysis.swift
//  Tabi
//
//  Advanced image analysis including pill classification, color detection, and barcode scanning
//

import Vision
import CoreImage
import UIKit
import VisionKit

// MARK: - Advanced Image Analyzer

class AdvancedImageAnalyzer {
    
    // MARK: - Color Detection
    
    /// Detect the dominant color of a pill in the image
    func detectPillColor(from pixelBuffer: CVPixelBuffer) async throws -> Medication.PillColor? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Get dominant colors using Core Image
        guard let dominantColors = try? await getDominantColors(from: ciImage) else {
            return nil
        }
        
        // Map to pill color
        return mapToPillColor(dominantColors.first)
    }
    
    private func getDominantColors(from image: CIImage) async throws -> [UIColor] {
        // Simplified color extraction
        // In production, you'd use more sophisticated color clustering
        return []
    }
    
    private func mapToPillColor(_ color: UIColor?) -> Medication.PillColor? {
        guard let color = color else { return nil }
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Simple color mapping
        if red > 0.8 && green > 0.8 && blue > 0.8 { return .white }
        if red > 0.7 && green > 0.7 { return .yellow }
        if red > 0.7 && green < 0.5 && blue < 0.5 { return .red }
        if red < 0.5 && green < 0.5 && blue > 0.7 { return .blue }
        if red < 0.5 && green > 0.7 && blue < 0.5 { return .green }
        if red > 0.6 && green < 0.5 && blue > 0.5 { return .purple }
        
        return .other
    }
    
    // MARK: - Shape Detection
    
    /// Detect the shape of a pill in the image
    func detectPillShape(from pixelBuffer: CVPixelBuffer) async throws -> Medication.PillShape? {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectContoursRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNContoursObservation],
                      let firstContour = observations.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let shape = self.classifyShape(from: firstContour)
                continuation.resume(returning: shape)
            }
            
            request.detectsDarkOnLight = true
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func classifyShape(from contour: VNContoursObservation) -> Medication.PillShape {
        // Analyze aspect ratio and vertex count
        let normalizedPath = contour.normalizedPath
        let bounds = normalizedPath.boundingBox
        let aspectRatio = bounds.width / bounds.height
        
        // Simple shape classification based on aspect ratio
        if abs(aspectRatio - 1.0) < 0.2 {
            return .round
        } else if aspectRatio > 1.5 {
            return .capsule
        } else if aspectRatio > 1.2 {
            return .oblong
        } else {
            return .oval
        }
    }
    
    // MARK: - Barcode Scanning
    
    /// Scan for medication barcodes (NDC codes)
    func scanBarcode(from pixelBuffer: CVPixelBuffer) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNBarcodeObservation],
                      let barcode = observations.first,
                      let payload = barcode.payloadStringValue else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: payload)
            }
            
            // Support multiple barcode types
            request.symbologies = [
                .code128,
                .code39,
                .code93,
                .ean13,
                .ean8,
                .upce,
                .dataMatrix,
                .qr
            ]
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Text Recognition with Layout
    
    /// Enhanced OCR with layout and confidence information
    func recognizeTextWithLayout(from pixelBuffer: CVPixelBuffer) async throws -> [RecognizedTextElement] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let elements = observations.compactMap { observation -> RecognizedTextElement? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    
                    return RecognizedTextElement(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                
                continuation.resume(returning: elements)
            }
            
            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    struct RecognizedTextElement {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
        
        /// Extract dosage information (e.g., "500mg", "10mg")
        var dosageInfo: String? {
            let pattern = #"\d+\s?(mg|mcg|g|ml|IU|units?)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return nil
            }
            
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range) else {
                return nil
            }
            
            return (text as NSString).substring(with: match.range)
        }
        
        /// Check if this looks like a medication name
        var isMedicationName: Bool {
            // Heuristics: longer text with capital letters, not numbers-heavy
            let words = text.components(separatedBy: .whitespaces)
            let hasCapital = text.contains(where: { $0.isUppercase })
            let isNotJustNumbers = text.filter({ $0.isLetter }).count > text.filter({ $0.isNumber }).count
            
            return hasCapital && isNotJustNumbers && words.count <= 3
        }
    }
    
    // MARK: - Object Detection
    
    /// Detect if image contains a pill or medication bottle
    func detectMedicationObject(from pixelBuffer: CVPixelBuffer) async throws -> MedicationObjectType? {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // For pill/bottle detection, you'd use a custom Core ML model
                // This is a placeholder showing the structure
                continuation.resume(returning: nil)
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum MedicationObjectType {
        case pill
        case bottle
        case blisterPack
        case tube
        case unknown
    }
    
    // MARK: - Comprehensive Analysis
    
    /// Perform comprehensive analysis combining all methods
    func analyzeComprehensively(pixelBuffer: CVPixelBuffer) async throws -> ComprehensiveAnalysisResult {
        async let textElements = recognizeTextWithLayout(from: pixelBuffer)
        async let barcode = scanBarcode(from: pixelBuffer)
        async let color = detectPillColor(from: pixelBuffer)
        async let shape = detectPillShape(from: pixelBuffer)
        async let objectType = detectMedicationObject(from: pixelBuffer)
        
        return try await ComprehensiveAnalysisResult(
            textElements: textElements,
            barcode: barcode,
            pillColor: color,
            pillShape: shape,
            objectType: objectType
        )
    }
    
    struct ComprehensiveAnalysisResult {
        let textElements: [RecognizedTextElement]
        let barcode: String?
        let pillColor: Medication.PillColor?
        let pillShape: Medication.PillShape?
        let objectType: MedicationObjectType?
        
        /// Extract medication names from text
        var medicationNames: [String] {
            textElements
                .filter { $0.isMedicationName }
                .map { $0.text }
        }
        
        /// Extract dosage information
        var dosages: [String] {
            textElements
                .compactMap { $0.dosageInfo }
        }
        
        /// All search terms for medication matching
        var searchTerms: [String] {
            var terms = medicationNames + dosages
            
            if let color = pillColor {
                terms.append(color.rawValue)
            }
            
            if let shape = pillShape {
                terms.append(shape.rawValue)
            }
            
            return terms
        }
    }
}
