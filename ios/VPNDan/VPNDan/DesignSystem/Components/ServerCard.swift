import SwiftUI

struct ServerCard: View {
    let server: Server?
    let onChangeTapped: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: VPNSpacing.md) {
                if let server {
                    Text(flag(for: server.country))
                        .font(.system(size: 36))

                    VStack(alignment: .leading, spacing: VPNSpacing.xs) {
                        Text(server.name)
                            .vpnTextStyle(.sectionHeader)
                        Text(server.country.uppercased())
                            .vpnTextStyle(.caption, color: .vpnTextSecondary)
                    }
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.vpnTextTertiary)

                    VStack(alignment: .leading, spacing: VPNSpacing.xs) {
                        Text("No Server Selected")
                            .vpnTextStyle(.sectionHeader)
                        Text("Tap to choose a server")
                            .vpnTextStyle(.caption, color: .vpnTextSecondary)
                    }
                }

                Spacer()

                Button(action: onChangeTapped) {
                    Text("Change")
                        .vpnTextStyle(.caption, color: .vpnPrimary)
                        .padding(.horizontal, VPNSpacing.sm + VPNSpacing.xs)
                        .padding(.vertical, VPNSpacing.xs + 2)
                        .background(
                            Capsule()
                                .fill(Color.vpnPrimary.opacity(0.15))
                        )
                }
            }
        }
    }

    private func flag(for countryCode: String) -> String {
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

        VStack(spacing: VPNSpacing.md) {
            ServerCard(
                server: Server(id: UUID(), name: "New York", country: "US", host: "10.0.0.1", isActive: true),
                onChangeTapped: {}
            )
            ServerCard(server: nil, onChangeTapped: {})
        }
        .padding()
    }
}
