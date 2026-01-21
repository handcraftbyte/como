import Foundation
import JavaScriptCore

/// Actor-based TypeScript language service using JavaScriptCore
/// Runs the TypeScript compiler and language service entirely in-process
actor TypeScriptService {
    private var context: JSContext?
    private var bridge: JSValue?
    private var isInitialized = false

    private typealias ServiceError = JSLanguageServiceError

    /// Initialize the JSContext and load TypeScript
    func initialize() async throws {
        guard !isInitialized else { return }

        // Create JSContext
        guard let ctx = JSContext() else {
            throw ServiceError.contextCreationFailed
        }

        // Set up error handler
        ctx.exceptionHandler = { _, exception in
            if let error = exception?.toString() {
                Log.jsBridge.error("TypeScript JSC error: \(error)")
            }
        }

        // Use Bundle.module for SPM resources
        let resourceBundle = Bundle.module

        // Load TypeScript compiler
        guard let tsURL = resourceBundle.url(forResource: "typescript", withExtension: "js"),
              let tsScript = try? String(contentsOf: tsURL, encoding: .utf8) else {
            Log.languageService.error("Failed to load typescript.js from bundle: \(resourceBundle.bundlePath)")
            throw ServiceError.scriptLoadFailed("typescript.js")
        }

        Log.languageService.info("Loading TypeScript compiler (\(tsScript.count) bytes)...")
        ctx.evaluateScript(tsScript)

        // Load bridge script
        guard let bridgeURL = resourceBundle.url(forResource: "tsbridge", withExtension: "js"),
              let bridgeScript = try? String(contentsOf: bridgeURL, encoding: .utf8) else {
            throw ServiceError.scriptLoadFailed("tsbridge.js")
        }

        ctx.evaluateScript(bridgeScript)

        // Get bridge object
        guard let tsBridge = ctx.objectForKeyedSubscript("TSBridge"),
              !tsBridge.isUndefined else {
            throw ServiceError.bridgeNotAvailable
        }

        // Load lib.d.ts for type definitions
        if let libURL = resourceBundle.url(forResource: "lib.es2015", withExtension: "d.ts"),
           let libContent = try? String(contentsOf: libURL, encoding: .utf8) {
            tsBridge.invokeMethod("setLibContent", withArguments: [libContent])
            Log.languageService.debug("Loaded lib.d.ts (\(libContent.count) bytes)")
        }

        // Verify service is ready
        if let isReady = tsBridge.invokeMethod("isReady", withArguments: []),
           isReady.toBool() {
            if let version = tsBridge.invokeMethod("getVersion", withArguments: [])?.toString() {
                Log.languageService.info("TypeScript service initialized (v\(version))")
            }
        }

        self.context = ctx
        self.bridge = tsBridge
        self.isInitialized = true
    }

    /// Update file content in the virtual file system
    func updateFile(name: String, content: String) throws {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }
        bridge.invokeMethod("updateFile", withArguments: [name, content])
    }

    /// Remove a file from the virtual file system
    func removeFile(name: String) throws {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }
        bridge.invokeMethod("removeFile", withArguments: [name])
    }

    /// Get completions at position
    func getCompletions(fileName: String, position: Int) throws -> [CompletionItem] {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }

        let result = bridge.invokeMethod("getCompletions", withArguments: [fileName, position])

        guard let array = result?.toArray() as? [[String: Any]] else {
            return []
        }

        return array.compactMap { dict -> CompletionItem? in
            guard let name = dict["name"] as? String,
                  let kind = dict["kind"] as? String else {
                return nil
            }

            return CompletionItem(
                label: name,
                kind: CompletionKind(tsKind: kind),
                sortText: dict["sortText"] as? String,
                insertText: dict["insertText"] as? String,
                isRecommended: dict["isRecommended"] as? Bool ?? false
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
                  let message = dict["message"] as? String,
                  let category = dict["category"] as? Int else {
                return nil
            }

            return Diagnostic(
                start: start,
                length: length,
                message: message,
                category: category,
                code: dict["code"] as? Int
            )
        }
    }

    /// Get quick info (hover) at position
    func getQuickInfo(fileName: String, position: Int) throws -> QuickInfo? {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }

        let result = bridge.invokeMethod("getQuickInfo", withArguments: [fileName, position])

        guard let dict = result?.toDictionary() as? [String: Any],
              let displayString = dict["displayString"] as? String else {
            return nil
        }

        return QuickInfo(
            kind: dict["kind"] as? String,
            displayString: displayString,
            documentation: dict["documentation"] as? String
        )
    }

    /// Get definition location
    func getDefinition(fileName: String, position: Int) throws -> [DefinitionLocation] {
        guard let bridge = bridge else { throw ServiceError.bridgeNotAvailable }

        let result = bridge.invokeMethod("getDefinition", withArguments: [fileName, position])

        guard let array = result?.toArray() as? [[String: Any]] else {
            return []
        }

        return array.compactMap { dict -> DefinitionLocation? in
            guard let fileName = dict["fileName"] as? String,
                  let start = dict["start"] as? Int,
                  let length = dict["length"] as? Int else {
                return nil
            }

            return DefinitionLocation(
                fileName: fileName,
                start: start,
                length: length
            )
        }
    }

    /// Check if service is initialized
    var ready: Bool {
        isInitialized
    }
}

/// Quick info result from hover
struct QuickInfo {
    let kind: String?
    let displayString: String
    let documentation: String?
}

/// Definition location result
struct DefinitionLocation {
    let fileName: String
    let start: Int
    let length: Int
}
