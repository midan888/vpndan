import SwiftUI

struct ServerListView: View {
    @State private var viewModel = ServerListViewModel()
    @Environment(VPNManager.self) private var vpn

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.servers.isEmpty {
                    ProgressView("Loading servers...")
                } else if viewModel.servers.isEmpty {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text("No servers available at the moment.")
                    )
                } else {
                    VStack(spacing: 0) {
                        if let refreshError = viewModel.refreshError {
                            RefreshErrorBanner(message: refreshError) {
                                viewModel.dismissRefreshError()
                            }
                        }
                        serverList
                    }
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable {
                await viewModel.loadServers()
            }
            .task {
                await viewModel.loadServers()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var serverList: some View {
        List(viewModel.servers) { server in
            NavigationLink(destination: ConnectionView(server: server)) {
                ServerRow(server: server, isConnected: vpn.connectedServer?.id == server.id && vpn.status == .connected)
            }
            .disabled(!server.isActive)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Refresh Error Banner

struct RefreshErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
    }
}

