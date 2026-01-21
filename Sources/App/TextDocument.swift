import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument {
	var text: String
	var language: Language

	static var readableContentTypes: [UTType] {
		[
			.plainText,
			.sourceCode,
			.swiftSource,
			.json,
			.html,
			.xml,
			.yaml,
			.init(filenameExtension: "md")!,
			.init(filenameExtension: "py")!,
			.init(filenameExtension: "rb")!,
			.init(filenameExtension: "rs")!,
			.init(filenameExtension: "go")!,
			.init(filenameExtension: "js")!,
			.init(filenameExtension: "ts")!,
			.init(filenameExtension: "tsx")!,
			.init(filenameExtension: "jsx")!,
			.init(filenameExtension: "css")!,
			.init(filenameExtension: "sh")!,
			.init(filenameExtension: "bash")!,
			.init(filenameExtension: "c")!,
			.init(filenameExtension: "h")!,
			.init(filenameExtension: "cpp")!,
			.init(filenameExtension: "hpp")!,
		].compactMap { $0 }
	}

	init(text: String = "", language: Language = .plainText) {
		self.text = text
		self.language = language
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents,
			  let string = String(data: data, encoding: .utf8) else {
			throw CocoaError(.fileReadCorruptFile)
		}
		self.text = string
		self.language = Language.detect(from: configuration.file.filename ?? "", content: string)
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = text.data(using: .utf8)!
		return .init(regularFileWithContents: data)
	}
}

enum Language: String, CaseIterable, Identifiable {
	case plainText = "Plain Text"
	case swift = "Swift"
	case python = "Python"
	case ruby = "Ruby"
	case rust = "Rust"
	case go = "Go"
	case javascript = "JavaScript"
	case typescript = "TypeScript"
	case json = "JSON"
	case html = "HTML"
	case css = "CSS"
	case markdown = "Markdown"
	case bash = "Bash"
	case c = "C"
	case cpp = "C++"

	var id: String { rawValue }

	var fileExtensions: [String] {
		switch self {
		case .plainText: return ["txt"]
		case .swift: return ["swift"]
		case .python: return ["py", "pyw"]
		case .ruby: return ["rb", "rake", "gemspec"]
		case .rust: return ["rs"]
		case .go: return ["go"]
		case .javascript: return ["js", "jsx", "mjs"]
		case .typescript: return ["ts", "tsx"]
		case .json: return ["json", "jsonc"]
		case .html: return ["html", "htm"]
		case .css: return ["css", "scss", "sass"]
		case .markdown: return ["md", "markdown"]
		case .bash: return ["sh", "bash", "zsh"]
		case .c: return ["c", "h"]
		case .cpp: return ["cpp", "hpp", "cc", "hh", "cxx"]
		}
	}

	static func detect(from filename: String, content: String) -> Language {
		let ext = (filename as NSString).pathExtension.lowercased()

		for language in Language.allCases {
			if language.fileExtensions.contains(ext) {
				return language
			}
		}

		// Check shebang
		if content.hasPrefix("#!") {
			let firstLine = content.prefix(while: { $0 != "\n" })
			if firstLine.contains("python") { return .python }
			if firstLine.contains("ruby") { return .ruby }
			if firstLine.contains("node") { return .javascript }
			if firstLine.contains("bash") || firstLine.contains("sh") { return .bash }
		}

		return .plainText
	}
}
