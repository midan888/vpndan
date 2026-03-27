import Foundation
import SwiftUI

@MainActor
@Observable
final class LatencyService {
    static let shared = LatencyService()

    /// Server ID → latency in milliseconds (nil = not yet measured)
    private(set) var latencies: [UUID: Int] = [:]

    /// When true, bulk pings are paused (only connected server is pinged).
    var vpnConnected = false {
        didSet {
            if vpnConnected {
                stopPeriodicRefresh()
            } else {
                stopConnectedPing()
                if let cachedServers = _servers {
                    startPeriodicRefresh(servers: cachedServers)
                }
            }
        }
    }

    /// The server currently being pinged while VPN is connected.
    private(set) var connectedServerID: UUID?

    private var measureTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var connectedPingTimer: Timer?
    private var _servers: [Server]?

    private static let pingSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private init() {}

    /// Measure latency for all given servers concurrently.
    func measureAll(_ servers: [Server]) {
        measureTask?.cancel()
        let targets = servers.filter { $0.isActive }.map { (id: $0.id, host: $0.host, pingPort: $0.pingPort) }
        measureTask = Task {
            let results = await Self.measureAllHosts(targets)
            for (id, ms) in results {
                if Task.isCancelled { return }
                latencies[id] = ms
            }
        }
    }

    /// Runs all HTTP pings concurrently off the main actor.
    private nonisolated static func measureAllHosts(_ targets: [(id: UUID, host: String, pingPort: Int)]) async -> [(UUID, Int)] {
        await withTaskGroup(of: (UUID, Int?).self, returning: [(UUID, Int)].self) { group in
            for target in targets {
                group.addTask {
                    let ms = await Self.httpPing(host: target.host, port: target.pingPort)
                    return (target.id, ms)
                }
            }
            var results: [(UUID, Int)] = []
            for await (id, ms) in group {
                if let ms { results.append((id, ms)) }
            }
            return results
        }
    }

    /// Start periodic refresh (every 5s).
    func startPeriodicRefresh(servers: [Server]) {
        _servers = servers
        stopPeriodicRefresh()
        guard !vpnConnected else { return }
        measureAll(servers)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.measureAll(servers)
            }
        }
    }

    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        measureTask?.cancel()
    }

    /// Measure latency for a single server by ID.
    func measure(server: Server) {
        Task {
            if let ms = await Self.httpPing(host: server.host, port: server.pingPort) {
                latencies[server.id] = ms
            }
        }
    }

    /// Start pinging only the connected server (every 5s) while VPN is active.
    func startConnectedPing(server: Server) {
        stopConnectedPing()
        connectedServerID = server.id
        measure(server: server)
        connectedPingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.measure(server: server)
            }
        }
    }

    func stopConnectedPing() {
        connectedPingTimer?.invalidate()
        connectedPingTimer = nil
        connectedServerID = nil
    }

    // MARK: - HTTP Ping

    /// Measures round-trip time of an HTTP GET to the server's /ping endpoint.
    /// Returns milliseconds or nil on failure.
    private nonisolated static func httpPing(host: String, port: Int) async -> Int? {
        guard let url = URL(string: "http://\(host):\(port)/ping") else { return nil }
        let start = ContinuousClock.now
        do {
            let (_, response) = try await pingSession.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let elapsed = ContinuousClock.now - start
            let components = elapsed.components
            return Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000) // → ms
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    func latency(for serverID: UUID) -> Int? {
        guard !vpnConnected else { return nil }
        return latencies[serverID]
    }

    func latencyText(for serverID: UUID) -> String? {
        guard !vpnConnected, let ms = latencies[serverID] else { return nil }
        return "\(ms) ms"
    }

    func latencyQuality(for serverID: UUID) -> LatencyQuality? {
        guard !vpnConnected, let ms = latencies[serverID] else { return nil }
        return LatencyQuality(ms: ms)
    }

    /// Returns the connected server's latency (available even while VPN is active).
    func connectedLatency() -> Int? {
        guard let id = connectedServerID else { return nil }
        return latencies[id]
    }
}

enum LatencyQuality {
    case excellent // < 50ms
    case good      // 50-100ms
    case fair      // 100-200ms
    case poor      // > 200ms

    init(ms: Int) {
        switch ms {
        case ..<50: self = .excellent
        case 50..<100: self = .good
        case 100..<200: self = .fair
        default: self = .poor
        }
    }

    var label: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .fair: "Fair"
        case .poor: "Poor"
        }
    }

    var color: Color {
        switch self {
        case .excellent, .good: .vpnConnected
        case .fair: .vpnConnecting
        case .poor: .vpnDisconnected
        }
    }

    var icon: String {
        switch self {
        case .excellent: "checkmark.shield.fill"
        case .good: "checkmark.circle.fill"
        case .fair: "exclamationmark.circle.fill"
        case .poor: "xmark.circle.fill"
        }
    }
}
