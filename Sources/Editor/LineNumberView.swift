import AppKit

/// Line number gutter view that overlays the scroll view
/// Uses textContainerInset to make room for itself instead of NSRulerView
final class LineNumberGutterView: NSView {
	private var lineIndices: [Int] = []
	private weak var textView: NSTextView?
	static let gutterWidth: CGFloat = Constants.Editor.gutterWidth

	// Use flipped coordinates to match text view (y=0 at top)
	override var isFlipped: Bool { true }

	var font: NSFont = NSFont.monospacedSystemFont(ofSize: Constants.Editor.lineNumberFontSize, weight: .regular) {
		didSet { needsDisplay = true }
	}

	var textColor: NSColor = .secondaryLabelColor {
		didSet { needsDisplay = true }
	}

	var gutterBackgroundColor: NSColor = .clear {
		didSet { needsDisplay = true }
	}

	init(textView: NSTextView) {
		self.textView = textView
		super.init(frame: .zero)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(textDidChange(_:)),
			name: NSText.didChangeNotification,
			object: textView
		)

		calculateLines()
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		// Register for scroll notifications once the view hierarchy is set up
		if let scrollView = textView?.enclosingScrollView {
			NotificationCenter.default.addObserver(
				self,
				selector: #selector(boundsDidChange(_:)),
				name: NSView.boundsDidChangeNotification,
				object: scrollView.contentView
			)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	@objc private func textDidChange(_ notification: Notification) {
		calculateLines()
		needsDisplay = true
	}

	@objc private func boundsDidChange(_ notification: Notification) {
		needsDisplay = true
	}

	private func calculateLines() {
		guard let textView = textView else { return }

		let text = textView.string as NSString

		if text.length == 0 {
			lineIndices = [0]
			return
		}

		lineIndices = [0]

		var index = 0
		while index < text.length {
			let lineRange = text.lineRange(for: NSRange(location: index, length: 0))
			index = lineRange.location + lineRange.length
			if index < text.length {
				lineIndices.append(index)
			}
		}

		// Handle trailing newline - adds an empty line at the end
		if text.length > 0 && text.character(at: text.length - 1) == UInt16(UnicodeScalar("\n").value) {
			lineIndices.append(text.length)
		}
	}

	/// Force refresh of line numbers (call after programmatic text changes)
	func refresh() {
		calculateLines()
		needsDisplay = true
	}

	override func draw(_ dirtyRect: NSRect) {
		guard let textView = textView,
			  let layoutManager = textView.layoutManager,
			  let textContainer = textView.textContainer,
			  let scrollView = textView.enclosingScrollView else {
			return
		}

		// Draw background
		gutterBackgroundColor.setFill()
		dirtyRect.fill()

		let textLength = (textView.string as NSString).length
		let visibleRect = scrollView.contentView.bounds
		let textContainerInset = textView.textContainerInset

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .right

		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]

		// Handle empty text case
		if textLength == 0 {
			let yPos = textContainerInset.height - visibleRect.origin.y
			let drawRect = NSRect(x: 0, y: yPos, width: Self.gutterWidth - 8, height: font.pointSize + 4)
			"1".draw(in: drawRect, withAttributes: attributes)
			return
		}

		// Ensure layout is complete
		layoutManager.ensureLayout(for: textContainer)

		let numberOfGlyphs = layoutManager.numberOfGlyphs

		for (index, charIndex) in lineIndices.enumerated() {
			guard charIndex < textLength else { continue }

			let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
			guard glyphIndex < numberOfGlyphs else { continue }

			var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

			// Adjust for text container inset and scroll position
			lineRect.origin.y += textContainerInset.height
			lineRect.origin.y -= visibleRect.origin.y

			// Skip lines outside visible area
			if lineRect.maxY < 0 || lineRect.minY > bounds.height {
				continue
			}

			let lineNumber = "\(index + 1)"
			let drawRect = NSRect(
				x: 0,
				y: lineRect.origin.y,
				width: Self.gutterWidth - 8,
				height: lineRect.height
			)

			lineNumber.draw(in: drawRect, withAttributes: attributes)
		}
	}
}

