import SwiftUI

@Observable
final class ThemeService: @unchecked Sendable {
    static let shared = ThemeService()

    private(set) var current: ColorTheme

    private let themeKey = "selectedThemeID"

    private init() {
        let savedID = UserDefaults.standard.string(forKey: themeKey) ?? ColorTheme.default.id
        self.current = ColorTheme.allThemes.first { $0.id == savedID } ?? .default
    }

    func setTheme(_ theme: ColorTheme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: themeKey)
    }
}
