import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = VPNSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .stroke(Color.vpnBorder.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Convenience modifier for existing views

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = VPNSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .stroke(Color.vpnBorder.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(padding: CGFloat = VPNSpacing.md) -> some View {
        modifier(GlassCardModifier(padding: padding))
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack(spacing: VPNSpacing.md) {
            GlassCard {
                HStack {
                    Text("🇺🇸")
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("United States")
                            .vpnTextStyle(.sectionHeader)
                        Text("New York • 24ms")
                            .vpnTextStyle(.caption, color: .vpnTextSecondary)
                    }
                    Spacer()
                }
            }

            Text("Using the modifier")
                .vpnTextStyle(.body)
                .frame(maxWidth: .infinity)
                .glassCard()
        }
        .padding()
    }
}
