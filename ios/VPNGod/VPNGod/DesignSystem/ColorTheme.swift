import SwiftUI

struct ColorTheme: Equatable, Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let isDark: Bool

    // Backgrounds
    let background: Color
    let surface: Color
    let surfaceLight: Color
    let border: Color

    // Accent
    let primary: Color
    let primaryLight: Color
    let gradientStart: Color
    let gradientEnd: Color

    // Status
    let connected: Color
    let connecting: Color
    let disconnected: Color
    let inactive: Color

    // Text
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Computed
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var primaryGradientColors: [Color] {
        [gradientStart, gradientEnd]
    }
}

// MARK: - Built-in Themes

extension ColorTheme {
    static let allThemes: [ColorTheme] = [.default, .hermes]

    static let `default` = ColorTheme(
        id: "default",
        displayName: "Midnight",
        icon: "moon.stars.fill",
        isDark: true,
        background: Color(hex: 0x0A0E1A),
        surface: Color(hex: 0x141929),
        surfaceLight: Color(hex: 0x1E2438),
        border: Color(hex: 0x2A3050),
        primary: Color(hex: 0x7B5EFF),
        primaryLight: Color(hex: 0xA78BFA),
        gradientStart: Color(hex: 0x7B5EFF),
        gradientEnd: Color(hex: 0x00D4AA),
        connected: Color(hex: 0x00D4AA),
        connecting: Color(hex: 0xFFB800),
        disconnected: Color(hex: 0xFF4757),
        inactive: Color(hex: 0x4A5068),
        textPrimary: .white,
        textSecondary: Color(hex: 0x8B92A8),
        textTertiary: Color(hex: 0x5A6180)
    )

    static let hermes = ColorTheme(
        id: "hermes",
        displayName: "Hermes",
        icon: "flame.fill",
        isDark: false,
        background: Color(hex: 0xFAF6F1),       // warm cream
        surface: Color(hex: 0xFFFFFF),           // white cards
        surfaceLight: Color(hex: 0xF0EAE2),      // light beige
        border: Color(hex: 0xE0D5C7),            // soft tan border
        primary: Color(hex: 0xD4621A),            // Hermès orange
        primaryLight: Color(hex: 0xE8843F),       // lighter orange
        gradientStart: Color(hex: 0xD4621A),      // orange
        gradientEnd: Color(hex: 0xC49A6C),        // warm gold/tan
        connected: Color(hex: 0x6B8E5E),          // muted olive green
        connecting: Color(hex: 0xD4961A),          // amber
        disconnected: Color(hex: 0xC44B3F),       // muted terracotta red
        inactive: Color(hex: 0xC4BAB0),           // warm grey
        textPrimary: Color(hex: 0x2C1810),        // deep espresso brown
        textSecondary: Color(hex: 0x7A6455),      // warm brown
        textTertiary: Color(hex: 0xA89888)         // light brown
    )
}
