import Vision
import UIKit

// MARK: - Pill Verifier (dose logging flow)
// Analyzes a captured pill photo against an expected medication using Vision OCR,
// shape detection, and color analysis.

class PillVerifier {
    static let shared = PillVerifier()

    struct AnalysisResult {
        let isMatch: Bool
        let confidence: Double
        let detectedText: [String]
        let colorProfile: String
        let shapeDetected: Bool
        let validMedicationDetected: Bool
        let matchedTerms: [String]
    }

    func analyzePill(image: UIImage, expectedMedication: Medication, completion: @escaping (AnalysisResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(AnalysisResult(isMatch: false, confidence: 0, detectedText: [], colorProfile: "unknown", shapeDetected: false, validMedicationDetected: false, matchedTerms: []))
            return
        }

        var detectedTexts: [String] = []
        var hasShape = false
        let group = DispatchGroup()

        group.enter()
        recognizeText(in: cgImage) { detectedTexts = $0; group.leave() }

        group.enter()
        detectPillShape(in: cgImage) { hasShape = $0; group.leave() }

        group.notify(queue: .main) {
            let colorProfile = self.analyzeColor(image: image)
            let validation = self.validateMedicationText(detectedTexts: detectedTexts, expectedMedication: expectedMedication)
            let score = self.confidenceScore(textMatch: validation.isMatch, hasShape: hasShape, colorProfile: colorProfile, hasValidMedTerms: validation.hasValidTerms)
            completion(AnalysisResult(
                isMatch: score > 0.5,
                confidence: score,
                detectedText: detectedTexts,
                colorProfile: colorProfile,
                shapeDetected: hasShape,
                validMedicationDetected: validation.hasValidTerms,
                matchedTerms: validation.matchedTerms
            ))
        }
    }
}

// MARK: - Validation

private extension PillVerifier {
    func validateMedicationText(detectedTexts: [String], expectedMedication: Medication) -> (isMatch: Bool, hasValidTerms: Bool, matchedTerms: [String]) {
        let medKeywords = ["mg", "mcg", "tablet", "capsule", "pill", "dose", "rx", "vitamin", "daily", "once", "twice", "take"]
        let allText = detectedTexts.joined(separator: " ").lowercased()
        let medicationWords = expectedMedication.name.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }

        var isMatch = false
        outer: for medWord in medicationWords {
            if allText.contains(medWord) { isMatch = true; break }
            for text in detectedTexts {
                let words = text.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                if words.contains(where: { fuzzyMatch($0, medWord) }) { isMatch = true; break outer }
            }
        }

        var hasValidTerms = false
        var matchedTerms: [String] = []
        for text in detectedTexts {
            let lower = text.lowercased()
            let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }
            let medNameMatch = medicationWords.contains { lower.contains($0) || words.contains { fuzzyMatch($0, $0) } }
            let keywordMatch = medKeywords.contains { lower.contains($0) }
            if medNameMatch || keywordMatch {
                if keywordMatch { hasValidTerms = true }
                matchedTerms.append(text)
            }
        }

        return (isMatch, hasValidTerms, Array(deduplicated(matchedTerms).prefix(3)))
    }

    func confidenceScore(textMatch: Bool, hasShape: Bool, colorProfile: String, hasValidMedTerms: Bool) -> Double {
        var score = 0.2
        if textMatch { score += 0.5 } else if hasValidMedTerms { score += 0.2 }
        if hasShape { score += 0.2 }
        if colorProfile != "unknown" { score += 0.1 }
        return min(score, 1.0)
    }

    func deduplicated(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        return terms.filter { seen.insert(normalized($0)).inserted }
    }

    func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .components(separatedBy: .punctuationCharacters).joined()
    }
}

// MARK: - Fuzzy Matching

private extension PillVerifier {
    func fuzzyMatch(_ a: String, _ b: String) -> Bool {
        let w1 = a.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let w2 = b.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if w1 == w2 || w1.contains(w2) || w2.contains(w1) { return true }
        let minLen = min(w1.count, w2.count)
        if minLen >= 4 && w1.prefix(min(minLen, 7)) == w2.prefix(min(minLen, 7)) { return true }
        return similarity(w1, w2) > 0.75
    }

    func similarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        guard !longer.isEmpty else { return 1.0 }
        let distance = levenshtein(Array(shorter), Array(longer))
        return (Double(longer.count) - Double(distance)) / Double(longer.count)
    }

    func levenshtein(_ s1: [Character], _ s2: [Character]) -> Int {
        let m = s1.count, n = s2.count
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                matrix[i][j] = min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
            }
        }
        return matrix[m][n]
    }
}

// MARK: - Vision Helpers

private extension PillVerifier {
    func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([]); return
            }
            let texts = observations
                .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                .compactMap { obs -> String? in
                    let text = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return text.isEmpty ? nil : text
                }
            completion(texts)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    }

    func detectPillShape(in image: CGImage, completion: @escaping (Bool) -> Void) {
        let request = VNDetectContoursRequest { request, error in
            guard error == nil, let observations = request.results as? [VNContoursObservation] else {
                completion(false); return
            }
            completion(!observations.isEmpty)
        }
        request.contrastAdjustment = 1.5
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    }

    func analyzeColor(image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "unknown" }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extent]),
              let output = filter.outputImage else { return "unknown" }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: kCFNull as Any]).render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let (r, g, b) = (bitmap[0], bitmap[1], bitmap[2])
        if r > 200 && g > 200 && b > 200 { return "white" }
        if r > 150 && g < 100 && b < 100 { return "red" }
        if r < 100 && g < 100 && b > 150 { return "blue" }
        if r > 150 && g > 150 && b < 100 { return "yellow" }
        if r > 150 && g > 100 && b < 100 { return "orange" }
        return "other"
    }
}
