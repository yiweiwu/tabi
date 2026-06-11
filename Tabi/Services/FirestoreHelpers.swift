import Foundation

extension Encodable {
    func firestoreDict() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return dict
    }
}

extension Decodable {
    static func decoded(from dict: [String: Any]) -> Self? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return value
    }
}
