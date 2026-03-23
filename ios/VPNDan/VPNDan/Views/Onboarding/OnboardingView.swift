import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let totalPages = 3

    var body: some View {
        ZStack {
            Color.vpnBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    PermissionPage()
                        .tag(1)
                    PersonalizationPage(onComplete: finishOnboarding)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.horizontal, VPNSpacing.xl)
                    .padding(.bottom, VPNSpacing.xxl)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: VPNSpacing.lg) {
            // Page dots
            HStack(spacing: VPNSpacing.sm) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.vpnPrimary : Color.vpnBorder)
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            // Buttons
            if currentPage < totalPages - 1 {
                HStack(spacing: VPNSpacing.md) {
                    Button {
                        finishOnboarding()
                    } label: {
                        Text("Skip")
                            .vpnTextStyle(.buttonText, color: .vpnTextTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }

                    GradientButton(title: "Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                }
            }
        }
    }

    private func finishOnboarding() {
        OnboardingService.markCompleted()
        onComplete()
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0

    var body: some View {
        VStack(spacing: VPNSpacing.xl) {
            Spacer()

            // Glow background
            ZStack {
                RadialGradient(
                    colors: [Color.vpnPrimary.opacity(0.25), Color.clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 180
                )
                .frame(width: 300, height: 300)

                Image(systemName: "shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.vpnPrimaryGradient)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }

            VStack(spacing: VPNSpacing.md) {
                Text("Total Privacy.\nOne Tap.")
                    .vpnTextStyle(.screenTitle)
                    .multilineTextAlignment(.center)

                Text("VPN Dan encrypts your connection\nand hides your identity from everyone.")
                    .vpnTextStyle(.body, color: .vpnTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, VPNSpacing.xl)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
}

// MARK: - Page 2: VPN Permission

private struct PermissionPage: View {
    var body: some View {
        VStack(spacing: VPNSpacing.xl) {
            Spacer()

            ZStack {
                RadialGradient(
                    colors: [Color.vpnConnected.opacity(0.2), Color.clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 180
                )
                .frame(width: 300, height: 300)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.vpnConnected)
            }

            VStack(spacing: VPNSpacing.md) {
                Text("VPN Permission")
                    .vpnTextStyle(.screenTitle)
                    .multilineTextAlignment(.center)

                Text("VPN Dan needs permission to create a secure tunnel. Your data never leaves your device unencrypted.")
                    .vpnTextStyle(.body, color: .vpnTextSecondary)
                    .multilineTextAlignment(.center)
            }

            // Feature list
            VStack(alignment: .leading, spacing: VPNSpacing.md) {
                featureRow(icon: "checkmark.shield.fill", text: "Military-grade encryption")
                featureRow(icon: "eye.slash.fill", text: "No activity logging")
                featureRow(icon: "bolt.shield.fill", text: "WireGuard protocol")
            }
            .padding(.top, VPNSpacing.md)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, VPNSpacing.xl)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: VPNSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.vpnConnected)
                .frame(width: 24)

            Text(text)
                .vpnTextStyle(.body, color: .vpnTextSecondary)
        }
    }
}

// MARK: - Page 3: Personalization

private struct PersonalizationPage: View {
    @State private var selectedPriority: Priority?
    let onComplete: () -> Void

    enum Priority: String, CaseIterable {
        case privacy = "Privacy"
        case access = "Access"
        case speed = "Speed"

        var icon: String {
            switch self {
            case .privacy: return "lock.fill"
            case .access: return "globe"
            case .speed: return "bolt.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .privacy: return "Hide my identity"
            case .access: return "Unlock content worldwide"
            case .speed: return "Fastest connection possible"
            }
        }

        var color: Color {
            switch self {
            case .privacy: return .vpnPrimary
            case .access: return .vpnConnected
            case .speed: return .vpnConnecting
            }
        }
    }

    var body: some View {
        VStack(spacing: VPNSpacing.xl) {
            Spacer()

            VStack(spacing: VPNSpacing.md) {
                Text("What's Your\nPriority?")
                    .vpnTextStyle(.screenTitle)
                    .multilineTextAlignment(.center)

                Text("We'll optimize your experience accordingly.")
                    .vpnTextStyle(.body, color: .vpnTextSecondary)
                    .multilineTextAlignment(.center)
            }

            // Priority cards
            VStack(spacing: VPNSpacing.md) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    priorityCard(priority)
                }
            }

            Spacer()

            // Get Started button
            GradientButton(title: "Get Started") {
                onComplete()
            }
            .padding(.horizontal, VPNSpacing.xl)

            Spacer()
        }
        .padding(.horizontal, VPNSpacing.xl)
    }

    private func priorityCard(_ priority: Priority) -> some View {
        let isSelected = selectedPriority == priority

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPriority = priority
            }
        } label: {
            HStack(spacing: VPNSpacing.md) {
                Image(systemName: priority.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? priority.color : Color.vpnTextTertiary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: VPNSpacing.xs) {
                    Text(priority.rawValue)
                        .vpnTextStyle(.sectionHeader, color: isSelected ? .vpnTextPrimary : .vpnTextSecondary)
                    Text(priority.subtitle)
                        .vpnTextStyle(.caption, color: .vpnTextTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(priority.color)
                }
            }
            .padding(VPNSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .fill(isSelected ? priority.color.opacity(0.08) : Color.vpnSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .stroke(isSelected ? priority.color.opacity(0.4) : Color.vpnBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}

// MARK: - Onboarding Persistence

enum OnboardingService {
    private static let key = "vpn_onboarding_completed"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
