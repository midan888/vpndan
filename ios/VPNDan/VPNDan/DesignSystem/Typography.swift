import SwiftUI

// MARK: - Text Style Modifiers

struct VPNTextStyle: ViewModifier {
    enum Style {
        case heroStat
        case screenTitle
        case sectionHeader
        case body
        case caption
        case statusBadge
        case buttonText
    }

    let style: Style
    var color: Color = .vpnTextPrimary

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }

    private var font: Font {
        switch style {
        case .heroStat:
            return .system(size: 34, weight: .bold, design: .default)
        case .screenTitle:
            return .system(size: 28, weight: .bold, design: .default)
        case .sectionHeader:
            return .system(size: 17, weight: .semibold, design: .default)
        case .body:
            return .system(size: 15, weight: .regular, design: .default)
        case .caption:
            return .system(size: 13, weight: .medium, design: .default)
        case .statusBadge:
            return .system(size: 12, weight: .semibold, design: .default)
        case .buttonText:
            return .system(size: 17, weight: .semibold, design: .default)
        }
    }
}

extension View {
    func vpnTextStyle(_ style: VPNTextStyle.Style, color: Color = .vpnTextPrimary) -> some View {
        modifier(VPNTextStyle(style: style, color: color))
    }
}
