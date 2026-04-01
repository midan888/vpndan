import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(VPNManager.self) private var vpn
    @Environment(ThemeService.self) private var themeService
    @Environment(SplitTunnelService.self) private var splitTunnel
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showThemePicker = false
    @State private var showSplitTunnel = false
    @State private var showHelpCenter = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

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

                    // Delete Account
                    deleteAccountButton

                    // Version
                    Text(L10n.Settings.appVersion(appVersion))
                        .vpnTextStyle(.caption, color: .vpnTextTertiary)
                        .padding(.top, VPNSpacing.sm)
                }
                .padding(.horizontal, VPNSpacing.md)
                .padding(.top, VPNSpacing.md)
                .padding(.bottom, VPNSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog(L10n.Settings.signOut, isPresented: $showLogoutConfirmation) {
            Button(L10n.Settings.signOut, role: .destructive) {
                Task {
                    if vpn.status == .connected {
                        try? await vpn.disconnect()
                    }
                    auth.logout()
                }
            }
        } message: {
            if vpn.status == .connected {
                Text(L10n.Settings.signOutConfirmConnected)
            } else {
                Text(L10n.Settings.signOutConfirm)
            }
        }
        .confirmationDialog(L10n.Settings.deleteAccount, isPresented: $showDeleteAccountConfirmation) {
            Button(L10n.Settings.deleteAccountButton, role: .destructive) {
                Task {
                    if vpn.status == .connected {
                        try? await vpn.disconnect()
                    }
                    await auth.deleteAccount()
                }
            }
        } message: {
            if vpn.status == .connected {
                Text(L10n.Settings.deleteAccountConfirmConnected)
            } else {
                Text(L10n.Settings.deleteAccountConfirm)
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        settingsSection(title: L10n.Settings.account, icon: "person.fill") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "envelope.fill",
                    title: L10n.Auth.email,
                    value: auth.userEmail ?? L10n.Common.notAvailable
                )

                sectionDivider

                settingsRow(
                    icon: "crown.fill",
                    title: L10n.Settings.plan,
                    value: L10n.Settings.planFree,
                    trailing: {
                        AnyView(comingSoonBadge)
                    }
                )
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        settingsSection(title: L10n.Settings.connection, icon: "network") {
            VStack(spacing: 0) {
                settingsDisabledToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: L10n.Settings.autoConnect,
                    subtitle: L10n.Settings.autoConnectSubtitle
                )

                sectionDivider

                settingsDisabledToggleRow(
                    icon: "xmark.shield.fill",
                    title: L10n.Settings.killSwitch,
                    subtitle: L10n.Settings.killSwitchSubtitle
                )

                sectionDivider

                Button {
                    showSplitTunnel = true
                } label: {
                    settingsRow(
                        icon: "arrow.triangle.branch",
                        title: L10n.Settings.bypassVPN,
                        value: splitTunnel.config.isEnabled ? L10n.Common.on : L10n.Common.off,
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
        settingsSection(title: L10n.Settings.appearance, icon: "paintbrush.fill") {
            Button {
                showThemePicker = true
            } label: {
                settingsRow(
                    icon: themeService.current.icon,
                    title: L10n.Settings.theme,
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
        settingsSection(title: L10n.Settings.support, icon: "questionmark.circle.fill") {
            VStack(spacing: 0) {
                Button {
                    showHelpCenter = true
                } label: {
                    settingsLinkRow(icon: "book.fill", title: L10n.Settings.helpCenter)
                }

                sectionDivider

                Button {
                    showPrivacyPolicy = true
                } label: {
                    settingsLinkRow(icon: "hand.raised.fill", title: L10n.Settings.privacyPolicy)
                }

                sectionDivider

                Button {
                    showTermsOfService = true
                } label: {
                    settingsLinkRow(icon: "doc.text.fill", title: L10n.Settings.termsOfService)
                }
            }
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalDocumentView(document: .privacyPolicy)
        }
        .sheet(isPresented: $showTermsOfService) {
            LegalDocumentView(document: .termsOfUse)
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
                Text(L10n.Settings.signOut)
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

    // MARK: - Delete Account Button

    private var deleteAccountButton: some View {
        Button {
            showDeleteAccountConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                Text(L10n.Settings.deleteAccount)
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
        Text(L10n.Common.comingSoon)
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
