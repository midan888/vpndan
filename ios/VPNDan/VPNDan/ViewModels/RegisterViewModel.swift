import Foundation

@Observable
final class RegisterViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""

    var passwordsMatch: Bool {
        password == confirmPassword
    }

    var isValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        passwordsMatch
    }
}
