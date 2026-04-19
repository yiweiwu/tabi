import Foundation

// MARK: - Gemini Service
// Handles structured extraction of medication info from OCR text via the Gemini API.

class GeminiService {
    static let shared = GeminiService()

    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    func extractMedicationInfo(from ocrTexts: [String]) async -> DetectedMedicationInfo {
        let prompt = """
        The following text was read from a curved prescription pill bottle label via OCR and may contain character errors. \
        Extract the medication names, dosage strength, and dosing instructions.

        Rules for names:
        - If only one name is present, put it in genericName and leave brandName empty.
        - If the label says "Generic for [Name]" or lists a brand name separately, put the brand in brandName.
        - If no brand is mentioned, leave brandName empty.

        OCR text:
        \(ocrTexts.joined(separator: "\n"))

        Return the output in JSON format matching the requested schema.
        """

        guard let url = URL(string: "\(endpoint)?key=\(Config.geminiAPIKey)"),
              let body = try? JSONSerialization.data(withJSONObject: requestBody(prompt: prompt)) else {
            return .empty(ocrTexts: ocrTexts)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return parseResponse(data: data, ocrTexts: ocrTexts)
        } catch {
            print("❌ Gemini network error: \(error)")
            return .empty(ocrTexts: ocrTexts)
        }
    }
}

// MARK: - Private

private extension GeminiService {
    func requestBody(prompt: String) -> [String: Any] {
        [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "object",
                    "properties": [
                        "brandName": ["type": "string"],
                        "genericName": ["type": "string"],
                        "dosage": ["type": "string"],
                        "schedule": ["type": "string"]
                    ],
                    "required": ["brandName", "genericName", "dosage", "schedule"]
                ]
            ]
        ]
    }

    func parseResponse(data: Data, ocrTexts: [String]) -> DetectedMedicationInfo {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let textData = text.data(using: .utf8),
              let extracted = try? JSONSerialization.jsonObject(with: textData) as? [String: Any] else {
            print("❌ Gemini: failed to parse response — raw: \(String(data: data, encoding: .utf8) ?? "nil")")
            return .empty(ocrTexts: ocrTexts)
        }

        let brandName = extracted["brandName"] as? String ?? ""
        let genericName = extracted["genericName"] as? String ?? ""
        let dosage = extracted["dosage"] as? String ?? ""
        let schedule = extracted["schedule"] as? String ?? ""
        print("✅ Gemini: brand='\(brandName)' generic='\(genericName)' dosage='\(dosage)'")
        return DetectedMedicationInfo(
            brandName: brandName,
            genericName: genericName,
            schedule: schedule,
            dosage: dosage,
            scheduleTime: scheduleTime(from: schedule),
            allDetectedText: ocrTexts
        )
    }

    func scheduleTime(from schedule: String) -> Date {
        let lower = schedule.lowercased()
        let hour: Int
        if lower.contains("morning") { hour = 8 }
        else if lower.contains("evening") || lower.contains("night") || lower.contains("bedtime") { hour = 20 }
        else if lower.contains("noon") || lower.contains("twice") { hour = 12 }
        else { hour = 9 }
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - DetectedMedicationInfo convenience

extension DetectedMedicationInfo {
    static func empty(ocrTexts: [String] = []) -> DetectedMedicationInfo {
        DetectedMedicationInfo(brandName: "", genericName: "", schedule: "", dosage: "", scheduleTime: Date(), allDetectedText: ocrTexts)
    }
}
