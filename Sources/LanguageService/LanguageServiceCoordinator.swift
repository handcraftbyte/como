import Foundation
import Combine

/// Active language service type
private enum ActiveService {
    case none
    case typescript
    case json
}

/// Coordinates language services for a document
/// Handles debouncing, caching, and UI updates
@MainActor
final class LanguageServiceCoordinator: ObservableObject {
    private let tsService = TypeScriptService()
    private let jsonService = JSONLanguageService()
    private var updateTask: Task<Void, Never>?
    private var diagnosticsDebounceTask: Task<Void, Never>?

    @Published private(set) var completions: [CompletionItem] = []
    @Published private(set) var diagnostics: [Diagnostic] = []
    @Published private(set) var isServiceReady = false

    private let diagnosticsDebounceInterval: TimeInterval = Constants.LanguageService.diagnosticsDebounceInterval
    private var fileName: String = "/untitled.ts"
    private var lastContent: String = ""
    private var activeService: ActiveService = .none

    /// Configure service for a language and file
    func configure(for language: Language, fileName: String?) async {
        // Determine which service to use
        switch language {
        case .javascript, .typescript:
            activeService = .typescript
            let ext = language == .typescript ? "ts" : "js"
            self.fileName = fileName.map { "/" + $0 } ?? "/untitled.\(ext)"

            do {
                try await tsService.initialize()
                isServiceReady = await tsService.ready
            } catch {
                Log.languageService.error("Failed to initialize TypeScript service: \(error)")
                isServiceReady = false
            }

        case .json:
            activeService = .json
            self.fileName = fileName.map { "/" + $0 } ?? "/untitled.json"

            do {
                try await jsonService.initialize()
                isServiceReady = await jsonService.ready
            } catch {
                Log.languageService.error("Failed to initialize JSON service: \(error)")
                isServiceReady = false
            }

        default:
            activeService = .none
            isServiceReady = false
        }
    }

    /// Called when text changes - updates file and debounces diagnostics
    func textDidChange(_ content: String) {
        guard activeService != .none, isServiceReady else { return }

        lastContent = content

        // Cancel previous tasks
        updateTask?.cancel()
        diagnosticsDebounceTask?.cancel()

        // Immediate file update (needed for fresh completions)
        updateTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                switch self.activeService {
                case .typescript:
                    try await self.tsService.updateFile(name: self.fileName, content: content)
                case .json:
                    try await self.jsonService.updateFile(name: self.fileName, content: content)
                case .none:
                    break
                }
            } catch {
                Log.languageService.error("Failed to update file: \(error)")
            }
        }

        // Debounced diagnostics
        diagnosticsDebounceTask = Task { [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: UInt64(self.diagnosticsDebounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self.refreshDiagnostics()
        }
    }

    /// Request completions at cursor position
    func requestCompletions(at position: Int) async {
        guard activeService != .none, isServiceReady else {
            completions = []
            return
        }

        do {
            let items: [CompletionItem]
            switch activeService {
            case .typescript:
                items = try await tsService.getCompletions(fileName: fileName, position: position)
            case .json:
                items = try await jsonService.getCompletions(fileName: fileName, position: position)
            case .none:
                items = []
            }
            // Sort by sortText, prioritize recommended items
            self.completions = items.sorted { lhs, rhs in
                if lhs.isRecommended != rhs.isRecommended {
                    return lhs.isRecommended
                }
                return lhs.sortText < rhs.sortText
            }
        } catch {
            Log.languageService.error("Failed to get completions: \(error)")
            completions = []
        }
    }

    /// Request quick info (hover) at position
    func requestQuickInfo(at position: Int) async -> QuickInfo? {
        guard activeService != .none, isServiceReady else { return nil }

        do {
            switch activeService {
            case .typescript:
                return try await tsService.getQuickInfo(fileName: fileName, position: position)
            case .json:
                // JSON service returns simple string hover
                if let text = try await jsonService.getHover(fileName: fileName, position: position) {
                    return QuickInfo(kind: nil, displayString: text, documentation: nil)
                }
                return nil
            case .none:
                return nil
            }
        } catch {
            Log.languageService.error("Failed to get quick info: \(error)")
            return nil
        }
    }

    /// Request definition at position
    func requestDefinition(at position: Int) async -> [DefinitionLocation] {
        guard activeService == .typescript, isServiceReady else { return [] }

        do {
            return try await tsService.getDefinition(fileName: fileName, position: position)
        } catch {
            Log.languageService.error("Failed to get definition: \(error)")
            return []
        }
    }

    /// Refresh diagnostics immediately
    func refreshDiagnostics() async {
        guard activeService != .none, isServiceReady else {
            diagnostics = []
            return
        }

        do {
            let diags: [Diagnostic]
            switch activeService {
            case .typescript:
                diags = try await tsService.getDiagnostics(fileName: fileName)
            case .json:
                diags = try await jsonService.getDiagnostics(fileName: fileName)
            case .none:
                diags = []
            }
            self.diagnostics = diags
        } catch {
            Log.languageService.error("Failed to get diagnostics: \(error)")
        }
    }

    /// Clear all state
    func clear() {
        updateTask?.cancel()
        diagnosticsDebounceTask?.cancel()
        completions = []
        diagnostics = []
        lastContent = ""
    }

    /// Get diagnostic counts by severity
    var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }
}
