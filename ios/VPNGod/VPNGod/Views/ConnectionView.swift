import SwiftUI

struct ConnectionView: View {
    let server: Server
    @Environment(VPNManager.self) private var vpn
    @State private var error: String?
    @State private var showError = false
    @State private var showSwitchConfirmation = false

    private var isConnectedToThis: Bool {
        vpn.connectedServer?.id == server.id && vpn.status == .connected
    }

    private var isConnectingToThis: Bool {
        vpn.connectedServer?.id == server.id && vpn.status == .connecting
    }

    private var isBusy: Bool {
        vpn.status == .connecting || vpn.status == .disconnecting
    }

    /// Connected to a *different* server
    private var isConnectedToOther: Bool {
        vpn.status == .connected && vpn.connectedServer?.id != server.id
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Server info
            VStack(spacing: 8) {
                Text(flag(for: server.country))
                    .font(.system(size: 64))

                Text(server.name)
                    .font(.title2.bold())
            }

            // Status
            VStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if isConnectedToThis, let ip = vpn.connectedServer?.host {
                    Text(ip)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Connect / Disconnect button
            Button {
                if isConnectedToOther {
                    showSwitchConfirmation = true
                } else {
                    Task { await toggleConnection() }
                }
            } label: {
                Group {
                    if isBusy {
                        ProgressView()
                    } else {
                        Text(isConnectedToThis ? "Disconnect" : "Connect")
                    }
                }
                .font(.title3.bold())
                .frame(width: 200, height: 200)
                .background(
                    Circle()
                        .fill(isConnectedToThis ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                )
                .overlay(
                    Circle()
                        .stroke(isConnectedToThis ? Color.red : Color.green, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Spacer()
            Spacer()
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(error ?? "")
        }
        .confirmationDialog("Switch Server", isPresented: $showSwitchConfirmation) {
            Button("Switch") {
                Task { await switchServer() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You are connected to \(vpn.connectedServer?.name ?? "another server"). Disconnect and connect to \(server.name)?")
        }
    }

    private var statusText: String {
        if isConnectingToThis { return "Connecting..." }
        if isConnectedToThis { return "Connected" }
        if vpn.status == .disconnecting { return "Disconnecting..." }
        return "Disconnected"
    }

    private var statusColor: Color {
        if isConnectedToThis { return .green }
        if isBusy { return .yellow }
        return .gray
    }

    private func toggleConnection() async {
        do {
            if isConnectedToThis {
                try await vpn.disconnect()
            } else {
                try await vpn.connect(server: server)
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
            showError = true
        } catch {
            self.error = "Connection failed. Please try again."
            showError = true
        }
    }

    private func switchServer() async {
        do {
            try await vpn.disconnect()
            try await vpn.connect(server: server)
        } catch let apiError as APIError {
            error = apiError.errorDescription
            showError = true
        } catch {
            self.error = "Connection failed. Please try again."
            showError = true
        }
    }

    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
