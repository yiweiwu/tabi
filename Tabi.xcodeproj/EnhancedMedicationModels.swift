//
//  EnhancedMedicationModels.swift
//  Tabi
//
//  Enhanced medication models with additional metadata for better Visual Intelligence matching
//

import Foundation

// MARK: - Extended Medication Properties

extension Medication {
    /// Enhanced metadata for better Visual Intelligence matching
    struct EnhancedMetadata: Codable {
        var genericName: String?
        var brandNames: [String] = []
        var activeIngredient: String?
        var dosageAmount: String?
        var pillColor: PillColor?
        var pillShape: PillShape?
        var ndcCode: String? // National Drug Code for barcode scanning
        var notes: String?
    }
    
    enum PillColor: String, Codable, CaseIterable {
        case white, yellow, orange, red, pink
        case blue, green, purple, brown, gray, black
        case multicolor
        
        var description: String { rawValue.capitalized }
    }
    
    enum PillShape: String, Codable, CaseIterable {
        case round, oval, capsule, oblong, rectangle
        case triangle, diamond, pentagon, hexagon, octagon
        case other
        
        var description: String { rawValue.capitalized }
    }
}

// MARK: - Medication Search Extensions

extension Medication {
    /// All searchable terms for this medication
    func searchableTerms(with metadata: EnhancedMetadata?) -> [String] {
        var terms = [name.lowercased()]
        
        guard let metadata = metadata else { return terms }
        
        if let generic = metadata.genericName {
            terms.append(generic.lowercased())
        }
        
        terms.append(contentsOf: metadata.brandNames.map { $0.lowercased() })
        
        if let ingredient = metadata.activeIngredient {
            terms.append(ingredient.lowercased())
        }
        
        if let dosage = metadata.dosageAmount {
            terms.append(dosage.lowercased())
        }
        
        if let color = metadata.pillColor {
            terms.append(color.rawValue)
        }
        
        if let shape = metadata.pillShape {
            terms.append(shape.rawValue)
        }
        
        return terms
    }
    
    /// Calculate relevance score for search matching (0.0 to 1.0)
    func relevanceScore(for searchTerms: [String], with metadata: EnhancedMetadata?) -> Double {
        let myTerms = searchableTerms(with: metadata)
        var score: Double = 0.0
        var matchCount = 0
        
        for searchTerm in searchTerms {
            let searchLower = searchTerm.lowercased()
            
            // Exact match = 1.0 point
            if myTerms.contains(where: { $0 == searchLower }) {
                score += 1.0
                matchCount += 1
                continue
            }
            
            // Partial match = 0.5 points
            if myTerms.contains(where: { $0.contains(searchLower) || searchLower.contains($0) }) {
                score += 0.5
                matchCount += 1
                continue
            }
            
            // Fuzzy match = 0.3 points
            if let fuzzyMatch = myTerms.first(where: { levenshteinDistance($0, searchLower) <= 2 }) {
                score += 0.3
                matchCount += 1
            }
        }
        
        // Normalize by number of search terms
        return searchTerms.isEmpty ? 0.0 : score / Double(searchTerms.count)
    }
    
    /// Levenshtein distance for fuzzy matching
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count {
            dist[i][0] = i
        }
        
        for j in 0...s2.count {
            dist[0][j] = j
        }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i-1] == s2[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = min(
                        dist[i-1][j] + 1,      // deletion
                        dist[i][j-1] + 1,      // insertion
                        dist[i-1][j-1] + 1     // substitution
                    )
                }
            }
        }
        
        return dist[s1.count][s2.count]
    }
}

// MARK: - Common Medication Database

struct CommonMedication {
    let name: String
    let genericName: String?
    let brandNames: [String]
    let activeIngredient: String
    let commonDosages: [String]
    let category: MedicationCategory
    
    enum MedicationCategory: String {
        case painRelief = "Pain Relief"
        case antibiotic = "Antibiotic"
        case vitamin = "Vitamin"
        case heartHealth = "Heart Health"
        case diabetes = "Diabetes"
        case mentalHealth = "Mental Health"
        case allergy = "Allergy"
        case other = "Other"
    }
    
    /// Common medications database for autocomplete and suggestion
    static let commonDatabase: [CommonMedication] = [
        // Pain Relief
        CommonMedication(
            name: "Aspirin",
            genericName: "Acetylsalicylic Acid",
            brandNames: ["Bayer", "Bufferin", "Ecotrin"],
            activeIngredient: "Aspirin",
            commonDosages: ["81mg", "325mg", "500mg"],
            category: .painRelief
        ),
        CommonMedication(
            name: "Ibuprofen",
            genericName: nil,
            brandNames: ["Advil", "Motrin", "Nurofen"],
            activeIngredient: "Ibuprofen",
            commonDosages: ["200mg", "400mg", "600mg", "800mg"],
            category: .painRelief
        ),
        CommonMedication(
            name: "Acetaminophen",
            genericName: nil,
            brandNames: ["Tylenol", "Paracetamol"],
            activeIngredient: "Acetaminophen",
            commonDosages: ["325mg", "500mg", "650mg"],
            category: .painRelief
        ),
        
        // Vitamins
        CommonMedication(
            name: "Vitamin D",
            genericName: "Cholecalciferol",
            brandNames: ["Vitamin D3"],
            activeIngredient: "Vitamin D3",
            commonDosages: ["1000 IU", "2000 IU", "5000 IU"],
            category: .vitamin
        ),
        CommonMedication(
            name: "Multivitamin",
            genericName: nil,
            brandNames: ["Centrum", "One A Day", "Nature Made"],
            activeIngredient: "Mixed vitamins",
            commonDosages: ["Daily"],
            category: .vitamin
        ),
        CommonMedication(
            name: "Fish Oil",
            genericName: "Omega-3 Fatty Acids",
            brandNames: ["Nordic Naturals", "Nature Made"],
            activeIngredient: "EPA/DHA",
            commonDosages: ["1000mg", "1200mg"],
            category: .vitamin
        ),
        
        // Antibiotics
        CommonMedication(
            name: "Amoxicillin",
            genericName: nil,
            brandNames: ["Amoxil", "Moxatag"],
            activeIngredient: "Amoxicillin",
            commonDosages: ["250mg", "500mg", "875mg"],
            category: .antibiotic
        ),
        
        // Allergy
        CommonMedication(
            name: "Cetirizine",
            genericName: nil,
            brandNames: ["Zyrtec", "Alleroff"],
            activeIngredient: "Cetirizine",
            commonDosages: ["5mg", "10mg"],
            category: .allergy
        ),
        CommonMedication(
            name: "Loratadine",
            genericName: nil,
            brandNames: ["Claritin", "Alavert"],
            activeIngredient: "Loratadine",
            commonDosages: ["10mg"],
            category: .allergy
        ),
    ]
    
    /// Find common medication by any name
    static func find(matching term: String) -> CommonMedication? {
        let termLower = term.lowercased()
        return commonDatabase.first { medication in
            medication.name.lowercased().contains(termLower) ||
            (medication.genericName?.lowercased().contains(termLower) ?? false) ||
            medication.brandNames.contains(where: { $0.lowercased().contains(termLower) }) ||
            medication.activeIngredient.lowercased().contains(termLower)
        }
    }
    
    /// Get suggestions based on partial input
    static func suggestions(for term: String, limit: Int = 5) -> [CommonMedication] {
        let termLower = term.lowercased()
        return commonDatabase.filter { medication in
            medication.name.lowercased().hasPrefix(termLower) ||
            (medication.genericName?.lowercased().hasPrefix(termLower) ?? false) ||
            medication.brandNames.contains(where: { $0.lowercased().hasPrefix(termLower) })
        }.prefix(limit).map { $0 }
    }
}
