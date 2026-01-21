import Foundation
import os.log

/// Centralized logging for Como using Apple's unified logging system
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.como.editor"

    /// Logger for editor-related events
    static let editor = Logger(subsystem: subsystem, category: "Editor")

    /// Logger for language service events
    static let languageService = Logger(subsystem: subsystem, category: "LanguageService")

    /// Logger for Tree-sitter highlighting
    static let treeSitter = Logger(subsystem: subsystem, category: "TreeSitter")

    /// Logger for JavaScript bridge (TypeScript/JSON services)
    static let jsBridge = Logger(subsystem: subsystem, category: "JSBridge")
}
