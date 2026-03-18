import SwiftUI

struct ServerSelectionSheet: View {
    let servers: [Server]
    let selectedServerID: UUID?
    let connectedServerID: UUID?
    let onSelect: (Server) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var favorites = FavoritesService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VPNSpacing.lg) {
                    // Search
                    searchBar

                    // Favorites section
                    if !favoriteServers.isEmpty && searchText.isEmpty {
                        serverSection(title: "Favorites", icon: "star.fill", servers: favoriteServers)
                    }

                    // All servers (or filtered)
                    if filteredServers.isEmpty {
                        emptyState
                    } else {
                        serverSection(
                            title: searchText.isEmpty ? "All Servers" : "Results",
                            icon: "globe",
                            servers: filteredServers
                        )
                    }
                }
                .padding(.horizontal, VPNSpacing.md)
                .padding(.bottom, VPNSpacing.xl)
            }
            .scrollIndicators(.hidden)
            .background(Color.vpnBackground)
            .navigationTitle("Select Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(Color.vpnPrimary)
                }
            }
            .toolbarBackground(Color.vpnBackground, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.vpnBackground)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: VPNSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.vpnTextTertiary)

            TextField("", text: $searchText, prompt: Text("Search servers...").foregroundStyle(Color.vpnTextTertiary))
                .font(.system(size: 15))
                .foregroundStyle(Color.vpnTextPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.vpnTextTertiary)
                }
            }
        }
        .padding(.horizontal, VPNSpacing.md)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: VPNRadius.textField)
                .fill(Color.vpnSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VPNRadius.textField)
                .stroke(Color.vpnBorder, lineWidth: 1)
        )
    }

    // MARK: - Server Section

    private func serverSection(title: String, icon: String, servers: [Server]) -> some View {
        VStack(alignment: .leading, spacing: VPNSpacing.sm) {
            // Section header
            HStack(spacing: VPNSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.vpnTextTertiary)

                Text(title.uppercased())
                    .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
            }
            .padding(.horizontal, VPNSpacing.xs)

            // Server rows in a glass card
            VStack(spacing: 0) {
                ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                    Button {
                        onSelect(server)
                    } label: {
                        ServerRow(
                            server: server,
                            isConnected: connectedServerID == server.id,
                            isSelected: selectedServerID == server.id,
                            isFavorite: favorites.isFavorite(server.id),
                            onFavoriteToggle: { favorites.toggle(server.id) }
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!server.isActive)

                    if index < servers.count - 1 {
                        Divider()
                            .background(Color.vpnBorder.opacity(0.5))
                            .padding(.leading, 60)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VPNRadius.card)
                    .stroke(Color.vpnBorder.opacity(0.5), lineWidth: 1)
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VPNSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.vpnTextTertiary)

            Text("No servers found")
                .vpnTextStyle(.body, color: .vpnTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VPNSpacing.xxl)
    }

    // MARK: - Filtered Data

    private var favoriteServers: [Server] {
        servers.filter { favorites.isFavorite($0.id) }
    }

    private var filteredServers: [Server] {
        if searchText.isEmpty {
            return servers
        }
        let query = searchText.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(query) ||
            $0.country.lowercased().contains(query)
        }
    }
}
