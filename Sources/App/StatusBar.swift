import SwiftUI

struct StatusBar: View {
	let language: Language
	let cursorPosition: CursorPosition
	let encoding: String
	let lineEnding: String
	var errorCount: Int = 0
	var warningCount: Int = 0
	@Binding var showDiagnosticsPanel: Bool

	@EnvironmentObject var themeManager: ThemeManager

	var body: some View {
		HStack(spacing: 16) {
			Text(cursorPosition.displayString)
				.font(.system(size: 11, weight: .medium, design: .monospaced))

			// Diagnostics summary - clickable to toggle panel
			if errorCount > 0 || warningCount > 0 {
				Button(action: { showDiagnosticsPanel.toggle() }) {
					HStack(spacing: 8) {
						if errorCount > 0 {
							HStack(spacing: 2) {
								Image(systemName: "xmark.circle.fill")
									.foregroundColor(.red)
								Text("\(errorCount)")
							}
						}
						if warningCount > 0 {
							HStack(spacing: 2) {
								Image(systemName: "exclamationmark.triangle.fill")
									.foregroundColor(.yellow)
								Text("\(warningCount)")
							}
						}
					}
					.font(.system(size: 11, weight: .medium))
				}
				.buttonStyle(.plain)
				.opacity(showDiagnosticsPanel ? 1.0 : 0.8)
			}

			Spacer()

			Text(lineEnding)
				.font(.system(size: 11, weight: .medium))

			Text(encoding)
				.font(.system(size: 11, weight: .medium))

			// Language display (non-interactive)
			Text(language.rawValue)
				.font(.system(size: 11, weight: .medium))
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(themeManager.currentTheme.backgroundColor)
		.foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
	}
}
