import Foundation

/// Output line from shell execution
struct ShellOutputLine {
    let text: String
    let isError: Bool
}

/// Executes shell commands and streams output
actor ShellExecutor {
    private var runningProcess: Process?
    private var isCancelled = false

    /// Execute a shell command and stream output
    func execute(
        command: String,
        workingDirectory: URL?,
        onOutput: @escaping (ShellOutputLine) async -> Void
    ) async throws -> Int32 {
        isCancelled = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Store reference for cancellation
        runningProcess = process

        // Start the process
        try process.run()

        // Read output asynchronously
        async let stdoutTask: () = readPipe(outputPipe, isError: false, onOutput: onOutput)
        async let stderrTask: () = readPipe(errorPipe, isError: true, onOutput: onOutput)

        // Wait for output reading to complete
        _ = await (stdoutTask, stderrTask)

        // Wait for process to exit
        process.waitUntilExit()

        runningProcess = nil

        if isCancelled {
            return -1
        }

        return process.terminationStatus
    }

    private func readPipe(
        _ pipe: Pipe,
        isError: Bool,
        onOutput: @escaping (ShellOutputLine) async -> Void
    ) async {
        let handle = pipe.fileHandleForReading

        // Read line by line
        var buffer = Data()
        let newline = Data([0x0A]) // \n

        while true {
            let data = handle.availableData

            if data.isEmpty {
                break
            }

            buffer.append(data)

            // Process complete lines
            while let range = buffer.range(of: newline) {
                let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex...range.lowerBound)

                if let line = String(data: lineData, encoding: .utf8) {
                    let processedLine = ANSIParser.stripANSICodes(from: line)
                    await onOutput(ShellOutputLine(text: processedLine, isError: isError))
                }
            }
        }

        // Process any remaining data
        if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
            let processedLine = ANSIParser.stripANSICodes(from: line)
            await onOutput(ShellOutputLine(text: processedLine, isError: isError))
        }
    }

    /// Terminate the running process
    func terminate() {
        isCancelled = true
        runningProcess?.terminate()
    }
}

/// Simple ANSI code parser (strips codes for now, can be extended)
enum ANSIParser {
    // Regex to match ANSI escape sequences
    private static let ansiPattern = try! NSRegularExpression(
        pattern: "\\x1B\\[[0-9;]*[A-Za-z]",
        options: []
    )

    /// Strip ANSI codes from a string
    static func stripANSICodes(from string: String) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return ansiPattern.stringByReplacingMatches(
            in: string,
            options: [],
            range: range,
            withTemplate: ""
        )
    }
}
