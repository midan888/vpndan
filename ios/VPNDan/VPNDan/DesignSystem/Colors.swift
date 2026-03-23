import SwiftUI

extension Color {
    // MARK: - Theme-aware colors

    private static var theme: ColorTheme {
        ThemeService.shared.current
    }

    // MARK: - Backgrounds
    static var vpnBackground: Color { theme.background }
    static var vpnSurface: Color { theme.surface }
    static var vpnSurfaceLight: Color { theme.surfaceLight }
    static var vpnBorder: Color { theme.border }

    // MARK: - Accent
    static var vpnPrimary: Color { theme.primary }
    static var vpnPrimaryLight: Color { theme.primaryLight }
    static var vpnGradientStart: Color { theme.gradientStart }
    static var vpnGradientEnd: Color { theme.gradientEnd }

    // MARK: - Status
    static var vpnConnected: Color { theme.connected }
    static var vpnConnecting: Color { theme.connecting }
    static var vpnDisconnected: Color { theme.disconnected }
    static var vpnInactive: Color { theme.inactive }

    // MARK: - Text
    static var vpnTextPrimary: Color { theme.textPrimary }
    static var vpnTextSecondary: Color { theme.textSecondary }
    static var vpnTextTertiary: Color { theme.textTertiary }

    // MARK: - Gradients
    static var vpnPrimaryGradient: LinearGradient { theme.primaryGradient }
    static var vpnPrimaryGradientColors: [Color] { theme.primaryGradientColors }

    // MARK: - Hex Init
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - VPN Status Color Mapping

extension VPNManager.VPNStatus {
    var color: Color {
        switch self {
        case .connected: return .vpnConnected
        case .connecting: return .vpnConnecting
        case .disconnected: return .vpnDisconnected
        case .disconnecting: return .vpnConnecting
        }
    }
}
