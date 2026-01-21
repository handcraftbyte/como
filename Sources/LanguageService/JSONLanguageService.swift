import Foundation
import JavaScriptCore

/// Actor-based JSON language service using JavaScriptCore
/// Uses vscode-json-languageservice for completions and validation
actor JSONLanguageService {
    private var context: JSContext?
    private var bridge: JSValue?
    private var isInitialized = false

    private typealias ServiceError = JSLanguageServiceError

    /// Initialize the JSContext and load JSON language service
    func initialize() async throws {
        guard !isInitialized else { return }

        // Create JSContext
        guard let ctx = JSContext() else {
            throw ServiceError.contextCreationFailed
        }

        // Set up error handler
        ctx.exceptionHandler = { _, exception in
            if let error = exception?.toString() {
                Log.jsBridge.error("JSON JSC error: \(error)")
            }
        }

        // Set up console.log handler
        let consoleLog: @convention(block) (String) -> Void = { message in
            Log.jsBridge.debug("\(message)")
        }
        ctx.setObject(consoleLog, forKeyedSubscript: "nativeLog" as NSString)
        ctx.evaluateScript("console = { log: function() { nativeLog(Array.from(arguments).join(' ')); } };")

        // Use Bundle.module for SPM resources
        let resourceBundle = Bundle.module

        // Load JSON language service bundle
        guard let jsonURL = resourceBundle.url(forResource: "json-languageservice", withExtension: "js"),
              let jsonScript = try? String(contentsOf: jsonURL, encoding: .utf8) else {
            Log.languageService.error("Failed to load json-languageservice.js from bundle: \(resourceBundle.bundlePath)")
            throw ServiceError.scriptLoadFailed("json-languageservice.js")
        }

        Log.languageService.info("Loading JSON language service (\(jsonScript.count) bytes)...")
        ctx.evaluateScript(jsonScript)

        // Get bridge object
        guard let jsonBridge = ctx.objectForKeyedSubscript("JSONBridge"),
              !jsonBridge.isUndefined else {
            throw ServiceError.bridgeNotAvailable
        }

        Log.languageService.info("JSON language service initialized")

        self.context = ctx
        self.bridge = jsonBridge
        self.isInitialized = true
    }

    /// Update file content in the virtual file system
    func updateFile(name: String, content: String) throws {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }
        bridge.invokeMethod("updateFile", withArguments: [name, content])
    }

    /// Get completions at position
    func getCompletions(fileName: String, position: Int) throws -> [CompletionItem] {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }

        let result = bridge.invokeMethod("getCompletions", withArguments: [fileName, position])

        guard let array = result?.toArray() as? [[String: Any]] else {
            return []
        }

        return array.compactMap { dict -> CompletionItem? in
            guard let label = dict["label"] as? String else {
                return nil
            }

            let kindNum = dict["kind"] as? Int ?? 1
            return CompletionItem(
                label: label,
                kind: CompletionKind(lspKind: kindNum),
                sortText: dict["sortText"] as? String,
                insertText: dict["insertText"] as? String,
                isRecommended: false
            )
        }
    }

    /// Get diagnostics for file
    func getDiagnostics(fileName: String) throws -> [Diagnostic] {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }

        let result = bridge.invokeMethod("getDiagnostics", withArguments: [fileName])

        guard let array = result?.toArray() as? [[String: Any]] else {
            return []
        }

        return array.compactMap { dict -> Diagnostic? in
            guard let start = dict["start"] as? Int,
                  let length = dict["length"] as? Int,
                  let message = dict["message"] as? String else {
                return nil
            }

            let severity = dict["severity"] as? Int ?? 1

            return Diagnostic(
                start: start,
                length: length,
                message: message,
                category: severity,
                code: nil
            )
        }
    }

    /// Get hover info at position
    func getHover(fileName: String, position: Int) throws -> String? {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }

        let result = bridge.invokeMethod("getHover", withArguments: [fileName, position])

        guard let dict = result?.toDictionary() as? [String: Any],
              let text = dict["text"] as? String,
              !text.isEmpty else {
            return nil
        }

        return text
    }

    /// Check if service is initialized
    var ready: Bool {
        isInitialized
    }
}

extension CompletionKind {
    /// Initialize from LSP completion item kind number
    init(lspKind: Int) {
        // Map LSP completion kinds to our existing CompletionKind
        switch lspKind {
        case 2: self = .method        // LSP Method
        case 3: self = .function      // LSP Function
        case 5: self = .property      // LSP Field
        case 6: self = .variable      // LSP Variable
        case 7: self = .classKind     // LSP Class
        case 8: self = .interface     // LSP Interface
        case 9: self = .module        // LSP Module
        case 10: self = .property     // LSP Property
        case 13: self = .enum         // LSP Enum
        case 14: self = .keyword      // LSP Keyword
        case 20: self = .enumMember   // LSP EnumMember
        default: self = .unknown      // All others map to unknown
        }
    }
}
