import Foundation
import NetworkExtension

@MainActor
@Observable
final class VPNManager {
    static let shared = VPNManager()

    private(set) var status: VPNStatus = .disconnected
    private(set) var connectedServer: Server?

    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    static let appGroupID = "group.com.vpngod.VPNGod"

    enum VPNStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }

    private init() {
        observeVPNStatus()
    }

    // MARK: - Connection

    func connect(server: Server) async throws {
        // If already connected, stop the tunnel first so API calls don't route through it
        if tunnelManager?.connection.status == .connected ||
           tunnelManager?.connection.status == .connecting {
            tunnelManager?.connection.stopVPNTunnel()
            // Give the OS a moment to tear down the tunnel route
            try await Task.sleep(for: .milliseconds(500))
        }

        status = .connecting
        connectedServer = server

        do {
            // Get WireGuard config from backend
            let config: WireGuardConfig
            do {
                config = try await APIClient.shared.connect(serverID: server.id)
            } catch let error as APIError {
                throw mapConnectError(error)
            }

            // Save config to App Group for the tunnel extension
            saveConfigToAppGroup(config)

            // Configure and start the tunnel
            let manager = try await loadOrCreateTunnelManager()

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.vpngod.VPNGod.PacketTunnel"
            proto.serverAddress = server.host

            manager.protocolConfiguration = proto
            manager.localizedDescription = "VPN God"
            manager.isEnabled = true

            do {
                try await manager.saveToPreferences()
            } catch {
                // saveToPreferences fails if user taps "Don't Allow" on the VPN permission prompt
                throw APIError.vpnPermissionRequired
            }

            try await manager.loadFromPreferences()

            do {
                try manager.connection.startVPNTunnel()
            } catch NEVPNError.configurationDisabled {
                throw APIError.vpnPermissionRequired
            } catch {
                throw APIError.vpnConnectionFailed
            }

            tunnelManager = manager
        } catch {
            status = .disconnected
            connectedServer = nil
            throw error
        }
    }

    func disconnect() async throws {
        status = .disconnecting

        tunnelManager?.connection.stopVPNTunnel()
        // Wait for tunnel teardown so the disconnect API call goes over the physical interface
        try? await Task.sleep(for: .milliseconds(500))

        do {
            _ = try await APIClient.shared.disconnect()
        } catch {
            // Tunnel is already stopped locally — don't block the UI.
            // Backend peer will be cleaned up on next connect or by TTL.
        }

        connectedServer = nil
        status = .disconnected
    }

    // MARK: - Status Sync

    func syncStatus() async {
        guard let manager = try? await loadOrCreateTunnelManager() else {
            status = .disconnected
            return
        }

        tunnelManager = manager

        switch manager.connection.status {
        case .connected:
            status = .connected
        case .connecting, .reasserting:
            status = .connecting
        case .disconnecting:
            status = .disconnecting
        default:
            status = .disconnected
            connectedServer = nil
        }
    }

    // MARK: - Private

    private func loadOrCreateTunnelManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first {
            return existing
        }
        return NETunnelProviderManager()
    }

    private func saveConfigToAppGroup(_ config: WireGuardConfig) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        let data = try? JSONEncoder().encode(config)
        defaults.set(data, forKey: "wg_config")
    }

    private func mapConnectError(_ error: APIError) -> APIError {
        switch error {
        case .badRequest(let msg) where msg.lowercased().contains("not available"):
            return .serverUnavailable
        case .notFound:
            return .serverUnavailable
        case .conflict:
            return error // "already connected, disconnect first"
        default:
            if case .serverError = error {
                return .serverAtCapacity
            }
            return error
        }
    }

    private func observeVPNStatus() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }

            Task { @MainActor in
                guard let self else { return }
                switch connection.status {
                case .connected:
                    self.status = .connected
                case .connecting, .reasserting:
                    self.status = .connecting
                case .disconnecting:
                    self.status = .disconnecting
                case .disconnected, .invalid:
                    self.status = .disconnected
                    self.connectedServer = nil
                @unknown default:
                    break
                }
            }
        }
    }
}

// Make WireGuardConfig Encodable for App Group storage
extension WireGuardConfig: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(interfacePrivateKey, forKey: .interfacePrivateKey)
        try container.encode(interfaceAddress, forKey: .interfaceAddress)
        try container.encode(interfaceDNS, forKey: .interfaceDNS)
        try container.encode(peerPublicKey, forKey: .peerPublicKey)
        try container.encode(peerEndpoint, forKey: .peerEndpoint)
        try container.encode(peerAllowedIPs, forKey: .peerAllowedIPs)
    }
}
