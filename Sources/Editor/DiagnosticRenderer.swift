import AppKit

/// Renders diagnostic underlines and tooltips in NSTextView
final class DiagnosticRenderer {
    weak var textView: NSTextView?
    private(set) var diagnostics: [Diagnostic] = []

    /// Custom attribute key for storing diagnostic info
    static let diagnosticKey = NSAttributedString.Key("ComoDiagnostic")

    /// Update diagnostics and apply underlines
    func update(diagnostics: [Diagnostic]) {
        self.diagnostics = diagnostics
        applyUnderlines()
    }

    /// Apply diagnostic underlines to the text storage
    private func applyUnderlines() {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Begin editing
        textStorage.beginEditing()

        // Remove existing diagnostic attributes
        textStorage.removeAttribute(.underlineStyle, range: fullRange)
        textStorage.removeAttribute(.underlineColor, range: fullRange)
        textStorage.removeAttribute(.toolTip, range: fullRange)
        textStorage.removeAttribute(Self.diagnosticKey, range: fullRange)

        // Apply diagnostic underlines
        for diagnostic in diagnostics {
            // Validate range
            guard diagnostic.range.lowerBound >= 0,
                  diagnostic.range.lowerBound < textStorage.length else {
                continue
            }

            // Clamp range to text bounds
            let safeEnd = min(diagnostic.range.upperBound, textStorage.length)
            let safeLength = max(1, safeEnd - diagnostic.range.lowerBound)
            let safeRange = NSRange(location: diagnostic.range.lowerBound, length: safeLength)

            // Determine underline style based on severity
            let underlineStyle: NSUnderlineStyle
            switch diagnostic.severity {
            case .error:
                underlineStyle = [.single, .patternDot]
            case .warning:
                underlineStyle = [.single, .patternDash]
            case .suggestion, .message:
                underlineStyle = [.single, .patternDashDot]
            }

            // Apply attributes
            textStorage.addAttributes([
                .underlineStyle: underlineStyle.rawValue,
                .underlineColor: diagnostic.severity.underlineColor,
                .toolTip: diagnostic.message,
                Self.diagnosticKey: diagnostic.id
            ], range: safeRange)
        }

        // End editing
        textStorage.endEditing()
    }

    /// Get diagnostic at text position (for hover/click)
    func diagnostic(at position: Int) -> Diagnostic? {
        diagnostics.first { $0.range.contains(position) }
    }

    /// Get diagnostic at point in text view
    func diagnostic(at point: NSPoint) -> Diagnostic? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return nil
        }

        // Convert point to text container coordinates
        let textContainerOffset = textView.textContainerOrigin
        let locationInTextContainer = NSPoint(
            x: point.x - textContainerOffset.x,
            y: point.y - textContainerOffset.y
        )

        // Get character index at point
        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        return diagnostic(at: characterIndex)
    }

    /// Clear all diagnostic rendering
    func clear() {
        diagnostics = []
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.removeAttribute(.underlineStyle, range: fullRange)
        textStorage.removeAttribute(.underlineColor, range: fullRange)
        textStorage.removeAttribute(.toolTip, range: fullRange)
        textStorage.removeAttribute(Self.diagnosticKey, range: fullRange)
        textStorage.endEditing()
    }
}
