import Foundation

struct SendCodeRequest: Encodable {
    let email: String
}

struct SendCodeResponse: Decodable {
    let message: String
}

struct VerifyCodeRequest: Encodable {
    let email: String
    let code: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct DeleteAccountResponse: Decodable {
    let message: String
}

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
