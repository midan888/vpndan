import SwiftUI

enum VPNTab: Int, CaseIterable {
    case home
    case servers
    case settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .servers: return "Servers"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: return "shield.fill"
        case .servers: return "globe"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "shield.fill"
        case .servers: return "globe"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: VPNTab

    var body: some View {
        HStack {
            ForEach(VPNTab.allCases, id: \.rawValue) { tab in
                Spacer()
                tabButton(for: tab)
                Spacer()
            }
        }
        .padding(.top, VPNSpacing.sm + VPNSpacing.xs)
        .padding(.bottom, VPNSpacing.sm)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: VPNRadius.tabBar,
                topTrailingRadius: VPNRadius.tabBar
            )
            .fill(.ultraThinMaterial)
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: VPNRadius.tabBar,
                topTrailingRadius: VPNRadius.tabBar
            )
            .stroke(Color.vpnBorder.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tabButton(for tab: VPNTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: VPNSpacing.xs) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.vpnPrimary : Color.vpnTextTertiary)
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.vpnPrimary : Color.vpnTextTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ZStack {
        Color.vpnBackground.ignoresSafeArea()

        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(.home))
        }
    }
}
