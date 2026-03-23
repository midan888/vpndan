import Foundation

@MainActor
@Observable
final class FavoritesService {
    static let shared = FavoritesService()

    private(set) var favoriteIDs: Set<UUID> = []
    private let key = "vpn_favorite_servers"

    private init() {
        load()
    }

    func isFavorite(_ serverID: UUID) -> Bool {
        favoriteIDs.contains(serverID)
    }

    func toggle(_ serverID: UUID) {
        if favoriteIDs.contains(serverID) {
            favoriteIDs.remove(serverID)
        } else {
            favoriteIDs.insert(serverID)
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
            return
        }
        favoriteIDs = ids
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favoriteIDs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
