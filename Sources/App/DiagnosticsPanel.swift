import SwiftUI

/// Panel showing diagnostic messages (errors, warnings, info)
struct DiagnosticsPanel: View {
	let diagnostics: [Diagnostic]
	var onDiagnosticClick: ((Diagnostic) -> Void)?

	@EnvironmentObject var themeManager: ThemeManager

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			// Header
			HStack {
				Text("Problems")
					.font(.system(size: 12, weight: .semibold))

				Spacer()

				// Summary
				HStack(spacing: 12) {
					if errorCount > 0 {
						Label("\(errorCount)", systemImage: "xmark.circle.fill")
							.foregroundColor(.red)
					}
					if warningCount > 0 {
						Label("\(warningCount)", systemImage: "exclamationmark.triangle.fill")
							.foregroundColor(.yellow)
					}
					if infoCount > 0 {
						Label("\(infoCount)", systemImage: "info.circle.fill")
							.foregroundColor(.blue)
					}
				}
				.font(.system(size: 11))
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(themeManager.currentTheme.backgroundColor.opacity(0.8))

			Divider()

			// Diagnostics list
			if diagnostics.isEmpty {
				HStack {
					Spacer()
					Text("No problems detected")
						.font(.system(size: 12))
						.foregroundColor(.secondary)
					Spacer()
				}
				.padding(.vertical, 20)
			} else {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 0) {
						ForEach(sortedDiagnostics, id: \.self) { diagnostic in
							DiagnosticRow(diagnostic: diagnostic)
								.onTapGesture {
									onDiagnosticClick?(diagnostic)
								}
						}
					}
				}
			}
		}
		.background(themeManager.currentTheme.backgroundColor)
		.frame(height: 150)
	}

	private var errorCount: Int {
		diagnostics.filter { $0.severity == .error }.count
	}

	private var warningCount: Int {
		diagnostics.filter { $0.severity == .warning }.count
	}

	private var infoCount: Int {
		diagnostics.filter { $0.severity == .suggestion || $0.severity == .message }.count
	}

	private var sortedDiagnostics: [Diagnostic] {
		diagnostics.sorted { d1, d2 in
			// Sort by severity (errors first), then by position
			if d1.severity.sortOrder != d2.severity.sortOrder {
				return d1.severity.sortOrder < d2.severity.sortOrder
			}
			return d1.range.lowerBound < d2.range.lowerBound
		}
	}
}

struct DiagnosticRow: View {
	let diagnostic: Diagnostic

	@EnvironmentObject var themeManager: ThemeManager
	@State private var isHovered = false

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			// Severity icon
			Image(systemName: diagnostic.severity.iconName)
				.foregroundColor(diagnostic.severity.swiftUIColor)
				.frame(width: 16)

			// Message
			VStack(alignment: .leading, spacing: 2) {
				Text(diagnostic.message)
					.font(.system(size: 12))
					.foregroundColor(themeManager.currentTheme.foregroundColor)
					.lineLimit(2)

				// Location
				Text("Position: \(diagnostic.range.lowerBound)")
					.font(.system(size: 10))
					.foregroundColor(.secondary)
			}

			Spacer()
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(isHovered ? themeManager.currentTheme.selectionColor.opacity(0.3) : Color.clear)
		.onHover { hovering in
			isHovered = hovering
		}
	}
}

extension DiagnosticSeverity {
	var sortOrder: Int {
		switch self {
		case .error: return 0
		case .warning: return 1
		case .suggestion: return 2
		case .message: return 3
		}
	}

	var swiftUIColor: Color {
		switch self {
		case .error: return .red
		case .warning: return .yellow
		case .suggestion: return .blue
		case .message: return .gray
		}
	}
}
