import SwiftUI

/// Represents a single line of console output
struct ConsoleLine: Identifiable {
    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let segments: [ConsoleLineSegment]

    enum Kind {
        case input(command: String)
        case stdout
        case stderr
        case systemMessage
        case commandResult(success: Bool, exitCode: Int32?)
    }

    init(kind: Kind, segments: [ConsoleLineSegment], timestamp: Date = Date()) {
        self.kind = kind
        self.segments = segments
        self.timestamp = timestamp
    }

    /// Create a simple text line
    static func text(_ text: String, kind: Kind) -> ConsoleLine {
        ConsoleLine(kind: kind, segments: [.plain(text)])
    }

    /// Create an input echo line
    static func input(_ command: String) -> ConsoleLine {
        ConsoleLine(kind: .input(command: command), segments: [
            ConsoleLineSegment(text: "$ ", style: .prompt),
            ConsoleLineSegment(text: command, style: .command)
        ])
    }

    /// Create a system message line
    static func system(_ message: String) -> ConsoleLine {
        ConsoleLine(kind: .systemMessage, segments: [.plain(message)])
    }

    /// Create a result line (only shown for failures)
    static func result(success: Bool, exitCode: Int32? = nil) -> ConsoleLine? {
        // Only show message for failures
        guard !success else { return nil }
        let message = "Command failed with exit code \(exitCode ?? -1)"
        return ConsoleLine(
            kind: .commandResult(success: false, exitCode: exitCode),
            segments: [ConsoleLineSegment(text: message, style: .error)]
        )
    }
}

/// A segment of text within a console line
struct ConsoleLineSegment: Identifiable {
    let id = UUID()
    let text: String
    let style: Style
    let action: ClickAction?

    enum Style {
        case plain
        case prompt
        case command
        case path
        case error
        case warning
        case success
        case link
        case ansi(foreground: Color?, background: Color?, bold: Bool, italic: Bool)
    }

    enum ClickAction {
        case openFile(path: String, line: Int?, column: Int?)
        case openURL(URL)
        case copyText(String)
    }

    init(text: String, style: Style = .plain, action: ClickAction? = nil) {
        self.text = text
        self.style = style
        self.action = action
    }

    /// Create a plain text segment
    static func plain(_ text: String) -> ConsoleLineSegment {
        ConsoleLineSegment(text: text, style: .plain)
    }

    /// Create a clickable path segment
    static func path(_ path: String, line: Int? = nil, column: Int? = nil) -> ConsoleLineSegment {
        var displayText = path
        if let line = line {
            displayText += ":\(line)"
            if let column = column {
                displayText += ":\(column)"
            }
        }
        return ConsoleLineSegment(
            text: displayText,
            style: .path,
            action: .openFile(path: path, line: line, column: column)
        )
    }
}

/// Console input mode determines how input is parsed
enum ConsoleInputMode: Equatable {
    case shell          // Execute as shell command
    case editorCommand  // Built-in editor command (starts with :)
    case quickOpen      // Fuzzy file search
    case symbolSearch   // Symbol navigation (starts with @)
    case lineNavigation // Go to line (starts with : followed by number)

    var placeholder: String {
        switch self {
        case .shell: return "Enter command..."
        case .editorCommand: return "Enter editor command..."
        case .quickOpen: return "Search files..."
        case .symbolSearch: return "Search symbols..."
        case .lineNavigation: return "Go to line..."
        }
    }

    var icon: String {
        switch self {
        case .shell: return "terminal"
        case .editorCommand: return "command"
        case .quickOpen: return "doc.text.magnifyingglass"
        case .symbolSearch: return "at"
        case .lineNavigation: return "number"
        }
    }
}
