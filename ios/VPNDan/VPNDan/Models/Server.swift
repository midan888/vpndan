import Foundation

struct Server: Codable, Identifiable {
    let id: UUID
    let name: String
    let country: String
    let host: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, country, host
        case isActive = "is_active"
    }
}
