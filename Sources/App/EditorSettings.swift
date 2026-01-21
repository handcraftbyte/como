import SwiftUI

/// Centralized editor settings that can be observed throughout the app
@MainActor
final class EditorSettings: ObservableObject {
	static let shared = EditorSettings()

	@AppStorage("fontSize") var fontSize: Double = 13
	@AppStorage("lineHeight") var lineHeight: Double = 1.4
	@AppStorage("showLineNumbers") var showLineNumbers: Bool = true
	@AppStorage("highlightCurrentLine") var highlightCurrentLine: Bool = true
	@AppStorage("wordWrap") var wordWrap: Bool = true
	@AppStorage("tabWidth") var tabWidth: Int = 4
	@AppStorage("useSpacesForTabs") var useSpacesForTabs: Bool = false

	private init() {}

	/// Toggle a setting and return its new value
	func toggle(_ setting: ToggleSetting) -> Bool {
		switch setting {
		case .showLineNumbers:
			showLineNumbers.toggle()
			return showLineNumbers
		case .highlightCurrentLine:
			highlightCurrentLine.toggle()
			return highlightCurrentLine
		case .wordWrap:
			wordWrap.toggle()
			return wordWrap
		case .useSpacesForTabs:
			useSpacesForTabs.toggle()
			return useSpacesForTabs
		}
	}

	enum ToggleSetting: String, CaseIterable {
		case showLineNumbers = "Show Line Numbers"
		case highlightCurrentLine = "Highlight Current Line"
		case wordWrap = "Word Wrap"
		case useSpacesForTabs = "Use Spaces for Tabs"

		var icon: String {
			switch self {
			case .showLineNumbers: return "list.number"
			case .highlightCurrentLine: return "highlighter"
			case .wordWrap: return "text.word.spacing"
			case .useSpacesForTabs: return "space"
			}
		}

		@MainActor
		var currentValue: Bool {
			let settings = EditorSettings.shared
			switch self {
			case .showLineNumbers: return settings.showLineNumbers
			case .highlightCurrentLine: return settings.highlightCurrentLine
			case .wordWrap: return settings.wordWrap
			case .useSpacesForTabs: return settings.useSpacesForTabs
			}
		}
	}
}
