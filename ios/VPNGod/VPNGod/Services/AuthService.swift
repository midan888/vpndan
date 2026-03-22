import Foundation

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var isAuthenticated = false
    private(set) var userEmail: String?
    private(set) var isLoading = false
    private(set) var error: String?

    private init() {}

    // MARK: - Session Check

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        // Try silent refresh if we have a refresh token
        guard let refreshToken = KeychainService.getRefreshToken() else {
            isAuthenticated = false
            return
        }

        do {
            let response = try await APIClient.shared.refresh(token: refreshToken)
            KeychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            userEmail = KeychainService.getEmail()
            isAuthenticated = true
        } catch {
            KeychainService.clearTokens()
            isAuthenticated = false
        }
    }

    // MARK: - Auth Actions

    func register(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.register(email: email, password: password)
            KeychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            KeychainService.saveEmail(email)
            userEmail = email
            isAuthenticated = true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
        } catch {
            self.error = "An unexpected error occurred."
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            KeychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            KeychainService.saveEmail(email)
            userEmail = email
            isAuthenticated = true
        } catch let apiError as APIError {
            self.error = apiError.errorDescription
        } catch {
            self.error = "An unexpected error occurred."
        }
    }

    func logout() {
        KeychainService.clearTokens()
        userEmail = nil
        isAuthenticated = false
    }

    func clearError() {
        error = nil
    }
}
