import SwiftUI

struct SplitTunnelSettingsView: View {
    @Environment(SplitTunnelService.self) private var splitTunnel
    @Environment(VPNManager.self) private var vpn
    @Environment(\.dismiss) private var dismiss
    @State private var showAddEntry = false
    @State private var newEntry = ""
    @State private var showCountryPicker = false
    @State private var availableCountries: [AvailableCountry] = []
    @State private var isLoadingCountries = false
    @State private var countrySearchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vpnBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VPNSpacing.lg) {
                        masterToggle

                        if splitTunnel.config.isEnabled {
                            presetsSection
                            countryBypassSection
                            excludedEntriesSection
                            infoSection
                        }
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.top, VPNSpacing.md)
                    .padding(.bottom, VPNSpacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Bypass VPN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.vpnPrimary)
                }
            }
            .alert("Exclude Domain or IP", isPresented: $showAddEntry) {
                TextField("e.g. google.com or 192.168.1.0/24", text: $newEntry)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) { newEntry = "" }
                Button("Add") {
                    let trimmed = newEntry.trimmingCharacters(in: .whitespaces).lowercased()
                    if let entry = parseEntry(trimmed) {
                        splitTunnel.addEntry(entry)
                    }
                    newEntry = ""
                }
            } message: {
                Text("Enter a domain name (e.g. google.com) or IP range in CIDR notation (e.g. 10.0.0.0/8).")
            }
        }
    }

    // MARK: - Master Toggle

    private var masterToggle: some View {
        settingsSection(title: "Bypass VPN", icon: "arrow.triangle.branch") {
            toggleRow(
                icon: "arrow.triangle.branch",
                title: "Bypass VPN",
                subtitle: "Let certain apps and sites skip the VPN",
                isOn: Binding(
                    get: { splitTunnel.config.isEnabled },
                    set: { splitTunnel.setEnabled($0) }
                )
            )
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        settingsSection(title: "Presets", icon: "sparkles") {
            VStack(spacing: 0) {
                ForEach(Array(SplitTunnelPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                    if index > 0 { sectionDivider }
                    toggleRow(
                        icon: preset.icon,
                        title: preset.displayName,
                        subtitle: preset.subtitle,
                        isOn: Binding(
                            get: { splitTunnel.isPresetEnabled(preset) },
                            set: { _ in splitTunnel.togglePreset(preset) }
                        )
                    )
                }
            }
        }
    }

    // MARK: - Country Bypass

    private var countryBypassSection: some View {
        settingsSection(title: "Bypass by Country", icon: "globe.americas") {
            VStack(spacing: 0) {
                if splitTunnel.config.excludedCountries.isEmpty {
                    HStack {
                        Text("No countries selected")
                            .vpnTextStyle(.body, color: .vpnTextTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.vertical, VPNSpacing.md)
                } else {
                    ForEach(Array(splitTunnel.config.excludedCountries.sorted().enumerated()), id: \.element) { index, code in
                        if index > 0 { sectionDivider }
                        HStack(spacing: VPNSpacing.md) {
                            Text(countryFlag(for: code))
                                .font(.system(size: 20))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(Locale.current.localizedString(forRegionCode: code) ?? code)
                                    .vpnTextStyle(.body)
                                Text(code.uppercased())
                                    .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
                            }

                            Spacer()

                            Button {
                                splitTunnel.toggleCountry(code)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.vpnDisconnected)
                            }
                        }
                        .padding(.horizontal, VPNSpacing.md)
                        .padding(.vertical, VPNSpacing.sm + VPNSpacing.xs)
                    }
                }

                sectionDivider

                Button {
                    showCountryPicker = true
                    loadCountries()
                } label: {
                    HStack(spacing: VPNSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.vpnPrimary)
                            .frame(width: 20)

                        Text("Add Country")
                            .vpnTextStyle(.body, color: .vpnPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.vertical, VPNSpacing.md)
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            countryPickerSheet
        }
    }

    private var countryPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.vpnBackground.ignoresSafeArea()

                if isLoadingCountries {
                    ProgressView()
                        .tint(Color.vpnPrimary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredCountries) { country in
                                let isSelected = splitTunnel.isCountryExcluded(country.country)
                                Button {
                                    splitTunnel.toggleCountry(country.country)
                                } label: {
                                    HStack(spacing: VPNSpacing.md) {
                                        Text(country.flag)
                                            .font(.system(size: 24))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(country.displayName)
                                                .vpnTextStyle(.body)
                                            Text("\(country.count) IP ranges")
                                                .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
                                        }

                                        Spacer()

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundStyle(isSelected ? Color.vpnPrimary : Color.vpnTextTertiary)
                                    }
                                    .padding(.horizontal, VPNSpacing.md)
                                    .padding(.vertical, VPNSpacing.sm + VPNSpacing.xs)
                                }

                                Divider()
                                    .background(Color.vpnBorder.opacity(0.5))
                                    .padding(.leading, 60)
                            }
                        }
                        .padding(.bottom, VPNSpacing.xxl)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Select Countries")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $countrySearchText, prompt: "Search countries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCountryPicker = false }
                        .foregroundStyle(Color.vpnPrimary)
                }
            }
        }
    }

    private var filteredCountries: [AvailableCountry] {
        if countrySearchText.isEmpty {
            return availableCountries
        }
        let query = countrySearchText.lowercased()
        return availableCountries.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.country.lowercased().contains(query)
        }
    }

    private func loadCountries() {
        guard availableCountries.isEmpty else { return }
        isLoadingCountries = true
        Task {
            do {
                availableCountries = try await APIClient.shared.getGeoIPCountries()
            } catch {
                print("[SplitTunnel] failed to load countries: \(error)")
            }
            isLoadingCountries = false
        }
    }

    private func countryFlag(for code: String) -> String {
        let base: UInt32 = 127397
        return code
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    // MARK: - Excluded Entries

    private var excludedEntriesSection: some View {
        settingsSection(title: "Excluded Domains & IPs", icon: "network") {
            VStack(spacing: 0) {
                if splitTunnel.config.excludedEntries.isEmpty {
                    HStack {
                        Text("No exclusions added")
                            .vpnTextStyle(.body, color: .vpnTextTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.vertical, VPNSpacing.md)
                } else {
                    ForEach(Array(splitTunnel.config.excludedEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { sectionDivider }
                        HStack(spacing: VPNSpacing.md) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.vpnPrimary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.value)
                                    .vpnTextStyle(.body)
                                Text(entry.type == .domain ? "Domain" : "IP Range")
                                    .vpnTextStyle(.statusBadge, color: .vpnTextTertiary)
                            }

                            Spacer()

                            Button {
                                splitTunnel.removeEntry(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.vpnDisconnected)
                            }
                        }
                        .padding(.horizontal, VPNSpacing.md)
                        .padding(.vertical, VPNSpacing.sm + VPNSpacing.xs)
                    }
                }

                sectionDivider

                Button {
                    showAddEntry = true
                } label: {
                    HStack(spacing: VPNSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.vpnPrimary)
                            .frame(width: 20)

                        Text("Add Domain or IP")
                            .vpnTextStyle(.body, color: .vpnPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, VPNSpacing.md)
                    .padding(.vertical, VPNSpacing.md)
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: VPNSpacing.sm) {
            HStack(alignment: .top, spacing: VPNSpacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.vpnTextTertiary)

                Text("Bypassed sites and addresses will use your regular internet connection instead of the VPN.")
                    .vpnTextStyle(.caption, color: .vpnTextTertiary)
            }

            if vpn.status == .connected {
                HStack(spacing: VPNSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.vpnConnecting)

                    Text("Changes will take effect on next connection.")
                        .vpnTextStyle(.caption, color: .vpnConnecting)
                }
            }
        }
        .padding(.horizontal, VPNSpacing.xs)
    }

    // MARK: - UI Helpers

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

    private func toggleRow(
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

    private var sectionDivider: some View {
        Divider()
            .background(Color.vpnBorder.opacity(0.5))
            .padding(.leading, 52)
    }

    // MARK: - Input Parsing

    private func parseEntry(_ input: String) -> ExcludedEntry? {
        guard !input.isEmpty else { return nil }

        // Check if it's a valid CIDR
        if isValidCIDR(input) {
            return ExcludedEntry(value: input, type: .ip)
        }

        // Check if it's a plain IP (add /32)
        if isValidIP(input) {
            return ExcludedEntry(value: "\(input)/32", type: .ip)
        }

        // Otherwise treat as domain
        if isValidDomain(input) {
            return ExcludedEntry(value: input, type: .domain)
        }

        return nil
    }

    private func isValidCIDR(_ string: String) -> Bool {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let prefix = Int(parts[1]),
              prefix >= 0 && prefix <= 32 else {
            return false
        }
        return isValidIP(String(parts[0]))
    }

    private func isValidIP(_ string: String) -> Bool {
        let octets = string.split(separator: ".")
        guard octets.count == 4 else { return false }
        return octets.allSatisfy { octet in
            guard let value = Int(octet) else { return false }
            return value >= 0 && value <= 255
        }
    }

    private func isValidDomain(_ string: String) -> Bool {
        let pattern = #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$"#
        return string.range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    SplitTunnelSettingsView()
        .environment(SplitTunnelService.shared)
        .environment(VPNManager.shared)
}
