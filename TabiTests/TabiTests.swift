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
    
    // MARK: - Cached Test Results (for speed)
    
    /// Cache for analyzed medication results to avoid re-running OCR
    private static var cachedResults: [String: DetectedMedicationInfo] = [:]
    private static let cacheLock = NSLock()
    
    /// Clears the test result cache - call this when testing parser changes
    static func clearCache() {
        cacheLock.lock()
        cachedResults.removeAll()
        cacheLock.unlock()
        print("🗑️ Test cache cleared")
    }
    
    // MARK: - Main Detection Tests
    
    @Test("Clear cache before running tests")
    func testClearCache() async throws {
        // Always run this first to ensure clean state
        TabiTests.clearCache()
        print("✅ Cache cleared - tests will use fresh OCR/parsing results")
    }
    
    @Test(arguments: testCases)
    func testMedicationDetection(testCase: MedicationTestCase) async throws {
        let image = try loadTestImage(named: testCase.imageName)
        
        print("\n🧪 Testing: \(testCase.description)")
        print("   Image: \(testCase.imageName)")
        
        let detectedInfo = try await detectMedicationInfo(from: image, cacheKey: testCase.imageName)
        
        print("📊 Detection Results:")
        print("   Detected Medication: \(detectedInfo.brandName)")
        print("   Detected Dosage: \(detectedInfo.dosage)")
        print("   Detected Schedule: \(detectedInfo.schedule)")
        
        // Verify medication name (lenient threshold for OCR variations)
        let medicationMatch = fuzzyMatch(
            detectedInfo.brandName,
            testCase.expectedMedication,
            threshold: 0.75
        )
        
        #expect(
            medicationMatch,
            "Expected medication '\(testCase.expectedMedication)' but got '\(detectedInfo.brandName)' with similarity \(String(format: "%.2f", calculateSimilarity(detectedInfo.brandName, testCase.expectedMedication)))"
        )
        
        // Verify dosage
        let dosageMatch = detectedInfo.dosage.contains(testCase.expectedDosage) ||
                          fuzzyMatch(detectedInfo.dosage, testCase.expectedDosage, threshold: 0.8)
        
        #expect(
            dosageMatch,
            "Expected dosage '\(testCase.expectedDosage)' but got '\(detectedInfo.dosage)'"
        )
        
        // Verify schedule if provided
        if let expectedSchedule = testCase.expectedSchedule {
            let scheduleMatch = fuzzyMatch(
                detectedInfo.schedule,
                expectedSchedule,
                threshold: 0.6
            )
            
            #expect(
                scheduleMatch,
                "Expected schedule '\(expectedSchedule)' but got '\(detectedInfo.schedule)'"
            )
        }
        
        print("✅ Test passed: \(testCase.description)\n")
    }
    
    // MARK: - Detailed Debug Tests
    
    @Test
    func testRawOCROutput() async throws {
        print("\n🔍 RAW OCR DIAGNOSTIC TEST")
        print("==================================\n")
        
        for testCase in Self.testCases {
            let image = try loadTestImage(named: testCase.imageName)
            let allTexts = try await recognizeAllText(in: image)
            
            print("📷 \(testCase.imageName):")
            print("   Expected: \(testCase.expectedMedication) - \(testCase.expectedDosage)")
            print("\n   Raw OCR Output:")
            allTexts.enumerated().forEach { index, text in
                print("   \(index + 1). '\(text)'")
            }
            print("")
        }
    }
    
    @Test
    func testHydrocodoneDetailed() async throws {
        let image = try loadTestImage(named: "Med_Hydrocodone")
        
        print("\n🔍 DETAILED ANALYSIS: Hydrocodone")
        print("==================================")
        
        let info = try await detectMedicationInfo(from: image, cacheKey: "Med_Hydrocodone")
        
        print("\n📊 Extracted Information:")
        print("  Medication: \(info.brandName)")
        print("  Dosage: \(info.dosage)")
        print("  Schedule: \(info.schedule)")
        
        print("\n📝 All Detected Text:")
        info.allDetectedText.forEach { print("  - \($0)") }
        
        let medicationLowercased = info.brandName.lowercased()
        let hasHydrocodone = medicationLowercased.contains("hydrocodone")
        let hasAcetamin = medicationLowercased.contains("acetamin")
        let hasDosage = info.dosage.contains("5-325") || info.dosage.contains("5 325")
        
        print("\n✅ Validation:")
        print("  Contains 'Hydrocodone': \(hasHydrocodone ? "✅" : "❌")")
        print("  Contains 'Acetamin': \(hasAcetamin ? "✅" : "❌")")
        print("  Contains '5-325': \(hasDosage ? "✅" : "❌")")
        
        #expect(hasHydrocodone, "Medication name should contain 'Hydrocodone'")
        #expect(hasDosage, "Dosage should contain '5-325' or '5 325'")
    }
    
    @Test
    func testDoxycyclineDetailed() async throws {
        let image = try loadTestImage(named: "Med_Doxycycline")
        
        print("\n🔍 DETAILED ANALYSIS: Doxycycline")
        print("==================================")
        
        let info = try await detectMedicationInfo(from: image, cacheKey: "Med_Doxycycline")
        
        print("\n📊 Extracted Information:")
        print("  Medication: \(info.brandName)")
        print("  Dosage: \(info.dosage)")
        print("  Schedule: \(info.schedule)")
        
        print("\n📝 All Detected Text:")
        info.allDetectedText.forEach { print("  - \($0)") }
        
        let medicationLowercased = info.brandName.lowercased()
        let hasDoxycycline = medicationLowercased.contains("doxycycline")
        let hasHyclate = medicationLowercased.contains("hyclate")
        let hasDosage = info.dosage.contains("100")
        
        print("\n✅ Validation:")
        print("  Contains 'Doxycycline': \(hasDoxycycline ? "✅" : "❌")")
        print("  Contains 'Hyclate': \(hasHyclate ? "✅" : "❌")")
        print("  Contains '100 MG': \(hasDosage ? "✅" : "❌")")
        
        #expect(hasDoxycycline, "Medication name should contain 'Doxycycline'")
        #expect(hasDosage, "Dosage should contain '100'")
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
            
            #expect(
                report.averageConfidence > 0.5,
                "OCR confidence for \(testCase.imageName) is too low: \(String(format: "%.1f%%", report.averageConfidence * 100))"
            )
            
            print("")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads a test image from the test bundle
    /// - Parameter imageName: The name of the image file (with or without extension)
    /// - Returns: The loaded UIImage
    /// - Throws: `TestError.imageNotFound` if the image cannot be found or loaded
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
    
    /// Detects medication information from an image using the MedicationAnalyzer (with caching)
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Detected medication information
    /// - Throws: Any errors that occur during detection
    private func detectMedicationInfo(from image: UIImage, cacheKey: String? = nil) async throws -> DetectedMedicationInfo {
        // Check cache first if we have a key
        if let key = cacheKey {
            Self.cacheLock.lock()
            if let cached = Self.cachedResults[key] {
                Self.cacheLock.unlock()
                print("📦 Using cached result for \(key)")
                return cached
            }
            Self.cacheLock.unlock()
        }
        
        // Perform actual detection
        let result = try await withCheckedThrowingContinuation { continuation in
            LabelScanner.shared.scanLabel(image: image) { info in
                continuation.resume(returning: info)
            }
        }
        
        // Cache the result if we have a key
        if let key = cacheKey {
            Self.cacheLock.lock()
            Self.cachedResults[key] = result
            Self.cacheLock.unlock()
        }
        
        return result
    }
    
    /// Recognizes all text in an image using Vision framework
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of recognized text strings, sorted top-to-bottom
    /// - Throws: Any errors that occur during text recognition
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
    
    /// Analyzes OCR confidence metrics for an image
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Report containing confidence statistics
    /// - Throws: `TestError.invalidImage` if the image cannot be converted to CGImage
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
    
    /// Performs fuzzy string matching using Levenshtein distance
    /// - Parameters:
    ///   - str1: First string to compare
    ///   - str2: Second string to compare
    ///   - threshold: Minimum similarity score (0.0-1.0) to consider a match
    /// - Returns: True if the strings match within the threshold
    private func fuzzyMatch(_ str1: String, _ str2: String, threshold: Double = 0.8) -> Bool {
        let similarity = calculateSimilarity(str1, str2)
        return similarity >= threshold
    }
    
    /// Calculates normalized similarity between two strings
    /// - Parameters:
    ///   - str1: First string to compare
    ///   - str2: Second string to compare
    /// - Returns: Similarity score from 0.0 (completely different) to 1.0 (identical)
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = normalize(str1)
        let s2 = normalize(str2)
        
        if s1.isEmpty && s2.isEmpty { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }
        
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Normalizes a string for comparison by removing punctuation, whitespace, and converting to lowercase
    /// - Parameter str: The string to normalize
    /// - Returns: Normalized string suitable for comparison
    private func normalize(_ str: String) -> String {
        return str
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: .punctuationCharacters)
            .joined()
    }
    
    /// Calculates Levenshtein distance between two strings (edit distance)
    /// - Parameters:
    ///   - s1: First string
    ///   - s2: Second string
    /// - Returns: Minimum number of single-character edits needed to transform s1 into s2
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

/// Report containing OCR confidence analysis metrics
struct OCRConfidenceReport {
    /// Average confidence score across all observations (0.0-1.0)
    let averageConfidence: Double
    /// Total number of text observations detected
    let totalObservations: Int
    /// Number of observations with confidence > 80%
    let highConfidenceCount: Int
    /// Number of observations with confidence < 50%
    let lowConfidenceCount: Int
}

/// Errors that can occur during test execution
enum TestError: Error {
    /// The specified test image could not be found in any bundle
    case imageNotFound(String)
    /// The image could not be converted to CGImage
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
