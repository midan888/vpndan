import SwiftUI

struct IPAddressCard: View {
    let ip: String?
    let location: String?

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: VPNSpacing.xs) {
                    Text("Your IP")
                        .vpnTextStyle(.caption, color: .vpnTextTertiary)

                    Text(ip ?? "Not connected")
                        .vpnTextStyle(.sectionHeader, color: ip != nil ? .vpnTextPrimary : .vpnTextTertiary)

                    if let location {
                        Text(location)
                            .vpnTextStyle(.caption, color: .vpnTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: ip != nil ? "lock.shield.fill" : "lock.shield")
                    .font(.system(size: 24))
                    .foregroundStyle(ip != nil ? Color.vpnConnected : Color.vpnTextTertiary)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ip != nil ? "Your IP address is \(ip!), location \(location ?? "unknown")" : "Not connected, IP address hidden")
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: VPNSpacing.md) {
            IPAddressCard(ip: "185.243.112.47", location: "New York, US")
            IPAddressCard(ip: nil, location: nil)
        }
        .padding()
    }
}
