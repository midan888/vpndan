import Foundation
import NetworkExtension

@MainActor
@Observable
final class VPNManager {
    static let shared = VPNManager()

    private(set) var status: VPNStatus = .disconnected
    private(set) var connectedServer: Server?
    private(set) var bytesReceived: UInt64 = 0
    private(set) var bytesSent: UInt64 = 0
    private(set) var connectedDate: Date?
    private(set) var publicIP: String?

    private var statsTimer: Timer?

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
        print("[VPNManager] connect() called — server=\(server.name) id=\(server.id) host=\(server.host)")

        // If already connected, stop the tunnel first so API calls don't route through it
        if tunnelManager?.connection.status == .connected ||
           tunnelManager?.connection.status == .connecting {
            print("[VPNManager] existing tunnel active — stopping before reconnect")
            tunnelManager?.connection.stopVPNTunnel()
            // Give the OS a moment to tear down the tunnel route
            try await Task.sleep(for: .milliseconds(500))
        }

        status = .connecting
        connectedServer = server

        do {
            // Get WireGuard config from backend
            print("[VPNManager] requesting WireGuard config from API for serverID=\(server.id)")
            let config: WireGuardConfig
            do {
                config = try await APIClient.shared.connect(serverID: server.id)
            } catch let error as APIError {
                print("[VPNManager] API connect failed: \(error)")
                throw mapConnectError(error)
            }
            print("[VPNManager] received config — endpoint=\(config.peerEndpoint) clientIP=\(config.interfaceAddress)")

            // Save config to App Group for the tunnel extension
            saveConfigToAppGroup(config)
            print("[VPNManager] config saved to App Group")

            // Configure and start the tunnel
            let manager = try await loadOrCreateTunnelManager()

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.vpngod.VPNGod.PacketTunnel"
            proto.serverAddress = server.host

            manager.protocolConfiguration = proto
            manager.localizedDescription = "VPN God"
            manager.isEnabled = true

            print("[VPNManager] saving tunnel preferences")
            do {
                try await manager.saveToPreferences()
            } catch {
                print("[VPNManager] saveToPreferences failed (permission denied?): \(error)")
                // saveToPreferences fails if user taps "Don't Allow" on the VPN permission prompt
                throw APIError.vpnPermissionRequired
            }

            try await manager.loadFromPreferences()
            print("[VPNManager] preferences loaded — starting tunnel")

            do {
                try manager.connection.startVPNTunnel()
                print("[VPNManager] startVPNTunnel() called successfully")
            } catch NEVPNError.configurationDisabled {
                print("[VPNManager] startVPNTunnel failed: configurationDisabled")
                throw APIError.vpnPermissionRequired
            } catch {
                print("[VPNManager] startVPNTunnel failed: \(error)")
                throw APIError.vpnConnectionFailed
            }

            tunnelManager = manager
        } catch {
            print("[VPNManager] connect() failed — resetting to disconnected: \(error)")
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

    // MARK: - Transfer Stats

    private func startStatsPolling() {
        stopStatsPolling()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollTransferStats()
            }
        }
    }

    private func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
        bytesReceived = 0
        bytesSent = 0
    }

    private func pollTransferStats() async {
        guard let session = tunnelManager?.connection as? NETunnelProviderSession else { return }
        let message = "getTransferStats".data(using: .utf8)!
        do {
            let response: Data? = try await withCheckedThrowingContinuation { continuation in
                do {
                    try session.sendProviderMessage(message) { response in
                        continuation.resume(returning: response)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            guard let response,
                  let str = String(data: response, encoding: .utf8) else { return }
            let parts = str.split(separator: ",")
            guard parts.count == 2,
                  let rx = UInt64(parts[0]),
                  let tx = UInt64(parts[1]) else { return }
            bytesReceived = rx
            bytesSent = tx
        } catch {
            // Extension may not be ready yet
        }
    }

    // MARK: - Public IP

    func fetchPublicIPOnLaunch() async {
        await fetchPublicIP()
    }

    private func fetchPublicIP() async {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.publicIP = ip
        } catch {
            self.publicIP = nil
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
                    self.connectedDate = self.connectedDate ?? Date()
                    self.startStatsPolling()
                    Task { await self.fetchPublicIP() }
                case .connecting, .reasserting:
                    self.status = .connecting
                case .disconnecting:
                    self.status = .disconnecting
                case .disconnected, .invalid:
                    self.status = .disconnected
                    self.connectedServer = nil
                    self.connectedDate = nil
                    self.stopStatsPolling()
                    Task { await self.fetchPublicIP() }
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
        try container.encode(jc, forKey: .jc)
        try container.encode(jmin, forKey: .jmin)
        try container.encode(jmax, forKey: .jmax)
        try container.encode(s1, forKey: .s1)
        try container.encode(s2, forKey: .s2)
        try container.encode(h1, forKey: .h1)
        try container.encode(h2, forKey: .h2)
        try container.encode(h3, forKey: .h3)
        try container.encode(h4, forKey: .h4)
    }
}
