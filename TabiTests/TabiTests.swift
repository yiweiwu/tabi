//
//  TabiTests.swift
//  TabiTests
//
//  Created by Annie on 9/21/25.
//

import Testing
import UIKit
import Vision
@testable import Tabi

// MARK: - Test Data Structure

struct MedicationTestCase {
    let imageName: String
    let expectedMedication: String
    let expectedDosage: String
    let expectedSchedule: String?
    let description: String
    
    init(
        imageName: String,
        expectedMedication: String,
        expectedDosage: String,
        expectedSchedule: String? = nil,
        description: String
    ) {
        self.imageName = imageName
        self.expectedMedication = expectedMedication
        self.expectedDosage = expectedDosage
        self.expectedSchedule = expectedSchedule
        self.description = description
    }
}

// MARK: - Main Test Suite

@Suite
struct TabiTests {
    
    // MARK: - Your Actual Medications (From Images You Provided)
    
    static let testCases: [MedicationTestCase] = [
        MedicationTestCase(
            imageName: "Med_Hydrocodone",
            expectedMedication: "Hydrocodone-Acetamin",
            expectedDosage: "5-325 MG",
            expectedSchedule: "Take 1 tablet by mouth every 6 hours",
            description: "Hydrocodone-Acetamin 5-325 MG prescription"
        ),
        
        MedicationTestCase(
            imageName: "Med_Doxycycline",
            expectedMedication: "Doxycycline Hyclate",
            expectedDosage: "100 MG",
            expectedSchedule: "Take 1 capsule by mouth twice a day",
            description: "Doxycycline Hyclate 100 MG prescription"
        ),
    ]
    
    // MARK: - Main Detection Tests
    
    @Test(arguments: testCases)
    func testMedicationDetection(testCase: MedicationTestCase) async throws {
        let image = try loadTestImage(named: testCase.imageName)
        
        print("\n🧪 Testing: \(testCase.description)")
        print("   Image: \(testCase.imageName)")
        print("   Expected Medication: \(testCase.expectedMedication)")
        print("   Expected Dosage: \(testCase.expectedDosage)")
        
        let detectedInfo = try await detectMedicationInfo(from: image)
        
        print("\n📊 Detection Results:")
        print("   Detected Medication: \(detectedInfo.medicationName)")
        print("   Detected Dosage: \(detectedInfo.dosage)")
        print("   Detected Schedule: \(detectedInfo.schedule)")
        print("\n📝 All Detected Text:")
        detectedInfo.allDetectedText.forEach { print("   - \($0)") }
        
        // Verify medication name (lenient threshold for OCR variations)
        let medicationMatch = fuzzyMatch(
            detectedInfo.medicationName,
            testCase.expectedMedication,
            threshold: 0.75
        )
        
        if !medicationMatch {
            let similarity = calculateSimilarity(detectedInfo.medicationName, testCase.expectedMedication)
            print("❌ Medication name mismatch!")
            print("   Expected: '\(testCase.expectedMedication)'")
            print("   Got: '\(detectedInfo.medicationName)'")
            print("   Similarity: \(String(format: "%.2f", similarity))")
        }
        #expect(medicationMatch)
        
        // Verify dosage
        let dosageMatch = detectedInfo.dosage.contains(testCase.expectedDosage) ||
                          fuzzyMatch(detectedInfo.dosage, testCase.expectedDosage, threshold: 0.8)
        
        if !dosageMatch {
            print("❌ Dosage mismatch!")
            print("   Expected: '\(testCase.expectedDosage)'")
            print("   Got: '\(detectedInfo.dosage)'")
        }
        #expect(dosageMatch)
        
        // Verify schedule if provided
        if let expectedSchedule = testCase.expectedSchedule {
            let scheduleMatch = fuzzyMatch(
                detectedInfo.schedule,
                expectedSchedule,
                threshold: 0.6
            )
            
            if !scheduleMatch {
                print("❌ Schedule mismatch!")
                print("   Expected: '\(expectedSchedule)'")
                print("   Got: '\(detectedInfo.schedule)'")
            }
            #expect(scheduleMatch)
        }
        
        print("\n✅ Test passed: \(testCase.description)")
    }
    
    // MARK: - Detailed Debug Tests
    
    @Test
    func testHydrocodoneDetailed() async throws {
        let image = try loadTestImage(named: "Med_Hydrocodone")
        
        print("\n🔍 DETAILED ANALYSIS: Hydrocodone")
        print("==================================")
        
        let allTexts = try await recognizeAllText(in: image)
        
        print("\n📝 Raw OCR Output (in order):")
        allTexts.enumerated().forEach { index, text in
            print("  \(index + 1). '\(text)'")
        }
        
        let info = try await detectMedicationInfo(from: image)
        
        print("\n📊 Extracted Information:")
        print("  Medication: \(info.medicationName)")
        print("  Dosage: \(info.dosage)")
        print("  Schedule: \(info.schedule)")
        
        let hasHydrocodone = info.medicationName.lowercased().contains("hydrocodone")
        let hasAcetamin = info.medicationName.lowercased().contains("acetamin")
        let hasDosage = info.dosage.contains("5-325") || info.dosage.contains("5 325")
        
        print("\n✅ Validation:")
        print("  Contains 'Hydrocodone': \(hasHydrocodone ? "✅" : "❌")")
        print("  Contains 'Acetamin': \(hasAcetamin ? "✅" : "❌")")
        print("  Contains '5-325': \(hasDosage ? "✅" : "❌")")
        
        #expect(hasHydrocodone)
        #expect(hasDosage)
    }
    
    @Test
    func testDoxycyclineDetailed() async throws {
        let image = try loadTestImage(named: "Med_Doxycycline")
        
        print("\n🔍 DETAILED ANALYSIS: Doxycycline")
        print("==================================")
        
        let allTexts = try await recognizeAllText(in: image)
        
        print("\n📝 Raw OCR Output (in order):")
        allTexts.enumerated().forEach { index, text in
            print("  \(index + 1). '\(text)'")
        }
        
        let info = try await detectMedicationInfo(from: image)
        
        print("\n📊 Extracted Information:")
        print("  Medication: \(info.medicationName)")
        print("  Dosage: \(info.dosage)")
        print("  Schedule: \(info.schedule)")
        
        let hasDoxycycline = info.medicationName.lowercased().contains("doxycycline")
        let hasHyclate = info.medicationName.lowercased().contains("hyclate")
        let hasDosage = info.dosage.contains("100")
        
        print("\n✅ Validation:")
        print("  Contains 'Doxycycline': \(hasDoxycycline ? "✅" : "❌")")
        print("  Contains 'Hyclate': \(hasHyclate ? "✅" : "❌")")
        print("  Contains '100 MG': \(hasDosage ? "✅" : "❌")")
        
        #expect(hasDoxycycline)
        #expect(hasDosage)
    }
    
    @Test
    func testOCRQuality() async throws {
        print("\n📊 OCR Quality Report")
        print("====================\n")
        
        for testCase in Self.testCases {
            let image = try loadTestImage(named: testCase.imageName)
            let report = try await analyzeOCRConfidence(in: image)
            
            print("📷 \(testCase.imageName):")
            print("   Average Confidence: \(String(format: "%.1f%%", report.averageConfidence * 100))")
            print("   High Confidence (>80%): \(report.highConfidenceCount)/\(report.totalObservations)")
            print("   Low Confidence (<50%): \(report.lowConfidenceCount)/\(report.totalObservations)")
            
            if report.averageConfidence <= 0.5 {
                print("   ⚠️ Low average OCR confidence: \(String(format: "%.1f%%", report.averageConfidence * 100))")
            }
            #expect(report.averageConfidence > 0.5)
            
            print("")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTestImage(named imageName: String) throws -> UIImage {
        print("🔍 Attempting to load image: '\(imageName)'")
        
        // Method 1: Try loading without extension from main bundle
        if let image = UIImage(named: imageName) {
            print("✅ Found image in main bundle")
            return image
        }
        
        // Method 2: Try with .jpeg extension
        if let image = UIImage(named: "\(imageName).jpeg") {
            print("✅ Found image with .jpeg extension")
            return image
        }
        
        // Method 3: Try with .jpg extension
        if let image = UIImage(named: "\(imageName).jpg") {
            print("✅ Found image with .jpg extension")
            return image
        }
        
        // Method 4: Try loading from test bundle
        if let testBundle = Bundle.allBundles.first(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            print("📦 Found test bundle: \(testBundle.bundlePath)")
            
            if let image = UIImage(named: imageName, in: testBundle, compatibleWith: nil) {
                print("✅ Found image in test bundle")
                return image
            }
            
            if let image = UIImage(named: "\(imageName).jpeg", in: testBundle, compatibleWith: nil) {
                print("✅ Found image in test bundle with .jpeg")
                return image
            }
        }
        
        // Method 5: Try finding the file path directly
        let bundles = Bundle.allBundles
        print("📦 Searching \(bundles.count) bundles...")
        
        for bundle in bundles {
            // Try different extensions
            for ext in ["", "jpeg", "jpg", "png"] {
                let filename = ext.isEmpty ? imageName : "\(imageName).\(ext)"
                if let path = bundle.path(forResource: imageName, ofType: ext.isEmpty ? nil : ext) {
                    print("✅ Found file at path: \(path)")
                    if let image = UIImage(contentsOfFile: path) {
                        print("✅ Successfully loaded image from path")
                        return image
                    }
                }
            }
        }
        
        print("❌ Image not found: '\(imageName)'")
        print("💡 Make sure the image is added to the TabiTests target")
        throw TestError.imageNotFound(imageName)
    }
    
    private func detectMedicationInfo(from image: UIImage) async throws -> DetectedMedicationInfo {
        try await withCheckedThrowingContinuation { continuation in
            MedicationAnalyzer.shared.detectMedicationFromLabel(image: image) { info in
                continuation.resume(returning: info)
            }
        }
    }
    
    private func recognizeAllText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw TestError.invalidImage
        }
        
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
                
                let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                let texts = sorted.compactMap { $0.topCandidates(1).first?.string }
                
                continuation.resume(returning: texts)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func analyzeOCRConfidence(in image: UIImage) async throws -> OCRConfidenceReport {
        guard let cgImage = image.cgImage else {
            throw TestError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRConfidenceReport(
                        averageConfidence: 0,
                        totalObservations: 0,
                        highConfidenceCount: 0,
                        lowConfidenceCount: 0
                    ))
                    return
                }
                
                var totalConfidence = 0.0
                var highConfidence = 0
                var lowConfidence = 0
                
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        totalConfidence += Double(candidate.confidence)
                        
                        if candidate.confidence > 0.8 {
                            highConfidence += 1
                        } else if candidate.confidence < 0.5 {
                            lowConfidence += 1
                        }
                    }
                }
                
                let report = OCRConfidenceReport(
                    averageConfidence: observations.isEmpty ? 0 : totalConfidence / Double(observations.count),
                    totalObservations: observations.count,
                    highConfidenceCount: highConfidence,
                    lowConfidenceCount: lowConfidence
                )
                
                continuation.resume(returning: report)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - String Matching Utilities
    
    private func fuzzyMatch(_ str1: String, _ str2: String, threshold: Double = 0.8) -> Bool {
        let similarity = calculateSimilarity(str1, str2)
        return similarity >= threshold
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = normalize(str1)
        let s2 = normalize(str2)
        
        if s1.isEmpty && s2.isEmpty { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }
        
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func normalize(_ str: String) -> String {
        return str
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: .punctuationCharacters)
            .joined()
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let arr1 = Array(s1)
        let arr2 = Array(s2)
        let m = arr1.count
        let n = arr2.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = arr1[i-1] == arr2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Supporting Types

struct OCRConfidenceReport {
    let averageConfidence: Double
    let totalObservations: Int
    let highConfidenceCount: Int
    let lowConfidenceCount: Int
}

enum TestError: Error {
    case imageNotFound(String)
    case invalidImage
    
    var localizedDescription: String {
        switch self {
        case .imageNotFound(let name):
            return "Test image not found: '\(name)'. Please add it to your test bundle."
        case .invalidImage:
            return "Invalid image - could not convert to CGImage"
        }
    }
}
