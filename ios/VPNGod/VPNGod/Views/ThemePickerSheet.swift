import SwiftUI

struct ThemePickerSheet: View {
    @Environment(ThemeService.self) private var themeService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vpnBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VPNSpacing.md) {
                        ForEach(ColorTheme.allThemes) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: themeService.current.id == theme.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    themeService.setTheme(theme)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.top, VPNSpacing.md)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.vpnPrimary)
                }
            }
            .toolbarBackground(Color.vpnSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Preview strip
                themePreview
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: VPNRadius.card))
                    .padding(VPNSpacing.sm)

                // Label row
                HStack(spacing: VPNSpacing.sm) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.primary)

                    Text(theme.displayName)
                        .vpnTextStyle(.body)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.vpnPrimary)
                    }
                }
                .padding(.horizontal, VPNSpacing.md)
                .padding(.bottom, VPNSpacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .stroke(
                        isSelected ? Color.vpnPrimary : Color.vpnBorder.opacity(0.5),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var themePreview: some View {
        ZStack {
            // Background
            theme.background

            // Simulated UI preview
            VStack(spacing: VPNSpacing.sm) {
                // Fake power button
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.connected.opacity(0.3), theme.background],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(theme.connected.opacity(0.6), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "power")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(theme.connected)
                    )

                // Fake gradient button
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [theme.gradientStart, theme.gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 100, height: 24)
            }
        }
    }
}

#Preview {
    ThemePickerSheet()
        .environment(ThemeService.shared)
}
