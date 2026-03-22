import Foundation

@MainActor
@Observable
final class SplitTunnelService {
    static let shared = SplitTunnelService()

    private(set) var config: SplitTunnelConfig

    private let key = "split_tunnel_config"
    private let resolvedKey = "split_tunnel_resolved_routes"
    private let defaults: UserDefaults

    private init() {
        let defaults = UserDefaults(suiteName: VPNManager.appGroupID) ?? .standard
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let config = try? JSONDecoder().decode(SplitTunnelConfig.self, from: data) {
            self.config = config
        } else {
            self.config = SplitTunnelConfig()
        }
    }

    func setEnabled(_ enabled: Bool) {
        config.isEnabled = enabled
        save()
    }

    func togglePreset(_ preset: SplitTunnelPreset) {
        if config.enabledPresets.contains(preset) {
            config.enabledPresets.remove(preset)
        } else {
            config.enabledPresets.insert(preset)
        }
        save()
    }

    func isPresetEnabled(_ preset: SplitTunnelPreset) -> Bool {
        config.enabledPresets.contains(preset)
    }

    func addEntry(_ entry: ExcludedEntry) {
        guard !config.excludedEntries.contains(where: { $0.value == entry.value }) else { return }
        config.excludedEntries.append(entry)
        save()
    }

    func removeEntry(_ entry: ExcludedEntry) {
        config.excludedEntries.removeAll { $0.id == entry.id }
        save()
    }

    func removeEntry(at offsets: IndexSet) {
        config.excludedEntries.remove(atOffsets: offsets)
        save()
    }

    /// Resolves all domain entries to IPs and writes the final CIDR list
    /// to App Group for the PacketTunnel extension. Call before connecting.
    func resolveAndWriteRoutes() async {
        guard config.isEnabled else {
            defaults.removeObject(forKey: resolvedKey)
            return
        }

        var routes: [String] = []

        // Preset routes
        for preset in config.enabledPresets {
            routes.append(contentsOf: preset.routes)
        }

        // Entries
        for entry in config.excludedEntries {
            switch entry.type {
            case .ip:
                routes.append(entry.value)
            case .domain:
                let ips = await Self.resolveDomain(entry.value)
                    .filter { !$0.isEmpty }
                routes.append(contentsOf: ips.map { "\($0)/32" })
            }
        }

        // Write resolved routes for the extension to read
        if let data = try? JSONEncoder().encode(routes) {
            defaults.set(data, forKey: resolvedKey)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - DNS Resolution

    private static func resolveDomain(_ domain: String) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM

                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(domain, nil, &hints, &result)

                guard status == 0, let addrList = result else {
                    continuation.resume(returning: [])
                    return
                }

                defer { freeaddrinfo(addrList) }

                var ips: [String] = []
                var current: UnsafeMutablePointer<addrinfo>? = addrList
                while let info = current {
                    if let addr = info.pointee.ai_addr {
                        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let niStatus = getnameinfo(
                            addr,
                            socklen_t(info.pointee.ai_addrlen),
                            &hostBuffer,
                            socklen_t(hostBuffer.count),
                            nil, 0,
                            NI_NUMERICHOST
                        )
                        if niStatus == 0 {
                            let ipStr = String(cString: hostBuffer)
                            if !ipStr.isEmpty && !ips.contains(ipStr) {
                                ips.append(ipStr)
                            }
                        }
                    }
                    current = info.pointee.ai_next
                }

                continuation.resume(returning: ips)
            }
        }
    }
}
