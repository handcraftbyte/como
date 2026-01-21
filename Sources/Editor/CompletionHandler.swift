import AppKit

/// Handles code completion logic for the editor
/// Manages completion triggering, filtering, display, and insertion
@MainActor
final class CompletionHandler {
	private let popover = CompletionPopoverController()
	private weak var textView: EditorTextView?
	private let languageCoordinator: LanguageServiceCoordinator

	var isPopoverVisible: Bool { popover.isVisible }

	init(languageCoordinator: LanguageServiceCoordinator) {
		self.languageCoordinator = languageCoordinator
	}

	func configure(textView: EditorTextView) {
		self.textView = textView
	}

	// MARK: - Completion Triggering

	func triggerCompletion() {
		guard let textView = textView else { return }

		let position = textView.selectedRange().location
		let text = textView.string as NSString
		let wordStart = findWordStart(in: text, at: position)
		let prefix = text.substring(with: NSRange(location: wordStart, length: position - wordStart)).lowercased()

		Task { @MainActor in
			await languageCoordinator.requestCompletions(at: position)

			// Filter completions by prefix
			var filtered = languageCoordinator.completions
			if !prefix.isEmpty {
				filtered = filtered.filter { $0.label.lowercased().hasPrefix(prefix) }
			}

			Log.editor.debug("Completions: \(self.languageCoordinator.completions.count) total, \(filtered.count) filtered")
			guard !filtered.isEmpty else { return }

			// Calculate popup position at cursor
			guard let layoutManager = textView.layoutManager,
				  let textContainer = textView.textContainer else { return }

			let glyphRange = layoutManager.glyphRange(
				forCharacterRange: NSRange(location: position, length: 0),
				actualCharacterRange: nil
			)

			var rect = layoutManager.boundingRect(
				forGlyphRange: glyphRange,
				in: textContainer
			)

			// Adjust for text container inset
			rect.origin.x += textView.textContainerInset.width
			rect.origin.y += textView.textContainerInset.height

			// Make rect at least 1pt wide for popover positioning
			rect.size.width = max(rect.size.width, 1)
			rect.size.height = max(rect.size.height, 16)

			self.popover.show(
				completions: filtered,
				relativeTo: rect,
				in: textView
			) { [weak self] item in
				self?.insertCompletion(item)
			}
		}
	}

	// MARK: - Navigation

	func navigate(direction: Int) {
		popover.moveSelection(by: direction)
	}

	func confirmSelection() {
		popover.confirmSelection()
	}

	func cancel() {
		popover.hide()
	}

	// MARK: - Insertion

	private func insertCompletion(_ item: CompletionItem) {
		guard let textView = textView else { return }

		let cursorPos = textView.selectedRange().location
		let text = textView.string as NSString
		let wordStart = findWordStart(in: text, at: cursorPos)
		let replaceRange = NSRange(location: wordStart, length: cursorPos - wordStart)

		// Use insertText for proper undo support
		textView.shouldChangeText(in: replaceRange, replacementString: item.insertText)
		textView.replaceCharacters(in: replaceRange, with: item.insertText)
		textView.didChangeText()
	}

	// MARK: - Helpers

	/// Finds the start of the word at the given position (for completion prefix matching and replacement)
	private func findWordStart(in text: NSString, at position: Int) -> Int {
		let underscore = UInt16(("_" as Character).asciiValue!)
		let dollar = UInt16(("$" as Character).asciiValue!)
		var wordStart = position

		while wordStart > 0 {
			let char = text.character(at: wordStart - 1)
			if let scalar = UnicodeScalar(char),
			   !CharacterSet.alphanumerics.contains(scalar) && char != underscore && char != dollar {
				break
			}
			wordStart -= 1
		}
		return wordStart
	}
}
