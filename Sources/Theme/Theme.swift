import SwiftUI
import AppKit

enum Theme: String, CaseIterable, Identifiable, Codable {
	case nord
	case nordLight
	case tokyoNight
	case tokyoNightLight

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .nord: return "Nord"
		case .nordLight: return "Nord Light"
		case .tokyoNight: return "Tokyo Night"
		case .tokyoNightLight: return "Tokyo Night Light"
		}
	}

	var isDark: Bool {
		switch self {
		case .nord, .tokyoNight: return true
		case .nordLight, .tokyoNightLight: return false
		}
	}

	var colorScheme: ColorScheme {
		isDark ? .dark : .light
	}
}

// MARK: - Nord Theme Colors
extension Theme {
	// Nord Polar Night (dark backgrounds)
	static let nord0 = Color(hex: "2E3440")
	static let nord1 = Color(hex: "3B4252")
	static let nord2 = Color(hex: "434C5E")
	static let nord3 = Color(hex: "4C566A")

	// Nord Snow Storm (light backgrounds/text)
	static let nord4 = Color(hex: "D8DEE9")
	static let nord5 = Color(hex: "E5E9F0")
	static let nord6 = Color(hex: "ECEFF4")

	// Nord Frost (accent colors)
	static let nord7 = Color(hex: "8FBCBB")   // cyan
	static let nord8 = Color(hex: "88C0D0")   // light blue
	static let nord9 = Color(hex: "81A1C1")   // blue
	static let nord10 = Color(hex: "5E81AC")  // dark blue

	// Nord Aurora (semantic colors)
	static let nord11 = Color(hex: "BF616A")  // red
	static let nord12 = Color(hex: "D08770")  // orange
	static let nord13 = Color(hex: "EBCB8B")  // yellow
	static let nord14 = Color(hex: "A3BE8C")  // green
	static let nord15 = Color(hex: "B48EAD")  // purple
}

// MARK: - Tokyo Night Theme Colors
extension Theme {
	// Tokyo Night backgrounds
	static let tokyoBg = Color(hex: "1A1B26")
	static let tokyoBgDark = Color(hex: "16161E")
	static let tokyoBgHighlight = Color(hex: "292E42")
	static let tokyoTerminalBlack = Color(hex: "414868")

	// Tokyo Night foregrounds
	static let tokyoFg = Color(hex: "C0CAF5")
	static let tokyoFgDark = Color(hex: "A9B1D6")
	static let tokyoFgGutter = Color(hex: "3B4261")

	// Tokyo Night colors
	static let tokyoBlue = Color(hex: "7AA2F7")
	static let tokyoCyan = Color(hex: "7DCFFF")
	static let tokyoMagenta = Color(hex: "BB9AF7")
	static let tokyoGreen = Color(hex: "9ECE6A")
	static let tokyoOrange = Color(hex: "FF9E64")
	static let tokyoRed = Color(hex: "F7768E")
	static let tokyoYellow = Color(hex: "E0AF68")
	static let tokyoTeal = Color(hex: "1ABC9C")

	// Tokyo Night Light
	static let tokyoLightBg = Color(hex: "D5D6DB")
	static let tokyoLightFg = Color(hex: "343B58")
	static let tokyoLightBlue = Color(hex: "34548A")
}

// MARK: - Theme Colors
extension Theme {
	var backgroundColor: Color {
		switch self {
		case .nord: return Theme.nord0
		case .nordLight: return Theme.nord6
		case .tokyoNight: return Theme.tokyoBg
		case .tokyoNightLight: return Theme.tokyoLightBg
		}
	}

	var editorBackground: Color {
		switch self {
		case .nord: return Theme.nord0
		case .nordLight: return Theme.nord6
		case .tokyoNight: return Theme.tokyoBg
		case .tokyoNightLight: return Theme.tokyoLightBg
		}
	}

	var foregroundColor: Color {
		switch self {
		case .nord: return Theme.nord4
		case .nordLight: return Theme.nord0
		case .tokyoNight: return Theme.tokyoFg
		case .tokyoNightLight: return Theme.tokyoLightFg
		}
	}

	var cursorColor: Color {
		switch self {
		case .nord: return Theme.nord4
		case .nordLight: return Theme.nord0
		case .tokyoNight: return Theme.tokyoFg
		case .tokyoNightLight: return Theme.tokyoLightFg
		}
	}

	var selectionColor: Color {
		switch self {
		case .nord: return Theme.nord2
		case .nordLight: return Theme.nord4
		case .tokyoNight: return Theme.tokyoBgHighlight
		case .tokyoNightLight: return Theme.tokyoLightBg.opacity(0.5)
		}
	}

	var lineNumberColor: Color {
		switch self {
		case .nord: return Theme.nord3
		case .nordLight: return Theme.nord3
		case .tokyoNight: return Theme.tokyoFgGutter
		case .tokyoNightLight: return Theme.tokyoLightFg.opacity(0.5)
		}
	}

	var currentLineBackground: Color {
		switch self {
		case .nord: return Theme.nord1
		case .nordLight: return Theme.nord5
		case .tokyoNight: return Theme.tokyoBgHighlight.opacity(0.5)
		case .tokyoNightLight: return Theme.tokyoLightBg.opacity(0.8)
		}
	}

	var statusBarBackground: Color {
		switch self {
		case .nord: return Theme.nord1
		case .nordLight: return Theme.nord5
		case .tokyoNight: return Theme.tokyoBgDark
		case .tokyoNightLight: return Theme.tokyoLightBg.opacity(0.9)
		}
	}
}

// MARK: - Syntax Colors
extension Theme {
	var syntaxKeyword: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord9
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoMagenta
		}
	}

	var syntaxString: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord14
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoGreen
		}
	}

	var syntaxComment: Color {
		switch self {
		case .nord: return Theme.nord3
		case .nordLight: return Theme.nord3
		case .tokyoNight: return Theme.tokyoTerminalBlack
		case .tokyoNightLight: return Theme.tokyoLightFg.opacity(0.5)
		}
	}

	var syntaxNumber: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord15
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoOrange
		}
	}

	var syntaxFunction: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord8
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoBlue
		}
	}

	var syntaxType: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord7
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoCyan
		}
	}

	var syntaxVariable: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord4
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoFg
		}
	}

	var syntaxOperator: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord9
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoCyan
		}
	}

	var syntaxConstant: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord12
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoOrange
		}
	}

	var syntaxError: Color {
		switch self {
		case .nord, .nordLight: return Theme.nord11
		case .tokyoNight, .tokyoNightLight: return Theme.tokyoRed
		}
	}
}

// MARK: - NSColor conversions
extension Theme {
	var nsBackgroundColor: NSColor {
		NSColor(backgroundColor)
	}

	var nsForegroundColor: NSColor {
		NSColor(foregroundColor)
	}

	var nsCursorColor: NSColor {
		NSColor(cursorColor)
	}

	var nsSelectionColor: NSColor {
		NSColor(selectionColor)
	}
}

// MARK: - Color Extension
extension Color {
	init(hex: String) {
		let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		var int: UInt64 = 0
		Scanner(string: hex).scanHexInt64(&int)
		let a, r, g, b: UInt64
		switch hex.count {
		case 3: // RGB (12-bit)
			(a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
		case 6: // RGB (24-bit)
			(a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
		case 8: // ARGB (32-bit)
			(a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
		default:
			(a, r, g, b) = (255, 0, 0, 0)
		}

		self.init(
			.sRGB,
			red: Double(r) / 255,
			green: Double(g) / 255,
			blue: Double(b) / 255,
			opacity: Double(a) / 255
		)
	}
}
