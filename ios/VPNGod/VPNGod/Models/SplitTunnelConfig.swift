import Foundation

struct SplitTunnelConfig: Codable {
    var isEnabled: Bool = false
    var enabledPresets: Set<SplitTunnelPreset> = []
    var excludedEntries: [ExcludedEntry] = []

    var allExcludedCIDRs: [String] {
        guard isEnabled else { return [] }
        var routes: [String] = []
        for preset in enabledPresets {
            routes.append(contentsOf: preset.routes)
        }
        for entry in excludedEntries where entry.type == .ip {
            routes.append(entry.value)
        }
        return routes
    }

    var excludedDomains: [String] {
        guard isEnabled else { return [] }
        return excludedEntries.filter { $0.type == .domain }.map(\.value)
    }
}

struct ExcludedEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let value: String
    let type: EntryType

    init(value: String, type: EntryType) {
        self.id = UUID()
        self.value = value
        self.type = type
    }

    enum EntryType: String, Codable {
        case ip
        case domain
    }

    var icon: String {
        switch type {
        case .ip: return "network"
        case .domain: return "globe"
        }
    }
}

enum SplitTunnelPreset: String, Codable, CaseIterable, Identifiable {
    case localNetwork
    case lanServices

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localNetwork: return "Local Network"
        case .lanServices: return "LAN Services"
        }
    }

    var subtitle: String {
        switch self {
        case .localNetwork: return "Bypass VPN for local network traffic"
        case .lanServices: return "Access printers, AirPlay, Chromecast"
        }
    }

    var icon: String {
        switch self {
        case .localNetwork: return "wifi"
        case .lanServices: return "printer.fill"
        }
    }

    var routes: [String] {
        switch self {
        case .localNetwork:
            return [
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "169.254.0.0/16",
            ]
        case .lanServices:
            return [
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "169.254.0.0/16",
                "224.0.0.0/4",
                "239.255.255.250/32",
            ]
        }
    }
}
