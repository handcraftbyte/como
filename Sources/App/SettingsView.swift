import SwiftUI

struct SettingsView: View {
	@EnvironmentObject var themeManager: ThemeManager
	@AppStorage("fontSize") private var fontSize: Double = 13
	@AppStorage("lineHeight") private var lineHeight: Double = 1.4
	@AppStorage("showLineNumbers") private var showLineNumbers: Bool = true
	@AppStorage("highlightCurrentLine") private var highlightCurrentLine: Bool = true
	@AppStorage("wordWrap") private var wordWrap: Bool = true
	@AppStorage("tabWidth") private var tabWidth: Int = 4
	@AppStorage("useSpacesForTabs") private var useSpacesForTabs: Bool = false

	var body: some View {
		TabView {
			GeneralSettingsView(
				fontSize: $fontSize,
				lineHeight: $lineHeight,
				showLineNumbers: $showLineNumbers,
				highlightCurrentLine: $highlightCurrentLine,
				wordWrap: $wordWrap
			)
			.tabItem {
				Label("General", systemImage: "gear")
			}

			EditorSettingsView(
				tabWidth: $tabWidth,
				useSpacesForTabs: $useSpacesForTabs
			)
			.tabItem {
				Label("Editor", systemImage: "text.alignleft")
			}

			ThemeSettingsView()
			.tabItem {
				Label("Themes", systemImage: "paintpalette")
			}
		}
		.frame(width: 450, height: 300)
	}
}

struct GeneralSettingsView: View {
	@Binding var fontSize: Double
	@Binding var lineHeight: Double
	@Binding var showLineNumbers: Bool
	@Binding var highlightCurrentLine: Bool
	@Binding var wordWrap: Bool

	var body: some View {
		Form {
			Section("Font") {
				HStack {
					Text("Size")
					Spacer()
					TextField("", value: $fontSize, format: .number)
						.frame(width: 60)
						.textFieldStyle(.roundedBorder)
					Stepper("", value: $fontSize, in: 8...32)
						.labelsHidden()
				}

				HStack {
					Text("Line Height")
					Spacer()
					TextField("", value: $lineHeight, format: .number.precision(.fractionLength(1)))
						.frame(width: 60)
						.textFieldStyle(.roundedBorder)
				}
			}

			Section("Display") {
				Toggle("Show Line Numbers", isOn: $showLineNumbers)
				Toggle("Highlight Current Line", isOn: $highlightCurrentLine)
				Toggle("Word Wrap", isOn: $wordWrap)
			}
		}
		.padding()
	}
}

struct EditorSettingsView: View {
	@Binding var tabWidth: Int
	@Binding var useSpacesForTabs: Bool

	var body: some View {
		Form {
			Section("Indentation") {
				Picker("Tab Width", selection: $tabWidth) {
					Text("2").tag(2)
					Text("4").tag(4)
					Text("8").tag(8)
				}

				Toggle("Use Spaces for Tabs", isOn: $useSpacesForTabs)
			}

			Section("Behavior") {
				Text("EditorConfig files are automatically detected and applied.")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
		.padding()
	}
}

struct ThemeSettingsView: View {
	@EnvironmentObject var themeManager: ThemeManager

	var body: some View {
		Form {
			Section("Theme") {
				Picker("Current Theme", selection: $themeManager.currentTheme) {
					ForEach(Theme.allCases) { theme in
						HStack {
							Circle()
								.fill(theme.backgroundColor)
								.frame(width: 12, height: 12)
								.overlay(
									Circle()
										.stroke(Color.secondary.opacity(0.3), lineWidth: 1)
								)
							Text(theme.displayName)
						}
						.tag(theme)
					}
				}
			}

			Section("Preview") {
				ThemePreview(theme: themeManager.currentTheme)
			}
		}
		.padding()
	}
}

struct ThemePreview: View {
	let theme: Theme

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 0) {
				Text("func ")
					.foregroundColor(theme.syntaxKeyword)
				Text("greet")
					.foregroundColor(theme.syntaxFunction)
				Text("(")
					.foregroundColor(theme.foregroundColor)
				Text("name")
					.foregroundColor(theme.syntaxVariable)
				Text(": ")
					.foregroundColor(theme.foregroundColor)
				Text("String")
					.foregroundColor(theme.syntaxType)
				Text(") {")
					.foregroundColor(theme.foregroundColor)
			}

			HStack(spacing: 0) {
				Text("    print")
					.foregroundColor(theme.syntaxFunction)
				Text("(")
					.foregroundColor(theme.foregroundColor)
				Text("\"Hello, \\(name)!\"")
					.foregroundColor(theme.syntaxString)
				Text(")")
					.foregroundColor(theme.foregroundColor)
			}

			Text("}")
				.foregroundColor(theme.foregroundColor)

			Text("// A simple greeting function")
				.foregroundColor(theme.syntaxComment)
		}
		.font(.system(size: 12, design: .monospaced))
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(theme.backgroundColor)
		.cornerRadius(8)
	}
}
