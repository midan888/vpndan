import SwiftUI

struct PowerButton: View {
    let status: VPNManager.VPNStatus
    let action: () -> Void

    @State private var ringRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    private let size: CGFloat = 200
    private let ringWidth: CGFloat = 4

    var body: some View {
        Button(action: action) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [statusColor.opacity(0.3), statusColor.opacity(0)],
                            center: .center,
                            startRadius: size * 0.2,
                            endRadius: size * 0.7
                        )
                    )
                    .frame(width: size * 1.4, height: size * 1.4)
                    .scaleEffect(glowScale)

                // Background fill
                Circle()
                    .fill(statusColor.opacity(0.08))
                    .frame(width: size, height: size)

                // Ring
                if status == .connecting || status == .disconnecting {
                    // Rotating gradient ring for connecting state
                    Circle()
                        .stroke(Color.vpnBorder.opacity(0.3), lineWidth: ringWidth)
                        .frame(width: size, height: size)

                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(
                            AngularGradient(
                                colors: [statusColor.opacity(0), statusColor, statusColor.opacity(0)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(ringRotation))
                } else {
                    // Static ring
                    Circle()
                        .stroke(statusColor.opacity(0.6), lineWidth: ringWidth)
                        .frame(width: size, height: size)
                }

                // Inner content
                VStack(spacing: VPNSpacing.sm) {
                    Image(systemName: powerIcon)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(statusColor)

                    Text(buttonLabel)
                        .vpnTextStyle(.caption, color: .vpnTextSecondary)
                }
            }
        }
        .buttonStyle(PowerButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(status == .connected ? "Double tap to disconnect" : "Double tap to connect")
        .disabled(status == .connecting || status == .disconnecting)
        .onChange(of: status) { _, newStatus in
            updateAnimations(for: newStatus)
        }
        .onAppear {
            updateAnimations(for: status)
        }
    }

    // MARK: - Computed Properties

    private var accessibilityLabel: String {
        switch status {
        case .connected: return "VPN connected. Tap to disconnect."
        case .connecting: return "VPN connecting."
        case .disconnected: return "VPN disconnected. Tap to connect."
        case .disconnecting: return "VPN disconnecting."
        }
    }

    private var statusColor: Color {
        status.color
    }

    private var powerIcon: String {
        switch status {
        case .connected: return "power"
        case .connecting: return "ellipsis"
        case .disconnected: return "power"
        case .disconnecting: return "ellipsis"
        }
    }

    private var buttonLabel: String {
        switch status {
        case .connected: return "TAP TO DISCONNECT"
        case .connecting: return "CONNECTING"
        case .disconnected: return "TAP TO CONNECT"
        case .disconnecting: return "DISCONNECTING"
        }
    }

    // MARK: - Animations

    private func updateAnimations(for status: VPNManager.VPNStatus) {
        switch status {
        case .connecting, .disconnecting:
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowScale = 1.15
                pulseOpacity = 1.0
            }

        case .connected:
            withAnimation(.easeInOut(duration: 0.4)) {
                ringRotation = 0
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowScale = 1.08
                pulseOpacity = 0.8
            }

        case .disconnected:
            withAnimation(.easeInOut(duration: 0.4)) {
                ringRotation = 0
                glowScale = 1.0
                pulseOpacity = 0.6
            }
        }
    }
}

// MARK: - Power Button Press Style

struct PowerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: 40) {
            PowerButton(status: .disconnected) {}
        }
    }
}
