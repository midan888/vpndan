import SwiftUI

struct QuickStatsRow: View {
    let isConnected: Bool
    let connectedDate: Date?
    let bytesReceived: UInt64
    let bytesSent: UInt64

    var body: some View {
        GlassCard(padding: VPNSpacing.sm + VPNSpacing.xs) {
            HStack(spacing: 0) {
                statItem(
                    icon: "arrow.down",
                    value: isConnected ? formatBytes(bytesReceived) : "--",
                    label: "Download"
                )

                divider

                statItem(
                    icon: "arrow.up",
                    value: isConnected ? formatBytes(bytesSent) : "--",
                    label: "Upload"
                )

                divider

                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    statItem(
                        icon: "clock",
                        value: isConnected ? uptimeString(at: context.date) : "--:--",
                        label: "Duration"
                    )
                }
            }
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: VPNSpacing.xs) {
            HStack(spacing: VPNSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.vpnTextTertiary)

                Text(value)
                    .vpnTextStyle(.sectionHeader)
            }

            Text(label)
                .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vpnBorder.opacity(0.5))
            .frame(width: 1, height: 32)
    }

    private func uptimeString(at now: Date) -> String {
        guard let connectedDate else { return "--:--" }
        let interval = now.timeIntervalSince(connectedDate)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: VPNSpacing.md) {
            QuickStatsRow(isConnected: true, connectedDate: Date().addingTimeInterval(-3672), bytesReceived: 15_400_000, bytesSent: 2_300_000)
            QuickStatsRow(isConnected: false, connectedDate: nil, bytesReceived: 0, bytesSent: 0)
        }
        .padding()
    }
}
