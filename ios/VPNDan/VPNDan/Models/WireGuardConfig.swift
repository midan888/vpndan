import Foundation

struct WireGuardConfig: Decodable {
    let interfacePrivateKey: String
    let interfaceAddress: String
    let interfaceDNS: String
    let peerPublicKey: String
    let peerEndpoint: String
    let peerAllowedIPs: String
    // Amnezia WireGuard obfuscation parameters
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
}

struct ConnectRequest: Encodable {
    let serverID: UUID

    enum CodingKeys: String, CodingKey {
        case serverID = "server_id"
    }
}

struct DisconnectResponse: Decodable {
    let message: String
}
