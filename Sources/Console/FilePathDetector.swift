import Foundation

/// Detected file path in console output
struct DetectedPath {
    let range: Range<String.Index>
    let path: String
    let line: Int?
    let column: Int?

    var absolutePath: String {
        path
    }
}

/// Detects file paths in console output
enum FilePathDetector {
    // Patterns for detecting file paths
    // Order matters - more specific patterns first

    /// Matches: /path/to/file.ext:line:column
    private static let pathWithLineAndColumn = try! NSRegularExpression(
        pattern: #"(/[^\s:]+\.[a-zA-Z0-9]+):(\d+):(\d+)"#,
        options: []
    )

    /// Matches: /path/to/file.ext:line
    private static let pathWithLine = try! NSRegularExpression(
        pattern: #"(/[^\s:]+\.[a-zA-Z0-9]+):(\d+)"#,
        options: []
    )

    /// Matches: /path/to/file.ext (absolute path with extension)
    private static let absolutePath = try! NSRegularExpression(
        pattern: #"(/[^\s:]+\.[a-zA-Z0-9]+)"#,
        options: []
    )

    /// Matches: ./relative/path.ext or ../relative/path.ext
    private static let relativePath = try! NSRegularExpression(
        pattern: #"(\.\.?/[^\s:]+\.[a-zA-Z0-9]+)(?::(\d+))?(?::(\d+))?"#,
        options: []
    )

    /// Matches paths without extensions (directories from ls)
    private static let directoryPath = try! NSRegularExpression(
        pattern: #"(/[^\s]+/)"#,
        options: []
    )

    /// Detect all file paths in a text string
    static func detectPaths(in text: String, workingDirectory: URL?) -> [DetectedPath] {
        var results: [DetectedPath] = []
        var coveredRanges: [Range<String.Index>] = []

        let nsRange = NSRange(text.startIndex..., in: text)

        // Check path with line and column first
        let lineColMatches = pathWithLineAndColumn.matches(in: text, options: [], range: nsRange)
        for match in lineColMatches {
            if let range = Range(match.range, in: text),
               let pathRange = Range(match.range(at: 1), in: text),
               let lineRange = Range(match.range(at: 2), in: text),
               let colRange = Range(match.range(at: 3), in: text) {

                let path = resolvePath(String(text[pathRange]), workingDirectory: workingDirectory)
                let line = Int(text[lineRange])
                let column = Int(text[colRange])

                if isValidPath(path) {
                    results.append(DetectedPath(range: range, path: path, line: line, column: column))
                    coveredRanges.append(range)
                }
            }
        }

        // Check path with line
        let lineMatches = pathWithLine.matches(in: text, options: [], range: nsRange)
        for match in lineMatches {
            if let range = Range(match.range, in: text),
               !coveredRanges.contains(where: { $0.overlaps(range) }),
               let pathRange = Range(match.range(at: 1), in: text),
               let lineRange = Range(match.range(at: 2), in: text) {

                let path = resolvePath(String(text[pathRange]), workingDirectory: workingDirectory)
                let line = Int(text[lineRange])

                if isValidPath(path) {
                    results.append(DetectedPath(range: range, path: path, line: line, column: nil))
                    coveredRanges.append(range)
                }
            }
        }

        // Check absolute paths
        let absMatches = absolutePath.matches(in: text, options: [], range: nsRange)
        for match in absMatches {
            if let range = Range(match.range, in: text),
               !coveredRanges.contains(where: { $0.overlaps(range) }) {

                let path = String(text[range])

                if isValidPath(path) {
                    results.append(DetectedPath(range: range, path: path, line: nil, column: nil))
                    coveredRanges.append(range)
                }
            }
        }

        // Check relative paths
        let relMatches = relativePath.matches(in: text, options: [], range: nsRange)
        for match in relMatches {
            if let range = Range(match.range, in: text),
               !coveredRanges.contains(where: { $0.overlaps(range) }),
               let pathRange = Range(match.range(at: 1), in: text) {

                let relativePath = String(text[pathRange])
                let path = resolvePath(relativePath, workingDirectory: workingDirectory)

                var line: Int? = nil
                var column: Int? = nil

                if match.numberOfRanges > 2, let lineRange = Range(match.range(at: 2), in: text) {
                    line = Int(text[lineRange])
                }
                if match.numberOfRanges > 3, let colRange = Range(match.range(at: 3), in: text) {
                    column = Int(text[colRange])
                }

                if isValidPath(path) {
                    results.append(DetectedPath(range: range, path: path, line: line, column: column))
                    coveredRanges.append(range)
                }
            }
        }

        return results.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Parse a line of text and return segments with clickable paths
    static func parseLineWithPaths(_ text: String, workingDirectory: URL?) -> [ConsoleLineSegment] {
        let detectedPaths = detectPaths(in: text, workingDirectory: workingDirectory)

        if detectedPaths.isEmpty {
            return [.plain(text)]
        }

        var segments: [ConsoleLineSegment] = []
        var currentIndex = text.startIndex

        for detected in detectedPaths {
            // Add text before the path
            if currentIndex < detected.range.lowerBound {
                let prefix = String(text[currentIndex..<detected.range.lowerBound])
                segments.append(.plain(prefix))
            }

            // Add the path segment
            segments.append(.path(detected.path, line: detected.line, column: detected.column))

            currentIndex = detected.range.upperBound
        }

        // Add remaining text
        if currentIndex < text.endIndex {
            let suffix = String(text[currentIndex...])
            segments.append(.plain(suffix))
        }

        return segments
    }

    /// Resolve a path (handle relative paths)
    private static func resolvePath(_ path: String, workingDirectory: URL?) -> String {
        if path.hasPrefix("/") {
            return path
        }

        guard let workingDirectory = workingDirectory else {
            return path
        }

        return workingDirectory.appendingPathComponent(path).standardized.path
    }

    /// Check if a path looks valid (exists or has a valid file extension)
    private static func isValidPath(_ path: String) -> Bool {
        // Check if file exists
        if FileManager.default.fileExists(atPath: path) {
            return true
        }

        // Check if it has a recognizable extension
        let ext = (path as NSString).pathExtension.lowercased()
        let validExtensions = [
            "swift", "py", "js", "ts", "tsx", "jsx", "json", "md", "txt",
            "html", "css", "scss", "sass", "go", "rs", "rb", "c", "h",
            "cpp", "hpp", "cc", "sh", "bash", "zsh", "yaml", "yml",
            "xml", "log", "conf", "config", "env"
        ]

        return validExtensions.contains(ext)
    }
}
