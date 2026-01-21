import Foundation
import AppKit

/// Represents a diagnostic (error, warning, etc.) from the TypeScript language service
struct Diagnostic: Identifiable, Hashable {
    let id = UUID()
    let range: Range<Int>
    let message: String
    let severity: DiagnosticSeverity
    let code: Int?

    init(start: Int, length: Int, message: String, category: Int, code: Int? = nil) {
        self.range = start..<(start + max(1, length))
        self.message = message
        self.severity = DiagnosticSeverity(tsCategory: category)
        self.code = code
    }

    /// NSRange for use with NSTextStorage
    var nsRange: NSRange {
        NSRange(location: range.lowerBound, length: range.count)
    }
}

/// Diagnostic severity matching TypeScript DiagnosticCategory
enum DiagnosticSeverity: Int, CaseIterable {
    case warning = 0
    case error = 1
    case suggestion = 2
    case message = 3

    init(tsCategory: Int) {
        self = DiagnosticSeverity(rawValue: tsCategory) ?? .message
    }

    /// Color for underline
    var underlineColor: NSColor {
        switch self {
        case .error:
            return .systemRed
        case .warning:
            return .systemYellow
        case .suggestion:
            return .systemBlue
        case .message:
            return .secondaryLabelColor
        }
    }

    /// Icon name for status bar
    var iconName: String {
        switch self {
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .suggestion:
            return "lightbulb.fill"
        case .message:
            return "info.circle.fill"
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .suggestion: return "Suggestion"
        case .message: return "Message"
        }
    }
}
