import AppKit

/// Protocol for completion trigger events
@MainActor
protocol EditorTextViewCompletionDelegate: AnyObject {
	func editorTextViewRequestsCompletion(_ textView: EditorTextView)
	func editorTextViewCompletionNavigate(_ textView: EditorTextView, direction: Int) -> Bool
	func editorTextViewCompletionConfirm(_ textView: EditorTextView) -> Bool
	func editorTextViewCompletionCancel(_ textView: EditorTextView) -> Bool
}

/// Custom text view for the code editor
final class EditorTextView: NSTextView {
	weak var completionDelegate: EditorTextViewCompletionDelegate?

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setup()
	}

	override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
		super.init(frame: frameRect, textContainer: container)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	private func setup() {
		// Basic text view setup
		isRichText = false
		allowsUndo = true
		usesFindBar = true
		isAutomaticQuoteSubstitutionEnabled = false
		isAutomaticDashSubstitutionEnabled = false
		isAutomaticTextReplacementEnabled = false
		isAutomaticSpellingCorrectionEnabled = false
		isContinuousSpellCheckingEnabled = false
		isGrammarCheckingEnabled = false

		// Typography
		font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

		// Line wrapping - container tracks text view width, but can grow infinitely in height
		isHorizontallyResizable = false
		textContainer?.widthTracksTextView = true
		textContainer?.heightTracksTextView = false
		textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
	}
}
