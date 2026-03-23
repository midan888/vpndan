import Foundation

@MainActor
@Observable
final class ServerListViewModel {
    private(set) var servers: [Server] = []
    private(set) var isLoading = false
    private(set) var refreshError: String?
    var error: String?
    var showError = false

    func loadServers() async {
        isLoading = true
        refreshError = nil
        defer { isLoading = false }

        do {
            servers = try await APIClient.shared.getServers()
        } catch let apiError as APIError {
            if servers.isEmpty {
                // No cached data — show full error
                error = apiError.errorDescription
                showError = true
            } else {
                // Have cached data — show inline banner
                refreshError = "Unable to refresh. Showing cached data."
            }
        } catch {
            if servers.isEmpty {
                self.error = "Failed to load servers."
                showError = true
            } else {
                refreshError = "Unable to refresh. Showing cached data."
            }
        }
    }

    func dismissRefreshError() {
        refreshError = nil
    }
}
