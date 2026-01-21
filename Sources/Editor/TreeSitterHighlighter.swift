import AppKit
import Neon
import SwiftTreeSitter
import TreeSitterTypeScript
import TreeSitterSwift
import TreeSitterJSON

/// Tree-sitter based syntax highlighter using ChimeHQ's Neon
/// Provides AST-aware highlighting for supported languages
@MainActor
final class TreeSitterHighlighter {
	private var highlighter: TextViewHighlighter?
	private weak var textView: NSTextView?
	private var currentLanguage: Language?
	private var theme: Theme

	init(theme: Theme) {
		self.theme = theme
	}

	/// Configure highlighting for the given text view and language
	func configure(textView: NSTextView, language: Language) {
		self.textView = textView
		self.currentLanguage = language

		// Only set up tree-sitter for supported languages
		guard let languageConfig = makeLanguageConfiguration(for: language) else {
			Log.treeSitter.warning("No parser available for \(language.rawValue)")
			highlighter = nil
			return
		}

		do {
			let config = TextViewHighlighter.Configuration(
				languageConfiguration: languageConfig,
				attributeProvider: { [weak self] token in
					let attrs = self?.attributes(for: token) ?? [:]
					return attrs
				},
				locationTransformer: { [weak textView] location in
					guard let textView = textView,
						  let storage = textView.textStorage else {
						return nil
					}

					let content = storage.string
					return Self.locationToPoint(location, in: content)
				}
			)

			self.highlighter = try TextViewHighlighter(textView: textView, configuration: config)
			Log.treeSitter.info("Highlighter created for \(language.rawValue)")
		} catch {
			Log.treeSitter.error("Failed to create highlighter: \(error)")
			highlighter = nil
		}
	}

	/// Update the theme for highlighting
	func updateTheme(_ theme: Theme) {
		self.theme = theme
		highlighter?.invalidate(.all)
	}

	/// Invalidate all highlighting (call after major text changes)
	func invalidate() {
		highlighter?.invalidate(.all)
	}

	// MARK: - Language Configuration

	private func makeLanguageConfiguration(for language: Language) -> LanguageConfiguration? {
		switch language {
		case .javascript:
			return makeJavaScriptConfiguration()
		case .typescript:
			return makeTypeScriptConfiguration()
		case .swift:
			return makeSwiftConfiguration()
		case .json:
			return makeJSONConfiguration()
		default:
			return nil
		}
	}

	private func makeJavaScriptConfiguration() -> LanguageConfiguration? {
		// Use TypeScript parser for JavaScript (TypeScript is a superset of JS)
		// tree-sitter-javascript has broken SPM, and TypeScript's queries are minimal
		// So we create a comprehensive query covering common JS/TS syntax
		let tsLanguage = SwiftTreeSitter.Language(language: tree_sitter_typescript())

		do {
			let highlightsQuery = try Query(language: tsLanguage, data: Self.jstsHighlightsQuery.data(using: .utf8)!)
			let config = LanguageConfiguration(tsLanguage, name: "TypeScript", queries: [.highlights: highlightsQuery])
			Log.treeSitter.debug("JS/TS config created with custom highlights query")
			return config
		} catch {
			Log.treeSitter.error("Failed to create JS/TS config: \(error)")
			return LanguageConfiguration(tsLanguage, name: "TypeScript", queries: [:])
		}
	}

	/// Comprehensive highlights query for JavaScript/TypeScript
	private static let jstsHighlightsQuery = """
; Comments
(comment) @comment

; Strings
(string) @string
(template_string) @string
(template_substitution) @punctuation.special
(regex) @string.regex
(escape_sequence) @string.escape

; Numbers
(number) @number

; Booleans
(true) @constant.builtin
(false) @constant.builtin
(null) @constant.builtin
(undefined) @constant.builtin

; Variables and properties
(identifier) @variable
(property_identifier) @property
(shorthand_property_identifier) @property
(shorthand_property_identifier_pattern) @property
(this) @variable.builtin
(super) @variable.builtin

; Functions
(function_declaration name: (identifier) @function)
(function_expression name: (identifier) @function)
(method_definition name: (property_identifier) @function.method)
(call_expression function: (identifier) @function.call)
(call_expression function: (member_expression property: (property_identifier) @function.method))
(arrow_function) @function
(new_expression constructor: (identifier) @constructor)

; Classes and types
(class_declaration name: (type_identifier) @type)
(interface_declaration name: (type_identifier) @type)
(type_alias_declaration name: (type_identifier) @type)
(type_identifier) @type
(predefined_type) @type.builtin

; Keywords
[
  "async"
  "await"
  "break"
  "case"
  "catch"
  "class"
  "const"
  "continue"
  "debugger"
  "default"
  "delete"
  "do"
  "else"
  "export"
  "extends"
  "finally"
  "for"
  "from"
  "function"
  "get"
  "if"
  "import"
  "in"
  "instanceof"
  "let"
  "new"
  "of"
  "return"
  "set"
  "static"
  "switch"
  "throw"
  "try"
  "typeof"
  "var"
  "void"
  "while"
  "with"
  "yield"
] @keyword

; TypeScript-specific keywords
[
  "abstract"
  "as"
  "declare"
  "enum"
  "implements"
  "interface"
  "namespace"
  "private"
  "protected"
  "public"
  "readonly"
  "type"
  "override"
  "satisfies"
] @keyword

; Operators
[
  "+"
  "-"
  "*"
  "/"
  "%"
  "**"
  "="
  "+="
  "-="
  "*="
  "/="
  "%="
  "**="
  "=="
  "==="
  "!="
  "!=="
  "<"
  "<="
  ">"
  ">="
  "&&"
  "||"
  "!"
  "?"
  ":"
  "??"
  "?."
  "=>"
  "..."
  "++"
  "--"
  "&"
  "|"
  "^"
  "~"
  "<<"
  ">>"
  ">>>"
  "&="
  "|="
  "^="
  "<<="
  ">>="
  ">>>="
] @operator

; Punctuation
["(" ")" "[" "]" "{" "}"] @punctuation.bracket
["." "," ";" ":"] @punctuation.delimiter
"""

	private func makeTypeScriptConfiguration() -> LanguageConfiguration? {
		// Use same comprehensive query as JavaScript
		return makeJavaScriptConfiguration()
	}

	private func makeSwiftConfiguration() -> LanguageConfiguration? {
		do {
			let tsLanguage = SwiftTreeSitter.Language(language: tree_sitter_swift())
			return try LanguageConfiguration(tsLanguage, name: "Swift")
		} catch {
			Log.treeSitter.error("Failed to create Swift config: \(error)")
			let tsLanguage = SwiftTreeSitter.Language(language: tree_sitter_swift())
			return LanguageConfiguration(tsLanguage, name: "Swift", queries: [:])
		}
	}

	private func makeJSONConfiguration() -> LanguageConfiguration? {
		do {
			let tsLanguage = SwiftTreeSitter.Language(language: tree_sitter_json())
			return try LanguageConfiguration(tsLanguage, name: "JSON")
		} catch {
			Log.treeSitter.error("Failed to create JSON config: \(error)")
			let tsLanguage = SwiftTreeSitter.Language(language: tree_sitter_json())
			return LanguageConfiguration(tsLanguage, name: "JSON", queries: [:])
		}
	}

	// MARK: - Token Styling

	private func attributes(for token: Token) -> [NSAttributedString.Key: Any] {
		let color = colorForTokenName(token.name)
		return [.foregroundColor: color]
	}

	private func colorForTokenName(_ name: String) -> NSColor {
		// Map tree-sitter capture names to theme colors
		switch name {
		// Keywords
		case "keyword":
			return NSColor(theme.syntaxKeyword)

		// Strings
		case "string", "string.regex", "string.escape":
			return NSColor(theme.syntaxString)

		// Comments
		case "comment":
			return NSColor(theme.syntaxComment)

		// Functions
		case "function", "function.call", "function.method", "constructor":
			return NSColor(theme.syntaxFunction)

		// Types
		case "type", "type.builtin":
			return NSColor(theme.syntaxType)

		// Variables - use foreground color for readability
		case "variable":
			return theme.nsForegroundColor

		// Variable builtins (this, super)
		case "variable.builtin":
			return NSColor(theme.syntaxKeyword)

		// Properties
		case "property":
			return NSColor(theme.syntaxVariable)

		// Numbers
		case "number":
			return NSColor(theme.syntaxNumber)

		// Constants (true, false, null, undefined)
		case "constant.builtin":
			return NSColor(theme.syntaxConstant)

		// Operators - subtle color
		case "operator":
			return NSColor(theme.syntaxOperator)

		// Punctuation - use foreground
		case "punctuation.bracket", "punctuation.delimiter", "punctuation.special":
			return theme.nsForegroundColor

		// Default to foreground
		default:
			return theme.nsForegroundColor
		}
	}

	// MARK: - Location Transformation

	/// Convert a UTF-16 code unit offset to a tree-sitter Point (row, column)
	private static func locationToPoint(_ location: Int, in content: String) -> Point? {
		guard location >= 0 && location <= (content as NSString).length else {
			return nil
		}

		var row = 0
		var column = 0
		var currentOffset = 0

		for char in content {
			let charLength = (String(char) as NSString).length

			if currentOffset + charLength > location {
				column = location - currentOffset
				break
			}

			if char == "\n" {
				row += 1
				column = 0
			} else {
				column += charLength
			}

			currentOffset += charLength
		}

		return Point(row: UInt32(row), column: UInt32(column))
	}
}
