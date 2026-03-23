import Foundation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""

    var isValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
}
