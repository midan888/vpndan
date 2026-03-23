import SwiftUI

struct ServerRow: View {
    let server: Server
    var isConnected: Bool = false
    var isSelected: Bool = false
    var isFavorite: Bool = false
    var onFavoriteToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: VPNSpacing.md) {
            // Flag
            Text(Self.flag(for: server.country))
                .font(.system(size: 32))

            // Name + status
            VStack(alignment: .leading, spacing: VPNSpacing.xs) {
                Text(server.name)
                    .vpnTextStyle(.body, color: server.isActive ? .vpnTextPrimary : .vpnTextTertiary)

                if isConnected {
                    Text("Connected")
                        .vpnTextStyle(.statusBadge, color: .vpnConnected)
                }
            }

            Spacer()

            // Favorite star
            if let onFavoriteToggle {
                Button(action: onFavoriteToggle) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(isFavorite ? Color.vpnConnecting : Color.vpnTextTertiary)
                }
                .buttonStyle(.plain)
            }

            // Connection indicator
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.vpnConnected)
            } else if isSelected {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.vpnPrimary)
            }

            // Active dot
            Circle()
                .fill(server.isActive ? Color.vpnConnected : Color.vpnInactive)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, VPNSpacing.sm)
        .padding(.horizontal, VPNSpacing.md)
        .opacity(server.isActive ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(server.name), \(server.country)\(isConnected ? ", connected" : "")\(isFavorite ? ", favorite" : "")\(server.isActive ? "" : ", unavailable")")
    }

    // MARK: - Flag Helper

    static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: 0) {
            ServerRow(
                server: Server(id: UUID(), name: "New York", country: "US", host: "10.0.0.1", isActive: true),
                isConnected: true,
                isFavorite: true,
                onFavoriteToggle: {}
            )
            ServerRow(
                server: Server(id: UUID(), name: "London", country: "GB", host: "10.0.0.2", isActive: true),
                isSelected: true,
                onFavoriteToggle: {}
            )
            ServerRow(
                server: Server(id: UUID(), name: "Tokyo", country: "JP", host: "10.0.0.3", isActive: false),
                onFavoriteToggle: {}
            )
        }
    }
}
