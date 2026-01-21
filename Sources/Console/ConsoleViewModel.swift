import SwiftUI
import Combine
import AppKit

/// Manages console state and command execution
@MainActor
final class ConsoleViewModel: ObservableObject {
    // MARK: - Published State

    @Published var inputText = ""
    @Published var outputLines: [ConsoleLine] = []
    @Published var commandHistory: [String] = []
    @Published var historyIndex: Int = -1
    @Published var isExecutingCommand = false
    @Published var inputMode: ConsoleInputMode = .shell
    @Published var workingDirectory: URL

    // MARK: - Dependencies

    weak var tabManager: TabManager?
    private var shellExecutor: ShellExecutor?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Pipe Command Support

    /// Callback to get current editor selection
    var getSelection: (() -> String)?

    /// Published text operation for editor to apply
    @Published var pendingTextOperation: TextOperation?

    // MARK: - Initialization

    init() {
        // Default to home directory
        self.workingDirectory = FileManager.default.homeDirectoryForCurrentUser

        // Watch input text for mode detection
        $inputText
            .sink { [weak self] text in
                self?.detectInputMode(from: text)
            }
            .store(in: &cancellables)
    }

    // MARK: - Input Mode Detection

    private func detectInputMode(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            inputMode = .shell
        } else if trimmed.hasPrefix("@") {
            inputMode = .symbolSearch
        } else if trimmed.hasPrefix(":") {
            // Check if it's a line number
            let afterColon = String(trimmed.dropFirst())
            if let _ = Int(afterColon) {
                inputMode = .lineNavigation
            } else if !afterColon.isEmpty {
                inputMode = .editorCommand
            } else {
                inputMode = .editorCommand
            }
        } else if trimmed.hasPrefix("$") || trimmed.hasPrefix("!") {
            inputMode = .shell
        } else {
            // Default to shell mode
            inputMode = .shell
        }
    }

    // MARK: - Command Execution

    func processInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Add to history
        if commandHistory.last != trimmed {
            commandHistory.append(trimmed)
        }
        historyIndex = -1

        // Capture command and mode BEFORE clearing input
        let command = inputText
        let currentMode = inputMode

        // Clear input
        inputText = ""

        // Process based on captured mode
        Task {
            switch currentMode {
            case .shell:
                await executeShellCommand(command)
            case .editorCommand:
                executeEditorCommand(command)
            case .lineNavigation:
                executeLineNavigation(command)
            case .symbolSearch:
                executeSymbolSearch(command)
            case .quickOpen:
                executeQuickOpen(command)
            }
        }
    }

    private func executeShellCommand(_ command: String) async {
        // Strip leading $ or ! if present
        var shellCommand = command
        if shellCommand.hasPrefix("$") || shellCommand.hasPrefix("!") {
            shellCommand = String(shellCommand.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        guard !shellCommand.isEmpty else { return }

        // Echo the command
        outputLines.append(.input(shellCommand))

        isExecutingCommand = true

        // Handle cd command specially
        if shellCommand.hasPrefix("cd ") {
            let path = String(shellCommand.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            handleCdCommand(path)
            isExecutingCommand = false
            return
        }

        // Execute the command
        let executor = ShellExecutor()
        self.shellExecutor = executor

        do {
            let exitCode = try await executor.execute(
                command: shellCommand,
                workingDirectory: workingDirectory
            ) { [weak self] line in
                await MainActor.run {
                    self?.handleOutputLine(line)
                }
            }

            if let resultLine = ConsoleLine.result(success: exitCode == 0, exitCode: exitCode) {
                outputLines.append(resultLine)
            }
        } catch {
            outputLines.append(.text("Error: \(error.localizedDescription)", kind: .stderr))
            if let resultLine = ConsoleLine.result(success: false, exitCode: -1) {
                outputLines.append(resultLine)
            }
        }

        isExecutingCommand = false
        shellExecutor = nil
    }

    private func handleOutputLine(_ line: ShellOutputLine) {
        let segments = FilePathDetector.parseLineWithPaths(
            line.text,
            workingDirectory: workingDirectory
        )

        let consoleLine = ConsoleLine(
            kind: line.isError ? .stderr : .stdout,
            segments: segments
        )
        outputLines.append(consoleLine)
    }

    private func handleCdCommand(_ path: String) {
        var targetPath = path

        // Handle ~ for home directory
        if targetPath.hasPrefix("~") {
            targetPath = targetPath.replacingOccurrences(
                of: "~",
                with: FileManager.default.homeDirectoryForCurrentUser.path
            )
        }

        // Handle relative paths
        let targetURL: URL
        if targetPath.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: targetPath)
        } else {
            targetURL = workingDirectory.appendingPathComponent(targetPath)
        }

        // Resolve .. and . components
        let resolvedURL = targetURL.standardized

        // Check if directory exists
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            workingDirectory = resolvedURL
            outputLines.append(.system("Changed directory to \(resolvedURL.path)"))
        } else {
            outputLines.append(.text("cd: no such directory: \(path)", kind: .stderr))
        }
    }

    /// Published navigation action for views to observe
    @Published var pendingNavigation: NavigationAction?

    private func executeEditorCommand(_ command: String) {
        // Strip leading :
        let cmd = String(command.dropFirst()).trimmingCharacters(in: .whitespaces)

        // Check for pipe commands first (they need async handling)
        if cmd.hasPrefix("<") {
            let shellCmd = String(cmd.dropFirst()).trimmingCharacters(in: .whitespaces)
            outputLines.append(.input(":< " + shellCmd))
            Task { await executePipeRead(shellCmd) }
            return
        } else if cmd.hasPrefix(">") {
            let shellCmd = String(cmd.dropFirst()).trimmingCharacters(in: .whitespaces)
            outputLines.append(.input(":> " + shellCmd))
            Task { await executePipeWrite(shellCmd) }
            return
        } else if cmd.hasPrefix("|") {
            let shellCmd = String(cmd.dropFirst()).trimmingCharacters(in: .whitespaces)
            outputLines.append(.input(":| " + shellCmd))
            Task { await executePipeBoth(shellCmd) }
            return
        }

        outputLines.append(.input(":" + cmd))

        // Parse and execute editor command
        let result = EditorCommandExecutor.execute(cmd, tabManager: tabManager, workingDirectory: workingDirectory)

        switch result {
        case .success(let message):
            if let message = message {
                outputLines.append(.system(message))
            }
        case .failure(let error):
            outputLines.append(.text(error, kind: .stderr))
        case .navigation(let action, let message):
            if let message = message {
                outputLines.append(.system(message))
            }
            pendingNavigation = action
        case .clearConsole:
            clear()
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Pipe Commands

    /// :< command - Read command output into editor at cursor
    private func executePipeRead(_ command: String) async {
        guard !command.isEmpty else {
            outputLines.append(.text("Usage: :< command", kind: .stderr))
            return
        }

        isExecutingCommand = true

        do {
            let output = try await executeShellAndCapture(command: command, stdin: nil)
            if !output.isEmpty {
                // Select the inserted text so user can see what was added
                pendingTextOperation = .insertAtCursor(output, selectResult: true)
                outputLines.append(.system("Inserted \(output.count) characters"))
            }
        } catch {
            outputLines.append(.text("Error: \(error.localizedDescription)", kind: .stderr))
        }

        isExecutingCommand = false
    }

    /// :> command - Write selection to command stdin, show output
    private func executePipeWrite(_ command: String) async {
        guard !command.isEmpty else {
            outputLines.append(.text("Usage: :> command", kind: .stderr))
            return
        }

        let selection = getSelection?() ?? ""
        if selection.isEmpty {
            outputLines.append(.text("No selection", kind: .stderr))
            return
        }

        isExecutingCommand = true

        do {
            let output = try await executeShellAndCapture(command: command, stdin: selection)
            if !output.isEmpty {
                // Show command output in console
                outputLines.append(.text(output, kind: .stdout))
            } else {
                outputLines.append(.system("Sent \(selection.count) characters"))
            }
        } catch {
            outputLines.append(.text("Error: \(error.localizedDescription)", kind: .stderr))
        }

        isExecutingCommand = false
    }

    /// :| command - Pipe selection through command, replace with output
    private func executePipeBoth(_ command: String) async {
        guard !command.isEmpty else {
            outputLines.append(.text("Usage: :| command", kind: .stderr))
            return
        }

        let selection = getSelection?() ?? ""

        isExecutingCommand = true

        do {
            let output = try await executeShellAndCapture(command: command, stdin: selection.isEmpty ? nil : selection)

            if selection.isEmpty {
                // No selection: insert output at cursor, select result
                if !output.isEmpty {
                    pendingTextOperation = .insertAtCursor(output, selectResult: true)
                    outputLines.append(.system("Inserted \(output.count) characters"))
                }
            } else {
                // Has selection: replace with output, keep it selected
                pendingTextOperation = .replaceSelection(output, selectResult: true)
                outputLines.append(.system("Replaced \(selection.count) → \(output.count) characters"))
            }
        } catch {
            outputLines.append(.text("Error: \(error.localizedDescription)", kind: .stderr))
        }

        isExecutingCommand = false
    }

    /// Execute shell command and capture output
    private func executeShellAndCapture(command: String, stdin: String?) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = workingDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let stdin = stdin {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            inputPipe.fileHandleForWriting.write(stdin.data(using: .utf8) ?? Data())
            inputPipe.fileHandleForWriting.closeFile()
        }

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        // Trim trailing newline that most commands add
        return output.hasSuffix("\n") ? String(output.dropLast()) : output
    }

    private func executeLineNavigation(_ command: String) {
        let lineStr = String(command.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard let line = Int(lineStr), line > 0 else {
            outputLines.append(.text("Invalid line number", kind: .stderr))
            return
        }

        outputLines.append(.system("Line \(line)"))
        pendingNavigation = .line(line)
    }

    private func executeSymbolSearch(_ command: String) {
        let query = String(command.dropFirst()).trimmingCharacters(in: .whitespaces)
        outputLines.append(.system("Searching for symbol: \(query)"))
        // Symbol search would integrate with existing symbol extraction
    }

    private func executeQuickOpen(_ command: String) {
        outputLines.append(.system("Quick open: \(command)"))
        // Would integrate with file search
    }

    // MARK: - History Navigation

    func navigateHistoryUp() {
        guard !commandHistory.isEmpty else { return }

        if historyIndex < 0 {
            historyIndex = commandHistory.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }

        inputText = commandHistory[historyIndex]
    }

    func navigateHistoryDown() {
        guard !commandHistory.isEmpty, historyIndex >= 0 else { return }

        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            inputText = commandHistory[historyIndex]
        } else {
            historyIndex = -1
            inputText = ""
        }
    }

    // MARK: - Control

    func cancelCurrentExecution() {
        Task {
            await shellExecutor?.terminate()
        }
        isExecutingCommand = false
        outputLines.append(.system("Command cancelled"))
    }

    func clear() {
        outputLines.removeAll()
    }

    // MARK: - File Path Handling

    func handlePathClick(path: String, line: Int?, column: Int?) {
        guard let tabManager = tabManager else { return }

        // Resolve path
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            url = workingDirectory.appendingPathComponent(path).standardized
        }

        // Open file in tab
        do {
            try tabManager.openFile(at: url, line: line, column: column)
        } catch {
            outputLines.append(.text("Cannot open file: \(error.localizedDescription)", kind: .stderr))
        }
    }
}
