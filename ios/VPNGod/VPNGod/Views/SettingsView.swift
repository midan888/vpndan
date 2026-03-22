import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(VPNManager.self) private var vpn
    @Environment(ThemeService.self) private var themeService
    @Environment(SplitTunnelService.self) private var splitTunnel
    @State private var showLogoutConfirmation = false
    @State private var showThemePicker = false
    @State private var showSplitTunnel = false

    var body: some View {
        ZStack {
            Color.vpnBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: VPNSpacing.lg) {
                    // Account
                    accountSection

                    // Connection
                    connectionSection

                    // Appearance
                    appearanceSection

                    // Support
                    supportSection

                    // Sign Out
                    signOutButton

                    // Version
                    Text("VPN God v\(appVersion)")
                        .vpnTextStyle(.caption, color: .vpnTextTertiary)
                        .padding(.top, VPNSpacing.sm)
                }
                .padding(.horizontal, VPNSpacing.md)
                .padding(.top, VPNSpacing.md)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("Sign Out", isPresented: $showLogoutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task {
                    if vpn.status == .connected {
                        try? await vpn.disconnect()
                    }
                    auth.logout()
                }
            }
        } message: {
            if vpn.status == .connected {
                Text("You are currently connected. Signing out will disconnect you.")
            } else {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        settingsSection(title: "Account", icon: "person.fill") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "envelope.fill",
                    title: "Email",
                    value: auth.userEmail ?? "Not available"
                )

                sectionDivider

                settingsRow(
                    icon: "crown.fill",
                    title: "Plan",
                    value: "Free",
                    trailing: {
                        AnyView(comingSoonBadge)
                    }
                )
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        settingsSection(title: "Connection", icon: "network") {
            VStack(spacing: 0) {
                settingsDisabledToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Auto-Connect",
                    subtitle: "Connect on app launch"
                )

                sectionDivider

                settingsDisabledToggleRow(
                    icon: "xmark.shield.fill",
                    title: "Kill Switch",
                    subtitle: "Block traffic if VPN drops"
                )

                sectionDivider

                Button {
                    showSplitTunnel = true
                } label: {
                    settingsRow(
                        icon: "arrow.triangle.branch",
                        title: "Bypass VPN",
                        value: splitTunnel.config.isEnabled ? "On" : "Off",
                        trailing: {
                            AnyView(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.vpnTextTertiary)
                            )
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showSplitTunnel) {
            SplitTunnelSettingsView()
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        settingsSection(title: "Appearance", icon: "paintbrush.fill") {
            Button {
                showThemePicker = true
            } label: {
                settingsRow(
                    icon: themeService.current.icon,
                    title: "Theme",
                    value: themeService.current.displayName,
                    trailing: {
                        AnyView(
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.vpnTextTertiary)
                        )
                    }
                )
            }
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet()
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        settingsSection(title: "Support", icon: "questionmark.circle.fill") {
            VStack(spacing: 0) {
                settingsDisabledLinkRow(icon: "book.fill", title: "Help Center")

                sectionDivider

                settingsDisabledLinkRow(icon: "hand.raised.fill", title: "Privacy Policy")

                sectionDivider

                settingsDisabledLinkRow(icon: "doc.text.fill", title: "Terms of Service")
            }
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14))
                Text("Sign Out")
                    .vpnTextStyle(.buttonText)
            }
            .foregroundStyle(Color.vpnDisconnected)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.button)
                    .fill(Color.vpnDisconnected.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VPNRadius.button)
                    .stroke(Color.vpnDisconnected.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: VPNSpacing.sm) {
            HStack(spacing: VPNSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.vpnTextTertiary)

                Text(title.uppercased())
                    .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
            }
            .padding(.horizontal, VPNSpacing.xs)

            content()
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

    // MARK: - Row Builders

    private func settingsRow(
        icon: String,
        title: String,
        value: String,
        trailing: (() -> AnyView)? = nil
    ) -> some View {
        HStack(spacing: VPNSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.vpnPrimary)
                .frame(width: 20)

            Text(title)
                .vpnTextStyle(.body)

            Spacer()

            if let trailing {
                trailing()
            } else {
                Text(value)
                    .vpnTextStyle(.body, color: .vpnTextSecondary)
            }
        }
        .padding(.horizontal, VPNSpacing.md)
        .padding(.vertical, VPNSpacing.md)
    }

    private func settingsToggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: VPNSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.vpnPrimary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .vpnTextStyle(.body)
                Text(subtitle)
                    .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(Color.vpnPrimary)
                .labelsHidden()
        }
        .padding(.horizontal, VPNSpacing.md)
        .padding(.vertical, VPNSpacing.sm + VPNSpacing.xs)
    }

    private var comingSoonBadge: some View {
        Text("Coming soon")
            .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
            .padding(.horizontal, VPNSpacing.sm + VPNSpacing.xs)
            .padding(.vertical, VPNSpacing.xs + 2)
            .background(
                Capsule()
                    .fill(Color.vpnTextTertiary.opacity(0.15))
            )
    }

    private func settingsDisabledToggleRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: VPNSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.vpnPrimary.opacity(0.4))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .vpnTextStyle(.body, color: .vpnTextSecondary)
                Text(subtitle)
                    .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
            }

            Spacer()

            comingSoonBadge
        }
        .padding(.horizontal, VPNSpacing.md)
        .padding(.vertical, VPNSpacing.sm + VPNSpacing.xs)
    }

    private func settingsDisabledLinkRow(icon: String, title: String) -> some View {
        HStack(spacing: VPNSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.vpnPrimary.opacity(0.4))
                .frame(width: 20)

            Text(title)
                .vpnTextStyle(.body, color: .vpnTextSecondary)

            Spacer()

            comingSoonBadge
        }
        .padding(.horizontal, VPNSpacing.md)
        .padding(.vertical, VPNSpacing.md)
    }

    private func settingsLinkRow(icon: String, title: String) -> some View {
        HStack(spacing: VPNSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.vpnPrimary)
                .frame(width: 20)

            Text(title)
                .vpnTextStyle(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.vpnTextTertiary)
        }
        .padding(.horizontal, VPNSpacing.md)
        .padding(.vertical, VPNSpacing.md)
    }

    private var sectionDivider: some View {
        Divider()
            .background(Color.vpnBorder.opacity(0.5))
            .padding(.leading, 52)
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

#Preview {
    SettingsView()
        .environment(AuthService.shared)
        .environment(VPNManager.shared)
        .environment(ThemeService.shared)
        .environment(SplitTunnelService.shared)
}
