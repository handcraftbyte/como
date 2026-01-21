import Foundation

/// App-wide constants for consistent configuration
enum Constants {
    /// Editor-related constants
    enum Editor {
        /// Width of the line number gutter
        static let gutterWidth: CGFloat = 40
        /// Font size for line numbers
        static let lineNumberFontSize: CGFloat = 12
    }

    /// Completion popover constants
    enum Completion {
        /// Width of the completion popover
        static let popoverWidth: CGFloat = 280
        /// Height of each completion row
        static let rowHeight: CGFloat = 22
        /// Maximum number of visible rows before scrolling
        static let maxVisibleRows: Int = 10
    }

    /// Language service constants
    enum LanguageService {
        /// Debounce interval for diagnostics refresh (seconds)
        static let diagnosticsDebounceInterval: TimeInterval = 0.5
    }
}
