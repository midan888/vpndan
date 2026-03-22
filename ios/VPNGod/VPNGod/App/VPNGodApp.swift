import SwiftUI

@main
struct VPNGodApp: App {
    @State private var auth = AuthService.shared
    @State private var vpn = VPNManager.shared
    @State private var theme = ThemeService.shared
    @State private var showOnboarding = !OnboardingService.isCompleted

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showOnboarding = false
                        }
                    }
                } else if auth.isLoading {
                    splashView
                } else if auth.isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: auth.isAuthenticated)
            .animation(.easeInOut(duration: 0.35), value: auth.isLoading)
            .environment(auth)
            .environment(vpn)
            .environment(theme)
            .preferredColorScheme(theme.current.isDark ? .dark : .light)
            .task {
                await auth.checkSession()
                await vpn.syncStatus()
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color.vpnBackground.ignoresSafeArea()

            VStack(spacing: VPNSpacing.md) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.vpnPrimaryGradient)

                ProgressView()
                    .tint(Color.vpnPrimary)
            }
        }
    }
}
