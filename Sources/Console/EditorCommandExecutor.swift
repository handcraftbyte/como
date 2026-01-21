import Foundation
import AppKit

/// Navigation action for commands that move the cursor
enum NavigationAction {
    case line(Int)
    case offset(Int)
    case position(line: Int, column: Int)
}

/// Result of executing an editor command
enum EditorCommandResult {
    case success(String?)
    case failure(String)
    case navigation(NavigationAction, message: String?)
    case clearConsole
    case quit
}

/// Executes built-in editor commands
@MainActor
enum EditorCommandExecutor {
    /// Execute a command string
    static func execute(_ command: String, tabManager: TabManager?, workingDirectory: URL) -> EditorCommandResult {
        let parts = parseCommand(command)
        guard let commandName = parts.first?.lowercased() else {
            return .failure("Empty command")
        }

        let args = Array(parts.dropFirst())

        switch commandName {
        // File operations
        case "open", "o", "e":
            return executeOpen(args: args, tabManager: tabManager, workingDirectory: workingDirectory)

        case "save", "w":
            return executeSave(tabManager: tabManager)

        case "saveas", "wa":
            return executeSaveAs(args: args, tabManager: tabManager, workingDirectory: workingDirectory)

        case "new", "n":
            return executeNew(tabManager: tabManager)

        case "close", "c", "bd":
            return executeClose(tabManager: tabManager)

        case "quit", "q":
            return executeQuit(tabManager: tabManager)

        // Search operations
        case "search", "find", "f":
            return executeSearch(args: args, tabManager: tabManager)

        case "search-replace", "sr", "replace":
            return executeSearchReplace(args: args, tabManager: tabManager)

        // Navigation
        case "goto", "go", "g":
            return executeGoto(args: args, tabManager: tabManager)

        case "symbol", "@":
            return executeSymbol(args: args, tabManager: tabManager)

        // Settings
        case "theme":
            return executeTheme(args: args)

        case "set":
            return executeSet(args: args)

        // Utility
        case "help", "h", "?":
            return executeHelp(args: args)

        case "clear", "cls":
            return .clearConsole

        case "pwd":
            return .success(workingDirectory.path)

        default:
            return .failure("Unknown command: \(commandName). Type :help for available commands.")
        }
    }

    // MARK: - Command Parsing

    /// Parse command string into parts, respecting quotes
    private static func parseCommand(_ command: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false
        var quoteChar: Character = "\""

        for char in command {
            if !inQuote && (char == "\"" || char == "'") {
                inQuote = true
                quoteChar = char
            } else if inQuote && char == quoteChar {
                inQuote = false
            } else if !inQuote && char == " " {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    // MARK: - File Operations

    private static func executeOpen(args: [String], tabManager: TabManager?, workingDirectory: URL) -> EditorCommandResult {
        guard let path = args.first else {
            return .failure("Usage: :open <path>")
        }

        guard let tabManager = tabManager else {
            return .failure("No editor context available")
        }

        let url = resolvePath(path, workingDirectory: workingDirectory)

        do {
            try tabManager.openFile(at: url)
            return .success("Opened: \(url.lastPathComponent)")
        } catch {
            return .failure("Cannot open file: \(error.localizedDescription)")
        }
    }

    private static func executeSave(tabManager: TabManager?) -> EditorCommandResult {
        guard let tabManager = tabManager else {
            return .failure("No editor context available")
        }

        guard tabManager.tabs.indices.contains(tabManager.activeTabIndex) else {
            return .failure("No active tab")
        }

        let tab = tabManager.tabs[tabManager.activeTabIndex]

        guard tab.fileURL != nil else {
            return .failure("File has no path. Use :saveas <path>")
        }

        do {
            try tabManager.saveActiveTab()
            return .success("Saved: \(tab.fileURL?.lastPathComponent ?? "file")")
        } catch {
            return .failure("Cannot save: \(error.localizedDescription)")
        }
    }

    private static func executeSaveAs(args: [String], tabManager: TabManager?, workingDirectory: URL) -> EditorCommandResult {
        guard let path = args.first else {
            return .failure("Usage: :saveas <path>")
        }

        guard let tabManager = tabManager else {
            return .failure("No editor context available")
        }

        let url = resolvePath(path, workingDirectory: workingDirectory)

        do {
            try tabManager.saveActiveTabAs(to: url)
            return .success("Saved as: \(url.lastPathComponent)")
        } catch {
            return .failure("Cannot save: \(error.localizedDescription)")
        }
    }

    private static func executeNew(tabManager: TabManager?) -> EditorCommandResult {
        guard let tabManager = tabManager else {
            return .failure("No editor context available")
        }

        tabManager.createNewTab()
        return .success("Created new tab")
    }

    private static func executeClose(tabManager: TabManager?) -> EditorCommandResult {
        guard let tabManager = tabManager else {
            return .failure("No editor context available")
        }

        guard tabManager.tabs.indices.contains(tabManager.activeTabIndex) else {
            return .failure("No active tab")
        }

        let tab = tabManager.tabs[tabManager.activeTabIndex]

        if tab.isDirty {
            return .failure("Unsaved changes. Use :save first or :close! to force")
        }

        tabManager.closeActiveTab()
        return .success("Tab closed")
    }

    private static func executeQuit(tabManager: TabManager?) -> EditorCommandResult {
        if let tabManager = tabManager, tabManager.hasUnsavedChanges {
            return .failure("Unsaved changes exist. Save first or use :quit! to force")
        }

        return .quit
    }

    // MARK: - Path Resolution

    private static func resolvePath(_ path: String, workingDirectory: URL) -> URL {
        var targetPath = path

        // Handle ~ for home directory
        if targetPath.hasPrefix("~") {
            targetPath = targetPath.replacingOccurrences(
                of: "~",
                with: FileManager.default.homeDirectoryForCurrentUser.path
            )
        }

        // Handle absolute vs relative paths
        if targetPath.hasPrefix("/") {
            return URL(fileURLWithPath: targetPath).standardized
        } else {
            return workingDirectory.appendingPathComponent(targetPath).standardized
        }
    }

    // MARK: - Search Operations

    private static func executeSearch(args: [String], tabManager: TabManager?) -> EditorCommandResult {
        guard let pattern = args.first else {
            return .failure("Usage: :search \"pattern\"")
        }

        guard let tabManager = tabManager,
              tabManager.tabs.indices.contains(tabManager.activeTabIndex) else {
            return .failure("No active tab")
        }

        let text = tabManager.tabs[tabManager.activeTabIndex].text
        let lines = text.components(separatedBy: .newlines)
        var matches: [(line: Int, preview: String)] = []

        for (index, line) in lines.enumerated() {
            if line.localizedCaseInsensitiveContains(pattern) {
                let lineNum = index + 1
                let preview = line.trimmingCharacters(in: .whitespaces)
                let truncated = preview.count > 60 ? String(preview.prefix(60)) + "..." : preview
                matches.append((line: lineNum, preview: truncated))
            }
        }

        if matches.isEmpty {
            return .success("No matches found for: \(pattern)")
        }

        var result = "Found \(matches.count) match(es):\n"
        for (lineNum, preview) in matches.prefix(10) {
            result += "  Line \(lineNum): \(preview)\n"
        }
        if matches.count > 10 {
            result += "  ... and \(matches.count - 10) more"
        }

        return .success(result)
    }

    // MARK: - Search Replace

    private static func executeSearchReplace(args: [String], tabManager: TabManager?) -> EditorCommandResult {
        guard args.count >= 2 else {
            return .failure("Usage: :search-replace \"pattern\" \"replacement\" [<all>]")
        }

        let pattern = args[0]
        let replacement = args[1]
        let scope = args.count > 2 ? args[2] : ""

        guard let tabManager = tabManager else {
            return .failure("No editor context available")
        }

        if scope.lowercased() == "<all>" || scope.lowercased() == "all" {
            // Replace in all tabs
            var totalCount = 0
            for index in tabManager.tabs.indices {
                let count = replaceInText(&tabManager.tabs[index].text, pattern: pattern, replacement: replacement)
                if count > 0 {
                    tabManager.tabs[index].isDirty = true
                    totalCount += count
                }
            }
            return .success("Replaced \(totalCount) occurrence(s) across all tabs")
        } else {
            // Replace in current tab only
            guard tabManager.tabs.indices.contains(tabManager.activeTabIndex) else {
                return .failure("No active tab")
            }

            let count = replaceInText(&tabManager.tabs[tabManager.activeTabIndex].text, pattern: pattern, replacement: replacement)
            if count > 0 {
                tabManager.tabs[tabManager.activeTabIndex].isDirty = true
            }
            return .success("Replaced \(count) occurrence(s)")
        }
    }

    private static func replaceInText(_ text: inout String, pattern: String, replacement: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(of: pattern, options: [], range: searchRange) {
            text.replaceSubrange(range, with: replacement)
            count += 1

            // Update search range to start after the replacement
            let newStart = text.index(range.lowerBound, offsetBy: replacement.count, limitedBy: text.endIndex) ?? text.endIndex
            searchRange = newStart..<text.endIndex
        }

        return count
    }

    // MARK: - Navigation

    private static func executeGoto(args: [String], tabManager: TabManager?) -> EditorCommandResult {
        guard let lineStr = args.first, let line = Int(lineStr), line > 0 else {
            return .failure("Usage: :goto <line_number>")
        }

        guard let tabManager = tabManager,
              tabManager.tabs.indices.contains(tabManager.activeTabIndex) else {
            return .failure("No active tab")
        }

        // Validate line number is within range
        let text = tabManager.tabs[tabManager.activeTabIndex].text
        let lineCount = text.components(separatedBy: .newlines).count

        if line > lineCount {
            return .failure("Line \(line) out of range (1-\(lineCount))")
        }

        return .navigation(.line(line), message: "Line \(line)")
    }

    private static func executeSymbol(args: [String], tabManager: TabManager?) -> EditorCommandResult {
        guard let query = args.first else {
            return .failure("Usage: :symbol <name>")
        }

        guard let tabManager = tabManager,
              tabManager.tabs.indices.contains(tabManager.activeTabIndex) else {
            return .failure("No active tab")
        }

        let tab = tabManager.tabs[tabManager.activeTabIndex]
        let text = tab.text
        let lines = text.components(separatedBy: .newlines)

        // Simple symbol search - look for function/class/struct definitions
        var matches: [(line: Int, name: String, preview: String)] = []
        let searchQuery = query.lowercased()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNum = index + 1

            // Match function/class/struct definitions
            if trimmed.localizedCaseInsensitiveContains(searchQuery) {
                // Check if it looks like a symbol definition
                if trimmed.hasPrefix("func ") ||
                   trimmed.hasPrefix("class ") ||
                   trimmed.hasPrefix("struct ") ||
                   trimmed.hasPrefix("enum ") ||
                   trimmed.hasPrefix("protocol ") ||
                   trimmed.hasPrefix("extension ") ||
                   trimmed.hasPrefix("def ") ||
                   trimmed.hasPrefix("function ") ||
                   trimmed.hasPrefix("const ") ||
                   trimmed.hasPrefix("let ") ||
                   trimmed.hasPrefix("var ") {
                    let preview = trimmed.count > 50 ? String(trimmed.prefix(50)) + "..." : trimmed
                    matches.append((line: lineNum, name: extractSymbolName(from: trimmed), preview: preview))
                }
            }
        }

        if matches.isEmpty {
            return .failure("No symbol found: \(query)")
        }

        if matches.count == 1 {
            return .navigation(.line(matches[0].line), message: "→ \(matches[0].name)")
        }

        // Multiple matches - show list and go to first
        var result = "Found \(matches.count) symbols:\n"
        for (lineNum, name, _) in matches.prefix(5) {
            result += "  Line \(lineNum): \(name)\n"
        }
        if matches.count > 5 {
            result += "  ... and \(matches.count - 5) more"
        }

        // Navigate to first match
        return .navigation(.line(matches[0].line), message: result)
    }

    private static func extractSymbolName(from line: String) -> String {
        // Extract symbol name from definition line
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "(" || $0 == ":" || $0 == "{" })
        if parts.count >= 2 {
            return String(parts[1])
        }
        return line
    }

    // MARK: - Theme

    private static func executeTheme(args: [String]) -> EditorCommandResult {
        guard let themeName = args.first else {
            // List available themes
            let themes = Theme.allCases.map { $0.rawValue }.joined(separator: ", ")
            return .success("Available themes: \(themes)")
        }

        let normalizedName = themeName.lowercased()

        for theme in Theme.allCases {
            if theme.rawValue.lowercased() == normalizedName ||
               theme.displayName.lowercased() == normalizedName {
                ThemeManager.shared.currentTheme = theme
                return .success("Theme set to \(theme.displayName)")
            }
        }

        return .failure("Unknown theme: \(themeName). Type :theme for available themes.")
    }

    // MARK: - Set

    private static func executeSet(args: [String]) -> EditorCommandResult {
        guard args.count >= 2 else {
            return .failure("Usage: :set <setting> <value>\nBoolean: wrap, ln, hl, spaces\nNumeric: fontsize, tabwidth, lineheight")
        }

        let setting = args[0].lowercased()
        let value = args[1].lowercased()

        let boolValue = value == "true" || value == "1" || value == "on" || value == "yes"

        switch setting {
        // Boolean settings
        case "wordwrap", "wrap":
            EditorSettings.shared.wordWrap = boolValue
            return .success("Word wrap \(boolValue ? "enabled" : "disabled")")

        case "linenumbers", "lines", "ln":
            EditorSettings.shared.showLineNumbers = boolValue
            return .success("Line numbers \(boolValue ? "shown" : "hidden")")

        case "highlightline", "highlight", "hl":
            EditorSettings.shared.highlightCurrentLine = boolValue
            return .success("Current line highlight \(boolValue ? "enabled" : "disabled")")

        case "usespaces", "spaces":
            EditorSettings.shared.useSpacesForTabs = boolValue
            return .success("Using \(boolValue ? "spaces" : "tabs") for indentation")

        // Numeric settings
        case "fontsize", "fs", "font":
            guard let size = Double(args[1]), size >= 8, size <= 72 else {
                return .failure("Font size must be between 8 and 72")
            }
            EditorSettings.shared.fontSize = size
            return .success("Font size set to \(Int(size))")

        case "tabwidth", "tw", "tab":
            guard let width = Int(args[1]), width >= 1, width <= 16 else {
                return .failure("Tab width must be between 1 and 16")
            }
            EditorSettings.shared.tabWidth = width
            return .success("Tab width set to \(width)")

        case "lineheight", "lh":
            guard let height = Double(args[1]), height >= 1.0, height <= 3.0 else {
                return .failure("Line height must be between 1.0 and 3.0")
            }
            EditorSettings.shared.lineHeight = height
            return .success("Line height set to \(height)")

        default:
            return .failure("Unknown setting: \(setting)")
        }
    }

    // MARK: - Help

    private static func executeHelp(args: [String]) -> EditorCommandResult {
        if let command = args.first {
            return helpForCommand(command)
        }

        let helpText = """
        File Commands:
          :open <path>       (:o, :e)   - Open file
          :save              (:w)       - Save current file
          :saveas <path>     (:wa)      - Save to new path
          :new               (:n)       - Create new tab
          :close             (:c, :bd)  - Close current tab
          :quit              (:q)       - Quit application

        Search:
          :search "pattern"  (:f)       - Find in file
          :search-replace "from" "to"   - Replace text

        Navigation:
          :goto <line>       (:g)       - Go to line
          :symbol <name>     (:@)       - Go to symbol

        Settings:
          :set <setting> <value>        - Change setting
          :theme [name]                 - Set or list themes

        Other:
          :clear                        - Clear console
          :pwd                          - Show working directory
          :help [cmd]        (:h, :?)   - Show help
        """
        return .success(helpText)
    }

    private static func helpForCommand(_ command: String) -> EditorCommandResult {
        switch command.lowercased() {
        // File operations
        case "open", "o", "e":
            return .success("""
            :open <path>  (aliases: :o, :e)

            Open a file in a new tab.

            Examples:
              :open file.swift        - Open relative to working directory
              :open ~/Documents/f.txt - Open with home path
              :o /etc/hosts           - Open absolute path
            """)

        case "save", "w":
            return .success("""
            :save  (alias: :w)

            Save the current file.
            Use :saveas <path> for files without a path.
            """)

        case "saveas", "wa":
            return .success("""
            :saveas <path>  (alias: :wa)

            Save the current file to a new path.

            Examples:
              :saveas backup.swift
              :wa ~/Desktop/copy.txt
            """)

        case "new", "n":
            return .success("""
            :new  (alias: :n)

            Create a new untitled tab.
            """)

        case "close", "c", "bd":
            return .success("""
            :close  (aliases: :c, :bd)

            Close the current tab.
            Will warn if there are unsaved changes.
            """)

        case "quit", "q":
            return .success("""
            :quit  (alias: :q)

            Quit the application.
            Will warn if there are unsaved changes.
            """)

        // Search
        case "search", "find", "f":
            return .success("""
            :search "pattern"  (aliases: :find, :f)

            Search for pattern in the current file.
            Shows matching lines with line numbers.

            Examples:
              :search "TODO"
              :f error
            """)

        case "search-replace", "sr", "replace":
            return .success("""
            :search-replace "pattern" "replacement" [<all>]

            Replace all occurrences of pattern with replacement.

            Examples:
              :search-replace "foo" "bar"         - Replace in current file
              :search-replace "foo" "bar" <all>   - Replace in all open files
            """)

        // Navigation
        case "goto", "go", "g":
            return .success("""
            :goto <line>  (alias: :g)

            Navigate to the specified line number.

            Examples:
              :goto 42
              :g 100
            """)

        case "symbol", "@":
            return .success("""
            :symbol <name>  (alias: :@)

            Jump to a symbol (function, class, etc.) by name.

            Examples:
              :symbol main
              :@ handleClick
            """)

        // Settings
        case "theme":
            return .success("""
            :theme [name]

            Set the editor theme or list available themes.

            Examples:
              :theme              - List themes
              :theme nord         - Set Nord theme
            """)

        case "set":
            return .success("""
            :set <setting> <value>

            Boolean settings:
              wrap (wordwrap)      - Word wrap on/off
              ln (linenumbers)     - Line numbers on/off
              hl (highlightline)   - Highlight current line
              spaces (usespaces)   - Spaces vs tabs

            Numeric settings:
              fontsize (fs)        - Font size (8-72)
              tabwidth (tw)        - Tab width (1-16)
              lineheight (lh)      - Line height (1.0-3.0)

            Examples:
              :set wrap on
              :set fontsize 14
              :set tw 2
            """)

        default:
            return .failure("No help available for: \(command)")
        }
    }
}
