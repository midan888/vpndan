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

    func sendCode(email: String) async throws -> SendCodeResponse {
        let body = SendCodeRequest(email: email)
        return try await post("/auth/send-code", body: body)
    }

    func verifyCode(email: String, code: String) async throws -> AuthResponse {
        let body = VerifyCodeRequest(email: email, code: code)
        return try await post("/auth/verify-code", body: body)
    }

    func refresh(token: String) async throws -> AuthResponse {
        let body = RefreshRequest(refreshToken: token)
        return try await post("/auth/refresh", body: body)
    }

    func deleteAccount() async throws -> DeleteAccountResponse {
        return try await delete("/auth/account", authenticated: true)
    }

    // MARK: - Server Endpoints

    func getServers() async throws -> [Server] {
        return try await get("/servers", authenticated: true)
    }

    // MARK: - GeoIP Endpoints

    func getGeoIPCountries() async throws -> [AvailableCountry] {
        return try await get("/geoip/countries", authenticated: true)
    }

    func getCountryCIDRs(country: String) async throws -> [String] {
        let response: CountryCIDRsResponse = try await get("/geoip/\(country)", authenticated: true)
        return response.cidrs
    }

    // MARK: - Connect Endpoints

    func connect(serverID: UUID) async throws -> WireGuardConfig {
        print("[APIClient] POST /connect serverID=\(serverID)")
        let body = ConnectRequest(serverID: serverID)
        let config: WireGuardConfig = try await post("/connect", body: body, authenticated: true)
        print("[APIClient] /connect success — endpoint=\(config.peerEndpoint) clientIP=\(config.interfaceAddress)")
        return config
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
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        print("[APIClient] \(method) \(url)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[APIClient] network error for \(method) \(url): \(error)")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[APIClient] non-HTTP response for \(method) \(url)")
            throw APIError.serverError
        }

        print("[APIClient] \(method) \(url) → \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            print("[APIClient] response body: \(body)")
        }

        // If 401 and this was an authenticated request, try token refresh
        if httpResponse.statusCode == 401,
           request.value(forHTTPHeaderField: "Authorization") != nil {
            print("[APIClient] 401 — attempting token refresh and retry")
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
