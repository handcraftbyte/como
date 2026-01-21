import SwiftUI
import AppKit

@MainActor
final class ThemeManager: ObservableObject {
	static let shared = ThemeManager()

	@AppStorage("selectedTheme") private var storedTheme: String = Theme.tokyoNight.rawValue

	@Published var currentTheme: Theme {
		didSet {
			storedTheme = currentTheme.rawValue
			updateAppAppearance()
		}
	}

	private init() {
		self.currentTheme = Theme(rawValue: UserDefaults.standard.string(forKey: "selectedTheme") ?? Theme.tokyoNight.rawValue) ?? .tokyoNight
	}

	var colorScheme: ColorScheme {
		currentTheme.colorScheme
	}

	var nsAppearance: NSAppearance? {
		currentTheme.isDark
			? NSAppearance(named: .darkAqua)
			: NSAppearance(named: .aqua)
	}

	private func updateAppAppearance() {
		NSApp.appearance = nsAppearance
	}
}
