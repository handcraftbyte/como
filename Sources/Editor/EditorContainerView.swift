import AppKit

/// Container view that holds the line number gutter and editor scroll view side by side
final class EditorContainerView: NSView {
	let gutterView: LineNumberGutterView
	let scrollView: EditorScrollView
	let textView: EditorTextView

	private var gutterWidthConstraint: NSLayoutConstraint?
	private var scrollViewLeadingConstraint: NSLayoutConstraint?

	override init(frame frameRect: NSRect) {
		// Create components
		scrollView = EditorScrollView()
		textView = EditorTextView()
		gutterView = LineNumberGutterView(textView: textView)

		super.init(frame: frameRect)

		// Set up scroll view
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = true
		scrollView.autohidesScrollers = true

		// Configure text view
		textView.autoresizingMask = [.width]
		textView.isVerticallyResizable = true
		textView.isHorizontallyResizable = false
		textView.minSize = NSSize(width: 0, height: 0)
		textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
		textView.textContainerInset = NSSize(width: 8, height: 8)

		// Add text view to scroll view
		scrollView.documentView = textView

		// Add subviews
		addSubview(gutterView)
		addSubview(scrollView)

		// Use Auto Layout
		gutterView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.translatesAutoresizingMaskIntoConstraints = false

		let gutterWidth = gutterView.widthAnchor.constraint(equalToConstant: LineNumberGutterView.gutterWidth)
		let scrollLeading = scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor)

		NSLayoutConstraint.activate([
			// Gutter on the left, fixed width
			gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
			gutterView.topAnchor.constraint(equalTo: topAnchor),
			gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
			gutterWidth,

			// Scroll view takes remaining space
			scrollLeading,
			scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])

		gutterWidthConstraint = gutterWidth
		scrollViewLeadingConstraint = scrollLeading
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// Updates the editor based on current settings
	func applySettings(showLineNumbers: Bool, wordWrap: Bool) {
		// Toggle gutter visibility
		if showLineNumbers {
			gutterView.isHidden = false
			gutterWidthConstraint?.constant = LineNumberGutterView.gutterWidth
		} else {
			gutterView.isHidden = true
			gutterWidthConstraint?.constant = 0
		}

		// Toggle word wrap
		if wordWrap {
			textView.isHorizontallyResizable = false
			textView.textContainer?.widthTracksTextView = true
			textView.textContainer?.containerSize = NSSize(
				width: textView.frame.width,
				height: CGFloat.greatestFiniteMagnitude
			)
			scrollView.hasHorizontalScroller = false
		} else {
			textView.isHorizontallyResizable = true
			textView.textContainer?.widthTracksTextView = false
			textView.textContainer?.containerSize = NSSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
			scrollView.hasHorizontalScroller = true
		}

		needsLayout = true
	}
}

/// Scroll view for the editor with overlay scrollers
final class EditorScrollView: NSScrollView {
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	private func setup() {
		drawsBackground = false
		borderType = .noBorder
		scrollerStyle = .overlay
	}
}
