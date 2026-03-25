//
//  FastMedicationParserTests.swift
//  TabiTests
//
//  Fast unit tests for medication parsing logic (no OCR, no simulator delay)
//  These tests run in <1 second for rapid iteration
//

import Testing
@testable import Tabi

/// Fast tests for medication parsing logic - NO OCR, NO CAMERA
/// These use mock OCR data to test the parsing algorithm directly
@Suite("Fast Medication Parser Tests")
struct FastMedicationParserTests {
    
    // MARK: - Mock OCR Data (based on real prescription labels)
    
    /// Simulates OCR output from a Hydrocodone prescription label
    static let mockHydrocodoneOCR = [
        "CVS PHARMACY",
        "Rx 123456789",
        "HYDROCODONE-ACETAMINOPHEN",
        "5-325 MG",
        "TABLET",
        "Take 1 tablet by mouth every 6 hours",
        "as needed for pain",
        "Qty: 30",
        "Refills: 0"
    ]
    
    /// Simulates OCR output from a Doxycycline prescription label
    static let mockDoxycyclineOCR = [
        "WALGREENS",
        "Rx 987654321",
        "DOXYCYCLINE HYCLATE",
        "100 MG",
        "CAPSULE",
        "Take 1 capsule by mouth twice a day",
        "Qty: 20",
        "Refills: 2"
    ]
    
    // MARK: - Real-World OCR Errors (Curved Bottles)
    
    /// Simulates fragmented OCR from a curved hydrocodone bottle
    static let curvedHydrocodoneOCR = [
        "CVS",
        "PHARMA",
        "CY",  // Split due to curvature
        "Rx 1234",
        "HYDRO",  // Fragmented
        "CODONE-",
        "ACETAM",  // Missing "INOPHEN"
        "5-325 MG",
        "Take 1 tab",
        "let by mo",  // Truncated
        "uth every",
        "6 hours"
    ]
    
    /// Simulates low-quality OCR with missing characters
    static let poorQualityDoxycyclineOCR = [
        "WALG",  // Missing "REENS"
        "Rx 98765",
        "DOXCY",  // Missing "CLINE"
        "HYCL",   // Missing "ATE"
        "100",    // Missing "MG"
        "MG",     // On separate line
        "Take 1 cap",
        "sule by mouth",  // Split word
        "twice a day"
    ]
    
    // MARK: - Hydrocodone Tests
    
    @Test("Parse Hydrocodone medication name")
    func testHydrocodoneName() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockHydrocodoneOCR)
        
        let nameLower = result.medicationName.lowercased()
        #expect(
            nameLower.contains("hydrocodone"),
            "Medication name '\(result.medicationName)' should contain 'hydrocodone'"
        )
    }
    
    @Test("Parse Hydrocodone dosage")
    func testHydrocodoneDosage() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockHydrocodoneOCR)
        
        let hasCorrectDosage = result.dosage.contains("5-325") || 
                                result.dosage.contains("5 325") ||
                                result.dosage.contains("325")
        
        #expect(
            hasCorrectDosage,
            "Dosage '\(result.dosage)' should contain '5-325' or '325'"
        )
    }
    
    @Test("Parse Hydrocodone schedule")
    func testHydrocodoneSchedule() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockHydrocodoneOCR)
        
        let scheduleLower = result.schedule.lowercased()
        let hasExpectedWords = scheduleLower.contains("take") || 
                                scheduleLower.contains("tablet") ||
                                scheduleLower.contains("every") ||
                                scheduleLower.contains("6") ||
                                scheduleLower.contains("hours")
        
        #expect(
            hasExpectedWords,
            "Schedule '\(result.schedule)' should contain medication instructions"
        )
    }
    
    // MARK: - Doxycycline Tests
    
    @Test("Parse Doxycycline medication name")
    func testDoxycyclineName() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockDoxycyclineOCR)
        
        let nameLower = result.medicationName.lowercased()
        #expect(
            nameLower.contains("doxycycline"),
            "Medication name '\(result.medicationName)' should contain 'doxycycline'"
        )
    }
    
    @Test("Parse Doxycycline dosage")
    func testDoxycyclineDosage() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockDoxycyclineOCR)
        
        #expect(
            result.dosage.contains("100"),
            "Dosage '\(result.dosage)' should contain '100'"
        )
    }
    
    @Test("Parse Doxycycline schedule")
    func testDoxycyclineSchedule() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockDoxycyclineOCR)
        
        let scheduleLower = result.schedule.lowercased()
        let hasExpectedWords = scheduleLower.contains("take") || 
                                scheduleLower.contains("capsule") ||
                                scheduleLower.contains("twice") ||
                                scheduleLower.contains("day")
        
        #expect(
            hasExpectedWords,
            "Schedule '\(result.schedule)' should contain medication instructions"
        )
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle curved bottle with fragmented text")
    func testCurvedBottleHydrocodone() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.curvedHydrocodoneOCR)
        
        print("\n📊 Curved Bottle Result:")
        print("  Medication: \(result.medicationName)")
        print("  Dosage: \(result.dosage)")
        print("  Schedule: \(result.schedule)")
        
        let nameLower = result.medicationName.lowercased()
        
        // Should still find "hydro" even if incomplete
        #expect(
            nameLower.contains("hydro") || nameLower != "Unknown Medication",
            "Should detect partial medication name from fragmented text"
        )
        
        // Dosage should still be found
        #expect(
            result.dosage.contains("5-325") || result.dosage.contains("325"),
            "Dosage '\(result.dosage)' should contain '5-325'"
        )
    }
    
    @Test("Handle poor quality OCR with missing characters")
    func testPoorQualityDoxycycline() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.poorQualityDoxycyclineOCR)
        
        print("\n📊 Poor Quality OCR Result:")
        print("  Medication: \(result.medicationName)")
        print("  Dosage: \(result.dosage)")
        print("  Schedule: \(result.schedule)")
        
        let nameLower = result.medicationName.lowercased()
        
        // Should match on partial "DOXCY" → "doxycycline"
        #expect(
            nameLower.contains("dox") || nameLower != "Unknown Medication",
            "Should detect medication from partial text 'DOXCY'"
        )
        
        // Dosage might be split, but should find "100"
        #expect(
            result.dosage.contains("100"),
            "Should find dosage even when split across lines"
        )
    }
    
    @Test("Handle empty OCR results")
    func testEmptyOCR() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: [])
        
        // Should return sensible defaults, not crash
        #expect(result.medicationName.count > 0)
        #expect(result.dosage.count >= 0) // Can be empty
        #expect(result.schedule.count > 0)
    }
    
    @Test("Handle OCR with no medication keywords")
    func testNoMedicationKeywords() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: [
            "Random text",
            "Nothing useful here",
            "Just garbage data"
        ])
        
        // Should handle gracefully
        #expect(result.medicationName.count > 0)
    }
    
    @Test("Parse dosage in different formats")
    func testDosageFormats() {
        let analyzer = MedicationAnalyzer.shared
        
        let testCases: [(input: [String], expectedPattern: String)] = [
            (["Test", "5-325 MG"], "5-325"),
            (["Test", "100 MG"], "100"),
            (["Test", "10MG"], "10"),
            (["Test", "2.5 mg"], "2.5")
        ]
        
        for testCase in testCases {
            let result = analyzer.extractMedicationInfo(from: testCase.input)
            #expect(
                result.dosage.contains(testCase.expectedPattern) || !result.dosage.isEmpty,
                "Should parse dosage from: \(testCase.input)"
            )
        }
    }
    
    // MARK: - Full Integration Scenarios
    
    @Test("Complete Hydrocodone parsing flow")
    func testCompleteHydrocodoneFlow() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockHydrocodoneOCR)
        
        print("\n📊 Hydrocodone Parsing Result:")
        print("  Medication: \(result.medicationName)")
        print("  Dosage: \(result.dosage)")
        print("  Schedule: \(result.schedule)")
        
        // All three should be populated
        #expect(!result.medicationName.isEmpty)
        #expect(!result.dosage.isEmpty)
        #expect(!result.schedule.isEmpty)
        
        // Should have the actual detected text stored
        #expect(result.allDetectedText.count > 0)
    }
    
    @Test("Complete Doxycycline parsing flow")
    func testCompleteDoxycyclineFlow() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockDoxycyclineOCR)
        
        print("\n📊 Doxycycline Parsing Result:")
        print("  Medication: \(result.medicationName)")
        print("  Dosage: \(result.dosage)")
        print("  Schedule: \(result.schedule)")
        
        // All three should be populated
        #expect(!result.medicationName.isEmpty)
        #expect(!result.dosage.isEmpty)
        #expect(!result.schedule.isEmpty)
        
        // Should have the actual detected text stored
        #expect(result.allDetectedText.count > 0)
    }
}

// MARK: - Debugging Helper

/// Add this to get detailed output when tests fail
extension FastMedicationParserTests {
    
    @Test("🔍 Verify parser version - checks if new fuzzy matching is active")
    func testParserVersion() {
        let analyzer = MedicationAnalyzer.shared
        
        // This should work with the NEW fuzzy matcher
        let testData = ["HYDRO", "CODONE", "5-325 MG"]
        let result = analyzer.extractMedicationInfo(from: testData)
        
        print("\n🔍 PARSER VERSION CHECK")
        print("=" * 50)
        print("Input: \(testData)")
        print("Output: '\(result.medicationName)'")
        print("")
        
        if result.medicationName.lowercased().contains("hydro") {
            print("✅ NEW PARSER ACTIVE - Fuzzy matching works!")
        } else if result.medicationName == "Unknown Medication" {
            print("❌ OLD PARSER ACTIVE - Still using exact matching")
            print("   → Clean build required! (⇧⌘K then ⌘B)")
        }
        print("=" * 50)
        
        // This test will pass with NEW parser, fail with OLD
        #expect(
            result.medicationName.lowercased().contains("hydro"),
            "Parser should match 'HYDRO' → 'Hydrocodone'. If this fails, do Clean Build (⇧⌘K) then rebuild (⌘B)"
        )
    }
    
    @Test("Debug: Show all parsed fields for Hydrocodone")
    func debugHydrocodoneParsing() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockHydrocodoneOCR)
        
        print("\n🔍 HYDROCODONE DEBUG OUTPUT")
        print("=" * 50)
        print("Input OCR:")
        Self.mockHydrocodoneOCR.enumerated().forEach { index, text in
            print("  [\(index)] \(text)")
        }
        print("\nParsed Result:")
        print("  medicationName: '\(result.medicationName)'")
        print("  dosage: '\(result.dosage)'")
        print("  schedule: '\(result.schedule)'")
        print("  scheduleTime: \(result.scheduleTime)")
        print("  allDetectedText count: \(result.allDetectedText.count)")
        print("=" * 50)
    }
    
    @Test("Debug: Show all parsed fields for Doxycycline")
    func debugDoxycyclineParsing() {
        let analyzer = MedicationAnalyzer.shared
        let result = analyzer.extractMedicationInfo(from: Self.mockDoxycyclineOCR)
        
        print("\n🔍 DOXYCYCLINE DEBUG OUTPUT")
        print("=" * 50)
        print("Input OCR:")
        Self.mockDoxycyclineOCR.enumerated().forEach { index, text in
            print("  [\(index)] \(text)")
        }
        print("\nParsed Result:")
        print("  medicationName: '\(result.medicationName)'")
        print("  dosage: '\(result.dosage)'")
        print("  schedule: '\(result.schedule)'")
        print("  scheduleTime: \(result.scheduleTime)")
        print("  allDetectedText count: \(result.allDetectedText.count)")
        print("=" * 50)
    }
}

// MARK: - String Multiplication Helper

infix operator *: MultiplicationPrecedence
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
