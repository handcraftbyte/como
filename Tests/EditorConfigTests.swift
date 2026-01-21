import XCTest
@testable import TemperEdit

final class EditorConfigTests: XCTestCase {
	func testParseBasicConfig() {
		let content = """
		root = true

		[*]
		indent_style = tab
		indent_size = 4
		end_of_line = lf
		charset = utf-8
		trim_trailing_whitespace = true
		insert_final_newline = true
		"""

		let config = EditorConfigParser.parse(content: content)

		XCTAssertEqual(config.indentStyle, .tab)
		XCTAssertEqual(config.indentSize, 4)
		XCTAssertEqual(config.endOfLine, .lf)
		XCTAssertEqual(config.charset, .utf8)
		XCTAssertTrue(config.trimTrailingWhitespace)
		XCTAssertTrue(config.insertFinalNewline)
	}

	func testParseSpaceIndent() {
		let content = """
		[*.py]
		indent_style = space
		indent_size = 4
		"""

		let config = EditorConfigParser.parse(content: content)

		XCTAssertEqual(config.indentStyle, .space)
		XCTAssertEqual(config.indentSize, 4)
	}

	func testDefaultConfig() {
		let config = EditorConfig.default

		XCTAssertEqual(config.indentStyle, .tab)
		XCTAssertEqual(config.tabWidth, 4)
		XCTAssertEqual(config.endOfLine, .lf)
		XCTAssertEqual(config.charset, .utf8)
	}

	func testIndentString() {
		var config = EditorConfig.default

		config.indentStyle = .tab
		XCTAssertEqual(config.indentString, "\t")

		config.indentStyle = .space
		config.indentSize = 2
		XCTAssertEqual(config.indentString, "  ")
	}

	func testLineEnding() {
		var config = EditorConfig.default

		config.endOfLine = .lf
		XCTAssertEqual(config.lineEnding, "\n")

		config.endOfLine = .crlf
		XCTAssertEqual(config.lineEnding, "\r\n")

		config.endOfLine = .cr
		XCTAssertEqual(config.lineEnding, "\r")
	}
}
