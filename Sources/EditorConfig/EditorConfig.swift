import Foundation

struct EditorConfig: Equatable {
	var indentStyle: IndentStyle
	var indentSize: Int
	var tabWidth: Int
	var endOfLine: EndOfLine
	var charset: Charset
	var trimTrailingWhitespace: Bool
	var insertFinalNewline: Bool
	var maxLineLength: Int?

	enum IndentStyle: String {
		case tab
		case space
	}

	enum EndOfLine: String {
		case lf
		case crlf
		case cr
	}

	enum Charset: String {
		case utf8 = "utf-8"
		case utf8Bom = "utf-8-bom"
		case utf16be = "utf-16be"
		case utf16le = "utf-16le"
		case latin1 = "latin1"
	}

	static let `default` = EditorConfig(
		indentStyle: .tab,
		indentSize: 4,
		tabWidth: 4,
		endOfLine: .lf,
		charset: .utf8,
		trimTrailingWhitespace: true,
		insertFinalNewline: true,
		maxLineLength: nil
	)
}

final class EditorConfigParser {
	static func parse(at url: URL) -> EditorConfig? {
		guard let content = try? String(contentsOf: url, encoding: .utf8) else {
			return nil
		}

		return parse(content: content)
	}

	static func parse(content: String) -> EditorConfig {
		var config = EditorConfig.default
		var currentSectionMatches = true

		let lines = content.components(separatedBy: .newlines)

		for line in lines {
			let trimmed = line.trimmingCharacters(in: .whitespaces)

			// Skip empty lines and comments
			if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
				continue
			}

			// Check for section header
			if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
				// For now, we'll match all patterns (simplified)
				currentSectionMatches = true
				continue
			}

			// Parse key=value pairs
			guard currentSectionMatches else { continue }

			let parts = trimmed.split(separator: "=", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
			let value = parts[1].trimmingCharacters(in: .whitespaces).lowercased()

			switch key {
			case "indent_style":
				if let style = EditorConfig.IndentStyle(rawValue: value) {
					config.indentStyle = style
				}
			case "indent_size":
				if value == "tab" {
					config.indentSize = config.tabWidth
				} else if let size = Int(value) {
					config.indentSize = size
				}
			case "tab_width":
				if let width = Int(value) {
					config.tabWidth = width
				}
			case "end_of_line":
				if let eol = EditorConfig.EndOfLine(rawValue: value) {
					config.endOfLine = eol
				}
			case "charset":
				if let charset = EditorConfig.Charset(rawValue: value) {
					config.charset = charset
				}
			case "trim_trailing_whitespace":
				config.trimTrailingWhitespace = value == "true"
			case "insert_final_newline":
				config.insertFinalNewline = value == "true"
			case "max_line_length":
				if value != "off" {
					config.maxLineLength = Int(value)
				}
			default:
				break
			}
		}

		return config
	}

	static func findConfig(for fileURL: URL) -> EditorConfig? {
		var currentDir = fileURL.deletingLastPathComponent()

		while true {
			let configURL = currentDir.appendingPathComponent(".editorconfig")

			if FileManager.default.fileExists(atPath: configURL.path) {
				if let config = parse(at: configURL) {
					// Check if this is root
					if let content = try? String(contentsOf: configURL, encoding: .utf8),
					   content.lowercased().contains("root = true") || content.lowercased().contains("root=true") {
						return config
					}

					// Continue searching parent directories
					let parentDir = currentDir.deletingLastPathComponent()
					if parentDir.path == currentDir.path {
						return config
					}
					currentDir = parentDir
					continue
				}
			}

			let parentDir = currentDir.deletingLastPathComponent()
			if parentDir.path == currentDir.path {
				break
			}
			currentDir = parentDir
		}

		return nil
	}
}

extension EditorConfig {
	var indentString: String {
		switch indentStyle {
		case .tab:
			return "\t"
		case .space:
			return String(repeating: " ", count: indentSize)
		}
	}

	var lineEnding: String {
		switch endOfLine {
		case .lf: return "\n"
		case .crlf: return "\r\n"
		case .cr: return "\r"
		}
	}
}
