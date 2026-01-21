import AppKit

/// Multi-cursor state management for the editor
/// Integrates with ChimeHQ's IBeam library concepts
final class MultiCursorManager {
	private weak var textView: NSTextView?
	private var additionalCursors: [NSRange] = []

	var isMultiCursorActive: Bool {
		!additionalCursors.isEmpty
	}

	var allCursorRanges: [NSRange] {
		var ranges = additionalCursors
		ranges.insert(textView?.selectedRange() ?? NSRange(), at: 0)
		return ranges
	}

	init(textView: NSTextView) {
		self.textView = textView
	}

	/// Add a cursor at the specified location
	/// Triggered by Option+Click
	func addCursor(at point: NSPoint) {
		guard let textView = textView,
			  let layoutManager = textView.layoutManager,
			  let textContainer = textView.textContainer else {
			return
		}

		let pointInTextContainer = NSPoint(
			x: point.x - textView.textContainerInset.width,
			y: point.y - textView.textContainerInset.height
		)

		var fraction: CGFloat = 0
		let glyphIndex = layoutManager.glyphIndex(for: pointInTextContainer, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
		let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

		let newRange = NSRange(location: charIndex, length: 0)

		// Don't add duplicate cursors
		if !additionalCursors.contains(newRange) && textView.selectedRange() != newRange {
			additionalCursors.append(newRange)
			updateCursorDisplay()
		}
	}

	/// Add cursors above the current selection
	/// Triggered by Option+Up
	func addCursorAbove() {
		guard let textView = textView,
			  let layoutManager = textView.layoutManager else { return }

		let currentRange = textView.selectedRange()
		let glyphIndex = layoutManager.glyphIndexForCharacter(at: currentRange.location)
		let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

		// Find position above current line
		let currentPoint = NSPoint(
			x: lineRect.minX + textView.textContainerInset.width,
			y: lineRect.minY - 1
		)

		if currentPoint.y > 0 {
			addCursor(at: currentPoint)
		}
	}

	/// Add cursors below the current selection
	/// Triggered by Option+Down
	func addCursorBelow() {
		guard let textView = textView,
			  let layoutManager = textView.layoutManager else { return }

		let currentRange = textView.selectedRange()
		let glyphIndex = layoutManager.glyphIndexForCharacter(at: currentRange.location)
		let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

		// Find position below current line
		let currentPoint = NSPoint(
			x: lineRect.minX + textView.textContainerInset.width,
			y: lineRect.maxY + 1
		)

		addCursor(at: currentPoint)
	}

	/// Clear all additional cursors
	/// Triggered by Escape or single click without modifier
	func clearAdditionalCursors() {
		additionalCursors.removeAll()
		updateCursorDisplay()
	}

	/// Insert text at all cursor positions
	func insertTextAtAllCursors(_ text: String) {
		guard let textView = textView,
			  let textStorage = textView.textStorage else { return }

		// Sort cursors by position (descending) to avoid offset issues
		let allRanges = allCursorRanges.sorted { $0.location > $1.location }

		textView.undoManager?.beginUndoGrouping()

		for range in allRanges {
			textStorage.replaceCharacters(in: range, with: text)
		}

		textView.undoManager?.endUndoGrouping()

		// Update cursor positions
		updateCursorPositionsAfterInsertion(text)
	}

	/// Delete text at all cursor positions
	func deleteAtAllCursors(forward: Bool) {
		guard let textView = textView,
			  let textStorage = textView.textStorage else { return }

		let allRanges = allCursorRanges.sorted { $0.location > $1.location }

		textView.undoManager?.beginUndoGrouping()

		for range in allRanges {
			let deleteRange: NSRange
			if range.length > 0 {
				deleteRange = range
			} else if forward {
				deleteRange = NSRange(location: range.location, length: 1)
			} else {
				deleteRange = NSRange(location: max(0, range.location - 1), length: 1)
			}

			if deleteRange.location >= 0 && deleteRange.location + deleteRange.length <= textStorage.length {
				textStorage.replaceCharacters(in: deleteRange, with: "")
			}
		}

		textView.undoManager?.endUndoGrouping()
	}

	private func updateCursorPositionsAfterInsertion(_ text: String) {
		let insertionLength = (text as NSString).length

		// Adjust all cursor positions
		additionalCursors = additionalCursors.map { range in
			NSRange(location: range.location + insertionLength, length: 0)
		}
	}

	private func updateCursorDisplay() {
		textView?.needsDisplay = true
	}
}

// MARK: - EditorTextView Multi-cursor Extension
extension EditorTextView {
	private static var multiCursorManagerKey: UInt8 = 0

	var multiCursorManager: MultiCursorManager {
		if let manager = objc_getAssociatedObject(self, &Self.multiCursorManagerKey) as? MultiCursorManager {
			return manager
		}
		let manager = MultiCursorManager(textView: self)
		objc_setAssociatedObject(self, &Self.multiCursorManagerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		return manager
	}

	override func mouseDown(with event: NSEvent) {
		if event.modifierFlags.contains(.option) {
			let point = convert(event.locationInWindow, from: nil)
			multiCursorManager.addCursor(at: point)
		} else {
			multiCursorManager.clearAdditionalCursors()
			super.mouseDown(with: event)
		}
	}

	override func keyDown(with event: NSEvent) {
		let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

		// Completion navigation (when popover is visible)
		// NSTextView events are always on main thread, safe to call delegate directly
		if flags.isEmpty || flags == .shift {
			switch event.keyCode {
			case 125: // Down arrow
				if completionDelegate?.editorTextViewCompletionNavigate(self, direction: 1) == true {
					return
				}
			case 126: // Up arrow
				if completionDelegate?.editorTextViewCompletionNavigate(self, direction: -1) == true {
					return
				}
			case 36: // Return/Enter
				if completionDelegate?.editorTextViewCompletionConfirm(self) == true {
					return
				}
			case 48: // Tab
				if completionDelegate?.editorTextViewCompletionConfirm(self) == true {
					return
				}
			case 53: // Escape
				if completionDelegate?.editorTextViewCompletionCancel(self) == true {
					return
				}
			default:
				break
			}
		}

		// Completion triggers: Ctrl+Space, Option+Escape
		if flags == .control && event.keyCode == 49 { // Ctrl+Space
			Task { @MainActor in
				self.completionDelegate?.editorTextViewRequestsCompletion(self)
			}
			return
		}
		if flags == .option && event.keyCode == 53 { // Option+Escape
			Task { @MainActor in
				self.completionDelegate?.editorTextViewRequestsCompletion(self)
			}
			return
		}

		// Handle multi-cursor keyboard shortcuts
		if event.modifierFlags.contains(.option) {
			switch event.keyCode {
			case 126: // Up arrow
				multiCursorManager.addCursorAbove()
				return
			case 125: // Down arrow
				multiCursorManager.addCursorBelow()
				return
			default:
				break
			}
		}

		// Escape clears multi-cursors
		if event.keyCode == 53 && multiCursorManager.isMultiCursorActive {
			multiCursorManager.clearAdditionalCursors()
			return
		}

		super.keyDown(with: event)
	}

	override func insertText(_ insertString: Any, replacementRange: NSRange) {
		if multiCursorManager.isMultiCursorActive, let text = insertString as? String {
			multiCursorManager.insertTextAtAllCursors(text)
		} else {
			super.insertText(insertString, replacementRange: replacementRange)
		}
	}

	override func deleteBackward(_ sender: Any?) {
		if multiCursorManager.isMultiCursorActive {
			multiCursorManager.deleteAtAllCursors(forward: false)
		} else {
			super.deleteBackward(sender)
		}
	}

	override func deleteForward(_ sender: Any?) {
		if multiCursorManager.isMultiCursorActive {
			multiCursorManager.deleteAtAllCursors(forward: true)
		} else {
			super.deleteForward(sender)
		}
	}
}
