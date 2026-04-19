import Vision
import UIKit

// MARK: - Label Scanner (add new medication flow)
// Runs Vision OCR on a prescription label photo, then delegates to GeminiService
// for structured extraction of medication name, dosage, and schedule.

class LabelScanner {
    static let shared = LabelScanner()

    func scanLabel(image: UIImage, completion: @escaping (DetectedMedicationInfo) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.empty()); return
        }
        recognizeText(in: cgImage) { texts in
            print("📝 Vision OCR: \(texts.count) lines")
            texts.forEach { print("  - \($0)") }
            Task {
                let info = await GeminiService.shared.extractMedicationInfo(from: texts)
                await MainActor.run { completion(info) }
            }
        }
    }
}

// MARK: - Vision OCR

private extension LabelScanner {
    func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([]); return
            }
            // Sort top-to-bottom (higher y = higher on screen in Vision coordinate space)
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
}
