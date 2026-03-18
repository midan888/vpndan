import SwiftUI

struct ServersView: View {
    @State private var viewModel = ServerListViewModel()
    @State private var favorites = FavoritesService.shared
    @Environment(VPNManager.self) private var vpn

    @State private var searchText = ""
    @State private var selectedRegion: Region = .all
    @State private var sortOption: SortOption = .name

    var onServerSelected: ((Server) -> Void)?

    // MARK: - Region Filter

    enum Region: String, CaseIterable {
        case all = "All"
        case americas = "Americas"
        case europe = "Europe"
        case asia = "Asia"
        case oceania = "Oceania"

        static let regionMap: [String: Region] = [
            "US": .americas, "CA": .americas, "BR": .americas, "MX": .americas, "AR": .americas, "CL": .americas, "CO": .americas,
            "GB": .europe, "DE": .europe, "FR": .europe, "NL": .europe, "SE": .europe, "CH": .europe, "IT": .europe,
            "ES": .europe, "PL": .europe, "NO": .europe, "DK": .europe, "FI": .europe, "AT": .europe, "BE": .europe,
            "IE": .europe, "PT": .europe, "CZ": .europe, "RO": .europe, "UA": .europe, "RU": .europe,
            "JP": .asia, "SG": .asia, "KR": .asia, "IN": .asia, "HK": .asia, "TW": .asia, "TH": .asia,
            "MY": .asia, "VN": .asia, "PH": .asia, "ID": .asia, "IL": .asia, "TR": .asia, "AE": .asia,
            "AU": .oceania, "NZ": .oceania,
        ]

        func matches(_ country: String) -> Bool {
            if self == .all { return true }
            return Self.regionMap[country.uppercased()] == self
        }
    }

    // MARK: - Sort

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case status = "Status"
    }

    var body: some View {
        ZStack {
            Color.vpnBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.top, VPNSpacing.sm)

                // Region filter
                regionFilter
                    .padding(.top, VPNSpacing.sm)

                // Sort bar
                sortBar
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.top, VPNSpacing.sm)

                // Server list
                if viewModel.isLoading && viewModel.servers.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(Color.vpnPrimary)
                    Spacer()
                } else if displayedServers.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    serverList
                }
            }
        }
        .task {
            await viewModel.loadServers()
        }
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

    // MARK: - Region Filter Chips

    private var regionFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VPNSpacing.sm) {
                ForEach(Region.allCases, id: \.self) { region in
                    regionChip(region)
                }
            }
            .padding(.horizontal, VPNSpacing.md)
        }
    }

    private func regionChip(_ region: Region) -> some View {
        let isSelected = selectedRegion == region
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRegion = region
            }
        } label: {
            Text(region.rawValue)
                .vpnTextStyle(.statusBadge, color: isSelected ? .vpnTextPrimary : .vpnTextSecondary)
                .padding(.horizontal, VPNSpacing.md)
                .padding(.vertical, VPNSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.vpnPrimary : Color.vpnSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.vpnBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            Text("\(displayedServers.count) servers")
                .vpnTextStyle(.caption, color: .vpnTextTertiary)

            Spacer()

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: VPNSpacing.xs) {
                    Text("Sort: \(sortOption.rawValue)")
                        .vpnTextStyle(.statusBadge, color: .vpnTextSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.vpnTextSecondary)
                }
            }
        }
    }

    // MARK: - Server List

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Favorites section
                if !favoriteServers.isEmpty && searchText.isEmpty && selectedRegion == .all {
                    sectionHeader(title: "Favorites", icon: "star.fill")
                        .padding(.horizontal, VPNSpacing.md)
                        .padding(.top, VPNSpacing.md)

                    serverGroup(favoriteServers)
                        .padding(.horizontal, VPNSpacing.md)
                        .padding(.top, VPNSpacing.sm)
                }

                // All servers
                sectionHeader(
                    title: searchText.isEmpty ? "All Servers" : "Results",
                    icon: "globe"
                )
                .padding(.horizontal, VPNSpacing.md)
                .padding(.top, VPNSpacing.md)

                serverGroup(displayedServers)
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.top, VPNSpacing.sm)
                    .padding(.bottom, 100)
            }
        }
        .refreshable {
            await viewModel.loadServers()
        }
        .scrollIndicators(.hidden)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: VPNSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.vpnTextTertiary)

            Text(title.uppercased())
                .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)

            Spacer()
        }
    }

    private func serverGroup(_ servers: [Server]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                Button {
                    onServerSelected?(server)
                } label: {
                    ServerRow(
                        server: server,
                        isConnected: vpn.connectedServer?.id == server.id && vpn.status == .connected,
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VPNSpacing.md) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundStyle(Color.vpnTextTertiary)

            Text("No servers found")
                .vpnTextStyle(.sectionHeader, color: .vpnTextSecondary)

            Text("Try a different search or region filter")
                .vpnTextStyle(.caption, color: .vpnTextTertiary)
        }
    }

    // MARK: - Filtered & Sorted Data

    private var favoriteServers: [Server] {
        viewModel.servers.filter { favorites.isFavorite($0.id) }
    }

    private var displayedServers: [Server] {
        var result = viewModel.servers

        // Region filter
        if selectedRegion != .all {
            result = result.filter { selectedRegion.matches($0.country) }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.country.lowercased().contains(query)
            }
        }

        // Sort
        switch sortOption {
        case .name:
            result.sort { $0.name < $1.name }
        case .status:
            result.sort { ($0.isActive ? 0 : 1) < ($1.isActive ? 0 : 1) }
        }

        return result
    }
}

#Preview {
    ServersView()
        .environment(VPNManager.shared)
}
