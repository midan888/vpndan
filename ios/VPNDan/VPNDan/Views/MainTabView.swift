import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: VPNTab = .home
    @Environment(VPNManager.self) private var vpn

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "shield.fill", value: .home) {
                HomeView()
            }

            Tab("Servers", systemImage: "globe", value: .servers) {
                ServersView(onServerSelected: { server in
                    connectToServer(server)
                    selectedTab = .home
                })
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private func connectToServer(_ server: Server) {
        Task {
            if vpn.status == .connected {
                try? await vpn.disconnect()
            }
            try? await vpn.connect(server: server)
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthService.shared)
        .environment(VPNManager.shared)
}
