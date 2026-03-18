import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String, !url.isEmpty else {
            fatalError("API_BASE_URL not set in Info.plist")
        }
        return url
    }()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let encoder = JSONEncoder()

    private init() {}

    // MARK: - Auth Endpoints

    func register(email: String, password: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, password: password)
        return try await post("/auth/register", body: body)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        return try await post("/auth/login", body: body)
    }

    func refresh(token: String) async throws -> AuthResponse {
        let body = RefreshRequest(refreshToken: token)
        return try await post("/auth/refresh", body: body)
    }

    // MARK: - Server Endpoints

    func getServers() async throws -> [Server] {
        return try await get("/servers", authenticated: true)
    }

    // MARK: - Connect Endpoints

    func connect(serverID: UUID) async throws -> WireGuardConfig {
        let body = ConnectRequest(serverID: serverID)
        return try await post("/connect", body: body, authenticated: true)
    }

    func disconnect() async throws -> DisconnectResponse {
        return try await delete("/connect", authenticated: true)
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(_ path: String, authenticated: Bool = false) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", authenticated: authenticated)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, authenticated: Bool = false) async throws -> T {
        var request = try buildRequest(path: path, method: "POST", authenticated: authenticated)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    private func delete<T: Decodable>(_ path: String, authenticated: Bool = false) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE", authenticated: authenticated)
        return try await execute(request)
    }

    // MARK: - Request Building

    private func buildRequest(path: String, method: String, authenticated: Bool) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            guard let token = KeychainService.getAccessToken() else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Execution with Auto-Refresh

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }

        // If 401 and this was an authenticated request, try token refresh
        if httpResponse.statusCode == 401,
           request.value(forHTTPHeaderField: "Authorization") != nil {
            return try await handleTokenRefreshAndRetry(originalRequest: request)
        }

        return try handleResponse(data: data, statusCode: httpResponse.statusCode)
    }

    private func handleTokenRefreshAndRetry<T: Decodable>(originalRequest: URLRequest) async throws -> T {
        guard let refreshToken = KeychainService.getRefreshToken() else {
            throw APIError.sessionExpired
        }

        do {
            let authResponse: AuthResponse = try await refresh(token: refreshToken)
            KeychainService.saveTokens(access: authResponse.accessToken, refresh: authResponse.refreshToken)

            // Retry original request with new token
            var retryRequest = originalRequest
            retryRequest.setValue("Bearer \(authResponse.accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: retryRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError
            }
            return try handleResponse(data: data, statusCode: httpResponse.statusCode)
        } catch {
            KeychainService.clearTokens()
            throw APIError.sessionExpired
        }
    }

    private func handleResponse<T: Decodable>(data: Data, statusCode: Int) throws -> T {
        switch statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError
            }
        case 400:
            let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
            throw APIError.badRequest(errorResponse?.detail ?? "Bad request")
        case 401:
            throw APIError.unauthorized
        case 404:
            let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
            throw APIError.notFound(errorResponse?.detail ?? "Not found")
        case 409:
            let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
            throw APIError.conflict(errorResponse?.detail ?? "Conflict")
        default:
            throw APIError.serverError
        }
    }
}
