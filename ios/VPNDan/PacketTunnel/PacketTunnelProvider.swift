import NetworkExtension
import os.log

#if !targetEnvironment(simulator)
import WireGuardKit
#endif

private let log = OSLog(subsystem: "com.vpndan.VPNDan.PacketTunnel", category: "tunnel")

class PacketTunnelProvider: NEPacketTunnelProvider {

    #if !targetEnvironment(simulator)
    private lazy var adapter = WireGuardAdapter(with: self) { _, message in
        NSLog("WireGuard: %@", message)
    }
    #endif

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        // Load WireGuard config from App Group
        guard let defaults = UserDefaults(suiteName: "group.com.vpndan.VPNDan"),
              let data = defaults.data(forKey: "wg_config") else {
            throw PacketTunnelError.missingConfiguration
        }

        let config = try JSONDecoder().decode(WGConfig.self, from: data)

        // Load pre-resolved excluded routes (resolved by main app before tunnel start)
        let excludedRoutes = loadResolvedRoutes(from: defaults)
        if !excludedRoutes.isEmpty {
            os_log(.default, log: log, "split tunneling: excluding %{public}d routes", excludedRoutes.count)
        }

        #if targetEnvironment(simulator)
        // Simulator: just configure network settings without WireGuard
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.peerEndpoint)
        let ipv4 = NEIPv4Settings(
            addresses: [config.interfaceAddress.components(separatedBy: "/").first ?? "10.0.0.2"],
            subnetMasks: ["255.255.255.255"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        if !excludedRoutes.isEmpty {
            ipv4.excludedRoutes = excludedRoutes.compactMap { cidr -> NEIPv4Route? in
                let parts = cidr.split(separator: "/")
                guard parts.count == 2,
                      let prefixLength = Int(parts[1]) else { return nil }
                let address = String(parts[0])
                let mask = subnetMask(fromPrefixLength: prefixLength)
                return NEIPv4Route(destinationAddress: address, subnetMask: mask)
            }
        }
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: [config.interfaceDNS])
        try await setTunnelNetworkSettings(settings)
        #else
        let tunnelConfig = try config.toTunnelConfiguration(excludedRoutes: excludedRoutes)
        os_log(.default, log: log, "endpoint = %{public}s", config.peerEndpoint)
        os_log(.default, log: log, "interface address = %{public}s", config.interfaceAddress)
        os_log(.default, log: log, "allowed IPs = %{public}s", config.peerAllowedIPs)
        os_log(.default, log: log, "AWG params: Jc=%d Jmin=%d Jmax=%d S1=%d S2=%d", config.jc, config.jmin, config.jmax, config.s1, config.s2)
        return try await withCheckedThrowingContinuation { continuation in
            adapter.start(tunnelConfiguration: tunnelConfig) { adapterError in
                if let adapterError {
                    os_log(.error, log: log, "adapter start error: %{public}s", "\(adapterError)")
                    continuation.resume(throwing: adapterError)
                } else {
                    os_log(.default, log: log, "adapter started successfully")
                    continuation.resume()
                }
            }
        }
        #endif
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        #if !targetEnvironment(simulator)
        return await withCheckedContinuation { continuation in
            adapter.stop { _ in
                continuation.resume()
            }
        }
        #endif
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let message = String(data: messageData, encoding: .utf8) else { return nil }

        if message == "getTransferStats" {
            #if !targetEnvironment(simulator)
            return await withCheckedContinuation { continuation in
                adapter.getRuntimeConfiguration { config in
                    guard let config else {
                        continuation.resume(returning: nil)
                        return
                    }
                    // Parse UAPI format for rx_bytes and tx_bytes
                    var rxBytes: UInt64 = 0
                    var txBytes: UInt64 = 0
                    for line in config.split(separator: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("rx_bytes=") {
                            rxBytes += UInt64(trimmed.dropFirst("rx_bytes=".count)) ?? 0
                        } else if trimmed.hasPrefix("tx_bytes=") {
                            txBytes += UInt64(trimmed.dropFirst("tx_bytes=".count)) ?? 0
                        }
                    }
                    let response = "\(rxBytes),\(txBytes)"
                    continuation.resume(returning: response.data(using: .utf8))
                }
            }
            #else
            return nil
            #endif
        }

        return nil
    }

    // MARK: - Split Tunnel Helpers

    /// Reads the pre-resolved CIDR routes written by the main app
    private func loadResolvedRoutes(from defaults: UserDefaults) -> [String] {
        guard let data = defaults.data(forKey: "split_tunnel_resolved_routes"),
              let routes = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return routes
    }

    private func subnetMask(fromPrefixLength prefix: Int) -> String {
        let mask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << (32 - prefix)
        return "\(mask >> 24 & 0xFF).\(mask >> 16 & 0xFF).\(mask >> 8 & 0xFF).\(mask & 0xFF)"
    }
}

// MARK: - Error

enum PacketTunnelError: LocalizedError {
    case missingConfiguration
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "No WireGuard configuration found"
        case .invalidConfiguration(let detail):
            return "Invalid WireGuard configuration: \(detail)"
        }
    }
}

// MARK: - Config

private struct WGConfig: Decodable {
    let interfacePrivateKey: String
    let interfaceAddress: String
    let interfaceDNS: String
    let peerPublicKey: String
    let peerEndpoint: String
    let peerAllowedIPs: String
    let jc: Int
    let jmin: Int
    let jmax: Int
    let s1: Int
    let s2: Int
    let h1: Int64
    let h2: Int64
    let h3: Int64
    let h4: Int64

    enum CodingKeys: String, CodingKey {
        case interfacePrivateKey = "interface_private_key"
        case interfaceAddress = "interface_address"
        case interfaceDNS = "interface_dns"
        case peerPublicKey = "peer_public_key"
        case peerEndpoint = "peer_endpoint"
        case peerAllowedIPs = "peer_allowed_ips"
        case jc, jmin, jmax, s1, s2, h1, h2, h3, h4
    }

    #if !targetEnvironment(simulator)
    func toTunnelConfiguration(excludedRoutes: [String] = []) throws -> TunnelConfiguration {
        guard let privateKey = PrivateKey(base64Key: interfacePrivateKey) else {
            throw PacketTunnelError.invalidConfiguration("invalid client private key")
        }

        guard let serverPublicKey = PublicKey(base64Key: peerPublicKey) else {
            throw PacketTunnelError.invalidConfiguration("invalid server public key")
        }

        guard let endpoint = Endpoint(from: peerEndpoint) else {
            throw PacketTunnelError.invalidConfiguration("invalid server endpoint: \(peerEndpoint)")
        }

        var interface = InterfaceConfiguration(privateKey: privateKey)
        interface.addresses = interfaceAddress
            .split(separator: ",")
            .compactMap { IPAddressRange(from: String($0).trimmingCharacters(in: .whitespaces)) }
        interface.dns = interfaceDNS
            .split(separator: ",")
            .compactMap { DNSServer(from: String($0).trimmingCharacters(in: .whitespaces)) }

        // Amnezia WireGuard obfuscation parameters
        interface.junkPacketCount = UInt16(jc)
        interface.junkPacketMinSize = UInt16(jmin)
        interface.junkPacketMaxSize = UInt16(jmax)
        interface.initPacketJunkSize = UInt16(s1)
        interface.responsePacketJunkSize = UInt16(s2)
        interface.initPacketMagicHeader = String(h1)
        interface.responsePacketMagicHeader = String(h2)
        interface.underloadPacketMagicHeader = String(h3)
        interface.transportPacketMagicHeader = String(h4)

        var peer = PeerConfiguration(publicKey: serverPublicKey)
        peer.endpoint = endpoint
        peer.allowedIPs = peerAllowedIPs
            .split(separator: ",")
            .compactMap { IPAddressRange(from: String($0).trimmingCharacters(in: .whitespaces)) }
        peer.excludeIPs = excludedRoutes
            .compactMap { IPAddressRange(from: $0) }

        return TunnelConfiguration(name: "VPN Dan", interface: interface, peers: [peer])
    }
    #endif
}
