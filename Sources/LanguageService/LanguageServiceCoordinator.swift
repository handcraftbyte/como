import Foundation
import Combine

/// Coordinates language services for a document
/// Currently a stub - connect external LSP servers for language intelligence
@MainActor
final class LanguageServiceCoordinator: ObservableObject {
    @Published private(set) var completions: [CompletionItem] = []
    @Published private(set) var diagnostics: [Diagnostic] = []
    @Published private(set) var isServiceReady = false

    /// Configure service for a language and file
    func configure(for language: Language, fileName: String?) async {
        // External LSP connection would be configured here
        isServiceReady = false
    }

    /// Called when text changes
    func textDidChange(_ content: String) {
        // Would forward to external LSP
    }

    /// Request completions at cursor position
    func requestCompletions(at position: Int) async {
        // Would request from external LSP
        completions = []
    }

    /// Request quick info (hover) at position
    func requestQuickInfo(at position: Int) async -> QuickInfo? {
        // Would request from external LSP
        return nil
    }

    /// Request definition at position
    func requestDefinition(at position: Int) async -> [DefinitionLocation] {
        // Would request from external LSP
        return []
    }

    /// Clear all state
    func clear() {
        completions = []
        diagnostics = []
    }

    var errorCount: Int { 0 }
    var warningCount: Int { 0 }
}

/// Quick info from hover
struct QuickInfo {
    let kind: String?
    let displayString: String
    let documentation: String?
}

/// Definition location for go-to-definition
struct DefinitionLocation {
    let fileName: String
    let start: Int
    let length: Int
}
