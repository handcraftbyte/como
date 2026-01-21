import SwiftUI
import UniformTypeIdentifiers

/// Represents a single tab in the editor
struct TabDocument: Identifiable, Equatable {
    let id: UUID
    var fileURL: URL?
    var text: String
    var language: Language
    var isDirty: Bool
    var cursorPosition: CursorPosition

    /// Display name for the tab (filename or "Untitled")
    var displayName: String {
        if let url = fileURL {
            return url.lastPathComponent
        }
        return "Untitled"
    }

    /// Title with dirty indicator
    var tabTitle: String {
        isDirty ? "\(displayName) •" : displayName
    }

    init(
        id: UUID = UUID(),
        fileURL: URL? = nil,
        text: String = "",
        language: Language = .plainText,
        isDirty: Bool = false,
        cursorPosition: CursorPosition = CursorPosition(line: 1, column: 1)
    ) {
        self.id = id
        self.fileURL = fileURL
        self.text = text
        self.language = language
        self.isDirty = isDirty
        self.cursorPosition = cursorPosition
    }

    /// Create a new empty tab
    static func newUntitled() -> TabDocument {
        TabDocument()
    }

    /// Load a tab from a file URL
    static func load(from url: URL) throws -> TabDocument {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let language = Language.detect(from: url.lastPathComponent, content: text)

        return TabDocument(
            fileURL: url,
            text: text,
            language: language,
            isDirty: false
        )
    }

    /// Save the tab to its file URL (or throw if no URL)
    mutating func save() throws {
        guard let url = fileURL else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try save(to: url)
    }

    /// Save the tab to a specific URL
    mutating func save(to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: .atomic)
        fileURL = url
        isDirty = false
        // Update language based on new filename
        language = Language.detect(from: url.lastPathComponent, content: text)
    }

    static func == (lhs: TabDocument, rhs: TabDocument) -> Bool {
        lhs.id == rhs.id
    }
}
