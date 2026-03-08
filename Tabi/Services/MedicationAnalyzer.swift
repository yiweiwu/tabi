import Vision
import UIKit

// MARK: - Medication Analyzer (AI Vision)

class MedicationAnalyzer {
    static let shared = MedicationAnalyzer()

    struct AnalysisResult {
        let isMatch: Bool
        let confidence: Double
        let detectedText: [String]
        let colorProfile: String
        let shapeDetected: Bool
        let validMedicationDetected: Bool
        let matchedTerms: [String]
    }

    // MARK: - Pill verification (for logging an existing medication)

    func analyzePill(image: UIImage, expectedMedication: Medication, completion: @escaping (AnalysisResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(AnalysisResult(isMatch: false, confidence: 0.0, detectedText: [], colorProfile: "unknown", shapeDetected: false, validMedicationDetected: false, matchedTerms: []))
            return
        }

        var detectedTexts: [String] = []
        var hasShape = false
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        recognizeText(in: cgImage) { texts in detectedTexts = texts; dispatchGroup.leave() }

        dispatchGroup.enter()
        detectPillShape(in: cgImage) { detected in hasShape = detected; dispatchGroup.leave() }

        dispatchGroup.notify(queue: .main) {
            let colorProfile = self.analyzeColor(image: image)
            let validationResult = self.validateMedicationText(detectedTexts: detectedTexts, expectedMedication: expectedMedication)
            let confidence = self.calculateConfidence(textMatch: validationResult.isMatch, hasShape: hasShape, colorProfile: colorProfile, hasValidMedTerms: validationResult.hasValidTerms)
            completion(AnalysisResult(isMatch: confidence > 0.5, confidence: confidence, detectedText: detectedTexts, colorProfile: colorProfile, shapeDetected: hasShape, validMedicationDetected: validationResult.hasValidTerms, matchedTerms: validationResult.matchedTerms))
        }
    }

    // MARK: - Label scan (for adding a new medication)

    func detectMedicationFromLabel(image: UIImage, completion: @escaping (DetectedMedicationInfo) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(DetectedMedicationInfo(medicationName: "Unknown Medication", schedule: "Daily", dosage: "Unknown", scheduleTime: Date(), allDetectedText: []))
            return
        }

        recognizeText(in: cgImage) { detectedTexts in
            print("📝 Detected texts from label:")
            detectedTexts.forEach { print("  - \($0)") }
            let info = self.extractMedicationInfo(from: detectedTexts)
            completion(info)
        }
    }

    // MARK: - Private helpers

    private func extractMedicationInfo(from texts: [String]) -> DetectedMedicationInfo {
        var medicationName = "Unknown Medication"
        var schedule = "Take as directed"
        var dosage = ""
        var scheduleTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

        let medicationKeywords = [
            "hydrocodone", "acetaminophen", "acetamin",
            "doxycycline", "hyclate",
            "vitamin", "ibuprofen", "amoxicillin",
            "lisinopril", "metformin", "atorvastatin", "omeprazole"
        ]
        let dosagePattern = /(\d+[-\s]?\d*\s*(MG|MCG|mg|mcg))/
        let scheduleKeywords = ["daily", "twice", "once", "every", "morning", "evening", "night", "take"]

        // Find dosage
        var dosageIndex: Int?
        for (index, text) in texts.enumerated() {
            if let match = text.firstMatch(of: dosagePattern) {
                dosage = String(match.0); dosageIndex = index
                print("✅ Found dosage at index \(index): \(dosage)")
                break
            }
        }

        // Find medication name near dosage
        if let dosageIdx = dosageIndex {
            let searchRange = max(0, dosageIdx - 3)..<dosageIdx
            outer: for index in searchRange.reversed() {
                let text = texts[index]
                let lowerText = text.lowercased()
                for keyword in medicationKeywords where lowerText.contains(keyword) {
                    var fullName = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if index + 1 < texts.count && index + 1 < dosageIdx {
                        let nextLine = texts[index + 1].lowercased()
                        for nextKeyword in medicationKeywords where nextLine.contains(nextKeyword) {
                            fullName += " " + texts[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                    medicationName = cleanAndCapitalize(fullName)
                    print("✅ Found medication name near dosage: \(medicationName)")
                    break outer
                }
            }
        }

        // Fallback: search first 5 lines
        if medicationName == "Unknown Medication" {
            outer: for (index, text) in texts.enumerated() where index < 5 {
                let lowerText = text.lowercased()
                for keyword in medicationKeywords where lowerText.contains(keyword) {
                    var fullName = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if index + 1 < min(texts.count, 5) {
                        let nextLine = texts[index + 1].lowercased()
                        for nextKeyword in medicationKeywords where nextLine.contains(nextKeyword) {
                            fullName += " " + texts[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                    medicationName = cleanAndCapitalize(fullName)
                    print("✅ Found medication name (fallback): \(medicationName)")
                    break outer
                }
            }
        }

        // Extract schedule
        for text in texts {
            let lowerText = text.lowercased()
            if scheduleKeywords.contains(where: { lowerText.contains($0) }) {
                schedule = text
                if lowerText.contains("morning") { scheduleTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date() }
                else if lowerText.contains("evening") || lowerText.contains("night") { scheduleTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date() }
                else if lowerText.contains("twice") { scheduleTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date() }
                break
            }
        }

        print("📊 Final: medication=\(medicationName), dosage=\(dosage), schedule=\(schedule)")
        return DetectedMedicationInfo(medicationName: medicationName, schedule: schedule, dosage: dosage, scheduleTime: scheduleTime, allDetectedText: texts)
    }

    private func cleanAndCapitalize(_ text: String) -> String {
        text.replacingOccurrences(of: "-\n", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                return lower == "and" || lower == "with" ? lower : word.capitalized
            }
            .joined(separator: " ")
    }

    private func validateMedicationText(detectedTexts: [String], expectedMedication: Medication) -> (isMatch: Bool, hasValidTerms: Bool, matchedTerms: [String]) {
        let medKeywords = ["mg", "mcg", "tablet", "capsule", "pill", "dose", "rx", "vitamin", "daily", "once", "twice", "take"]
        var matchedTerms: [String] = []
        var hasValidTerms = false
        var isExactMatch = false

        let allText = detectedTexts.joined(separator: " ").lowercased()
        let expectedName = expectedMedication.name.lowercased()
        let medicationWords = expectedName
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }

        func fuzzyMatch(_ word1: String, _ word2: String) -> Bool {
            let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if w1 == w2 || w1.contains(w2) || w2.contains(w1) { return true }
            let minLength = min(w1.count, w2.count)
            if minLength >= 4 && w1.prefix(min(minLength, 7)) == w2.prefix(min(minLength, 7)) { return true }
            return stringSimilarity(w1, w2) > 0.75
        }

        func stringSimilarity(_ s1: String, _ s2: String) -> Double {
            let longer = s1.count > s2.count ? s1 : s2
            let shorter = s1.count > s2.count ? s2 : s1
            if longer.count == 0 { return 1.0 }
            let editDistance = levenshteinDistance(Array(shorter), Array(longer))
            return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
        }

        func levenshteinDistance(_ s1: [Character], _ s2: [Character]) -> Int {
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

        for medWord in medicationWords {
            if allText.contains(medWord) { isExactMatch = true; break }
            for detectedText in detectedTexts {
                let words = detectedText.lowercased().components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }
                if words.contains(where: { fuzzyMatch(medWord, $0) }) { isExactMatch = true; break }
            }
            if isExactMatch { break }
        }

        for text in detectedTexts {
            let lowerText = text.lowercased()
            let textWords = lowerText.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }
            var isRelevant = medicationWords.contains { medWord in lowerText.contains(medWord) || textWords.contains { fuzzyMatch(medWord, $0) } }
            if !isRelevant && medKeywords.contains(where: { lowerText.contains($0) }) { isRelevant = true; hasValidTerms = true }
            if isRelevant { matchedTerms.append(text) }
        }

        matchedTerms = deduplicateMatchedTerms(matchedTerms).prefix(3).map { String($0) }
        return (isExactMatch, hasValidTerms, matchedTerms)
    }

    private func deduplicateMatchedTerms(_ terms: [String]) -> [String] {
        func normalize(_ text: String) -> String {
            text.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                .components(separatedBy: CharacterSet.punctuationCharacters).joined()
        }
        var uniqueTerms: [String] = []
        var seenNormalized: Set<String> = []
        for term in terms {
            let normalized = normalize(term)
            if !seenNormalized.contains(normalized) {
                uniqueTerms.append(term)
                seenNormalized.insert(normalized)
            } else if let existingIndex = uniqueTerms.firstIndex(where: { normalize($0) == normalized }) {
                let existingScore = uniqueTerms[existingIndex].filter { $0 == " " || $0 == "-" }.count
                let newScore = term.filter { $0 == " " || $0 == "-" }.count
                if newScore > existingScore { uniqueTerms[existingIndex] = term }
            }
        }
        return uniqueTerms
    }

    private func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([]); return
            }
            let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            var allTexts: [(text: String, isBold: Bool)] = []
            for (index, observation) in sorted.enumerated() {
                let isBold = self.isBoldText(observation: observation, in: image)
                for candidate in observation.topCandidates(3) {
                    allTexts.append((candidate.string, isBold))
                    let boldIndicator = isBold ? "📌 BOLD" : "📄 normal"
                    print("📝 Line \(index): '\(candidate.string)' [\(boldIndicator)]")
                }
            }
            let uniqueTexts = Array(Set(allTexts.map { $0.text }))
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted()
            completion(uniqueTexts)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }

    private func isBoldText(observation: VNRecognizedTextObservation, in image: CGImage) -> Bool {
        let bb = observation.boundingBox
        let rect = CGRect(
            x: bb.origin.x * CGFloat(image.width),
            y: (1 - bb.origin.y - bb.height) * CGFloat(image.height),
            width: bb.width * CGFloat(image.width),
            height: bb.height * CGFloat(image.height)
        )
        guard let cropped = image.cropping(to: rect) else { return false }
        return calculatePixelDensity(in: cropped) > 0.35
    }

    private func calculatePixelDensity(in image: CGImage) -> Double {
        let width = image.width, height = image.height, bytesPerPixel = 4
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0.0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return 0.0 }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        var darkPixels = 0
        let sampleRate = 2
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let offset = (y * width + x) * bytesPerPixel
                if (Int(buffer[offset]) + Int(buffer[offset + 1]) + Int(buffer[offset + 2])) / 3 < 128 { darkPixels += 1 }
            }
        }
        return Double(darkPixels) / Double((width / sampleRate) * (height / sampleRate))
    }

    private func detectPillShape(in image: CGImage, completion: @escaping (Bool) -> Void) {
        let request = VNDetectContoursRequest { request, error in
            guard error == nil, let observations = request.results as? [VNContoursObservation] else { completion(false); return }
            completion(!observations.isEmpty)
        }
        request.contrastAdjustment = 1.5
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }

    private func analyzeColor(image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "unknown" }
        let ciImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else { return "unknown" }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: kCFNull as Any]).render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let r = bitmap[0], g = bitmap[1], b = bitmap[2]
        if r > 200 && g > 200 && b > 200 { return "white" }
        if r > 150 && g < 100 && b < 100 { return "red" }
        if r < 100 && g < 100 && b > 150 { return "blue" }
        if r > 150 && g > 150 && b < 100 { return "yellow" }
        if r > 150 && g > 100 && b < 100 { return "orange" }
        return "other"
    }

    private func calculateConfidence(textMatch: Bool, hasShape: Bool, colorProfile: String, hasValidMedTerms: Bool) -> Double {
        var confidence = 0.2
        if textMatch { confidence += 0.5 } else if hasValidMedTerms { confidence += 0.2 }
        if hasShape { confidence += 0.2 }
        if colorProfile != "unknown" { confidence += 0.1 }
        return min(confidence, 1.0)
    }
}
