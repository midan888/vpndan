import SwiftUI

struct LatencyGauge: View {
    let latencyMs: Int?
    @State private var showTechnical = false

    private var quality: LatencyQuality {
        guard let ms = latencyMs else { return .poor }
        return LatencyQuality(ms: ms)
    }

    var body: some View {
        GlassCard(padding: VPNSpacing.sm) {
            HStack(spacing: VPNSpacing.md) {
                SignalBars(quality: latencyMs != nil ? quality : nil)
                    .frame(width: 36, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    if showTechnical {
                        if let ms = latencyMs {
                            Text("\(ms) ms")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(quality.color)
                        } else {
                            Text("-- ms")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.vpnTextTertiary)
                        }
                    } else {
                        Text(quality.label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(quality.color)
                    }
                    Text("Connection Quality")
                        .vpnTextStyle(.caption, color: .vpnTextTertiary)
                }
                .contentTransition(.numericText())

                Spacer()

                Image(systemName: latencyMs != nil ? quality.icon : "wifi.slash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(latencyMs != nil ? quality.color : Color.vpnTextTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showTechnical.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: VPNSpacing.md) {
            LatencyGauge(latencyMs: 32)
            LatencyGauge(latencyMs: 85)
            LatencyGauge(latencyMs: 155)
            LatencyGauge(latencyMs: 280)
            LatencyGauge(latencyMs: nil)
        }
        .padding()
    }
}
