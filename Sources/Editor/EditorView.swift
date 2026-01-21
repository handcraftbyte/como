import SwiftUI
import AppKit
import Combine

/// Operations that can be applied to the editor text
enum TextOperation: Equatable {
	case replaceSelection(String, selectResult: Bool = false)
	case insertAtCursor(String, selectResult: Bool = false)
}

struct EditorView: NSViewRepresentable {
	@Binding var text: String
	let language: Language
	@Binding var cursorPosition: CursorPosition
	@Binding var navigateToPosition: Int?
	@Binding var requestFocus: Bool
	@Binding var pendingTextOperation: TextOperation?
	var onSelectionChange: ((String, NSRange) -> Void)?
	var onDiagnosticsUpdate: (([Diagnostic]) -> Void)?
	@EnvironmentObject var themeManager: ThemeManager
	@ObservedObject private var editorSettings = EditorSettings.shared

	func makeNSView(context: Context) -> EditorContainerView {
		let container = EditorContainerView()
		let textView = container.textView
		let gutterView = container.gutterView

		// Configure text view
		textView.delegate = context.coordinator
		textView.string = text

		context.coordinator.textView = textView
		context.coordinator.gutterView = gutterView
		context.coordinator.container = container
		context.coordinator.applyTheme(themeManager.currentTheme)
		context.coordinator.configureLanguageService(for: language, onDiagnosticsUpdate: onDiagnosticsUpdate)

		// Apply initial settings
		container.applySettings(
			showLineNumbers: editorSettings.showLineNumbers,
			wordWrap: editorSettings.wordWrap
		)

		return container
	}

	func updateNSView(_ container: EditorContainerView, context: Context) {
		let textView = container.textView

		if textView.string != text {
			let selectedRanges = textView.selectedRanges
			textView.string = text
			textView.selectedRanges = selectedRanges
		}

		// Handle navigation request
		if let position = navigateToPosition {
			let safePosition = min(position, (textView.string as NSString).length)
			textView.setSelectedRange(NSRange(location: safePosition, length: 0))
			textView.scrollRangeToVisible(NSRange(location: safePosition, length: 0))
			textView.window?.makeFirstResponder(textView)

			// Clear the navigation request
			DispatchQueue.main.async {
				self.navigateToPosition = nil
			}
		}

		// Handle focus request
		if requestFocus {
			textView.window?.makeFirstResponder(textView)
			DispatchQueue.main.async {
				self.requestFocus = false
			}
		}

		// Handle text operations (for pipe commands)
		if let operation = pendingTextOperation {
			switch operation {
			case .replaceSelection(let newText, let selectResult):
				let range = textView.selectedRange()
				if let textStorage = textView.textStorage {
					textStorage.replaceCharacters(in: range, with: newText)
					// Select the new text if requested, otherwise place cursor at end
					if selectResult {
						textView.setSelectedRange(NSRange(location: range.location, length: newText.count))
					} else {
						textView.setSelectedRange(NSRange(location: range.location + newText.count, length: 0))
					}
					// Update the binding and refresh gutter
					DispatchQueue.main.async {
						self.text = textView.string
						container.gutterView.refresh()
					}
				}
			case .insertAtCursor(let newText, let selectResult):
				let insertionPoint = textView.selectedRange().location
				if let textStorage = textView.textStorage {
					textStorage.insert(NSAttributedString(string: newText), at: insertionPoint)
					// Select the inserted text if requested, otherwise place cursor at end
					if selectResult {
						textView.setSelectedRange(NSRange(location: insertionPoint, length: newText.count))
					} else {
						textView.setSelectedRange(NSRange(location: insertionPoint + newText.count, length: 0))
					}
					// Update the binding and refresh gutter
					DispatchQueue.main.async {
						self.text = textView.string
						container.gutterView.refresh()
					}
				}
			}
			DispatchQueue.main.async {
				self.pendingTextOperation = nil
			}
		}

		// Store callbacks in coordinator for selection reporting
		context.coordinator.onSelectionChange = onSelectionChange

		context.coordinator.applyTheme(themeManager.currentTheme)

		// Apply settings changes
		container.applySettings(
			showLineNumbers: editorSettings.showLineNumbers,
			wordWrap: editorSettings.wordWrap
		)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	@MainActor
	class Coordinator: NSObject, NSTextViewDelegate, EditorTextViewCompletionDelegate {
		var parent: EditorView
		weak var textView: EditorTextView?
		weak var gutterView: LineNumberGutterView?
		weak var container: EditorContainerView?

		// Selection tracking for pipe commands
		var onSelectionChange: ((String, NSRange) -> Void)?

		// Language service integration
		private let languageCoordinator = LanguageServiceCoordinator()
		private lazy var completionHandler = CompletionHandler(languageCoordinator: languageCoordinator)
		private let diagnosticRenderer = DiagnosticRenderer()
		private var treeSitterHighlighter: TreeSitterHighlighter?
		private var cancellables = Set<AnyCancellable>()
		private var onDiagnosticsUpdate: (([Diagnostic]) -> Void)?
		private var currentLanguage: Language?

		init(_ parent: EditorView) {
			self.parent = parent
			super.init()
			setupDiagnosticsObserver()
		}

		private func setupDiagnosticsObserver() {
			languageCoordinator.$diagnostics
				.receive(on: DispatchQueue.main)
				.sink { [weak self] diagnostics in
					self?.diagnosticRenderer.update(diagnostics: diagnostics)
					self?.onDiagnosticsUpdate?(diagnostics)
				}
				.store(in: &cancellables)
		}

		func configureLanguageService(for language: Language, onDiagnosticsUpdate: (([Diagnostic]) -> Void)?) {
			self.onDiagnosticsUpdate = onDiagnosticsUpdate
			self.currentLanguage = language
			diagnosticRenderer.textView = textView
			textView?.completionDelegate = self

			// Configure completion handler
			if let textView = textView {
				completionHandler.configure(textView: textView)
			}

			// Set up tree-sitter syntax highlighting for supported languages
			if let textView = textView {
				let highlighter = TreeSitterHighlighter(theme: parent.themeManager.currentTheme)
				highlighter.configure(textView: textView, language: language)
				self.treeSitterHighlighter = highlighter
			}

			Task { @MainActor in
				await languageCoordinator.configure(for: language, fileName: nil)

				// Initial content update if we have text
				if let content = textView?.string, !content.isEmpty {
					languageCoordinator.textDidChange(content)
				}
			}
		}

		func textDidChange(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView else { return }
			parent.text = textView.string

			// Update language service
			languageCoordinator.textDidChange(textView.string)

			// Don't hide popover on text change - let user keep typing to filter
			// Popover closes on: Escape, clicking away, or selecting an item
		}

		func textViewDidChangeSelection(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView else { return }
			updateCursorPosition(textView)

			// Report selection for pipe commands
			let range = textView.selectedRange()
			let selectedText = (textView.string as NSString).substring(with: range)
			onSelectionChange?(selectedText, range)

			// Don't auto-hide popover on selection change
			// Arrow keys in completion list shouldn't close it
		}

		private func updateCursorPosition(_ textView: NSTextView) {
			let selectedRange = textView.selectedRange()
			let text = textView.string as NSString

			var line = 1
			var column = 1
			var currentIndex = 0

			text.enumerateSubstrings(
				in: NSRange(location: 0, length: min(selectedRange.location, text.length)),
				options: [.byLines, .substringNotRequired]
			) { _, substringRange, _, _ in
				line += 1
				currentIndex = substringRange.location + substringRange.length
			}

			column = selectedRange.location - currentIndex + 1

			parent.cursorPosition = CursorPosition(line: line, column: column)
		}

		// MARK: - Completion Handling (delegated to CompletionHandler)

		func editorTextViewRequestsCompletion(_ textView: EditorTextView) {
			completionHandler.triggerCompletion()
		}

		func editorTextViewCompletionNavigate(_ textView: EditorTextView, direction: Int) -> Bool {
			guard completionHandler.isPopoverVisible else { return false }
			completionHandler.navigate(direction: direction)
			return true
		}

		func editorTextViewCompletionConfirm(_ textView: EditorTextView) -> Bool {
			guard completionHandler.isPopoverVisible else { return false }
			completionHandler.confirmSelection()
			return true
		}

		func editorTextViewCompletionCancel(_ textView: EditorTextView) -> Bool {
			guard completionHandler.isPopoverVisible else { return false }
			completionHandler.cancel()
			return true
		}

		func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
			// Trigger completion on Ctrl+Space
			if commandSelector == #selector(NSStandardKeyBindingResponding.complete(_:)) {
				completionHandler.triggerCompletion()
				return true
			}

			// Handle completion popup navigation
			if completionHandler.isPopoverVisible {
				switch commandSelector {
				case #selector(NSStandardKeyBindingResponding.moveDown(_:)):
					completionHandler.navigate(direction: 1)
					return true
				case #selector(NSStandardKeyBindingResponding.moveUp(_:)):
					completionHandler.navigate(direction: -1)
					return true
				case #selector(NSStandardKeyBindingResponding.insertNewline(_:)),
					 #selector(NSStandardKeyBindingResponding.insertTab(_:)):
					completionHandler.confirmSelection()
					return true
				case #selector(NSStandardKeyBindingResponding.cancelOperation(_:)):
					completionHandler.cancel()
					return true
				default:
					break
				}
			}

			return false
		}

		func applyTheme(_ theme: Theme) {
			guard let textView = textView else { return }

			textView.backgroundColor = theme.nsBackgroundColor
			textView.insertionPointColor = theme.nsCursorColor
			textView.selectedTextAttributes = [
				.backgroundColor: theme.nsSelectionColor
			]

			// Apply font and foreground color
			let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
			textView.font = font
			textView.textColor = theme.nsForegroundColor

			// Update typing attributes
			textView.typingAttributes = [
				.font: font,
				.foregroundColor: theme.nsForegroundColor
			]

			// Update line number gutter theme
			if let gutterView = gutterView {
				gutterView.gutterBackgroundColor = theme.nsBackgroundColor.blended(withFraction: 0.05, of: .gray) ?? theme.nsBackgroundColor
				gutterView.textColor = theme.nsForegroundColor.withAlphaComponent(0.5)
				gutterView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
				gutterView.needsDisplay = true
			}

			// Update tree-sitter highlighter theme (it manages syntax colors)
			if let highlighter = treeSitterHighlighter {
				highlighter.updateTheme(theme)
			} else {
				// No tree-sitter - apply default foreground color to text
				if let textStorage = textView.textStorage {
					let fullRange = NSRange(location: 0, length: textStorage.length)
					textStorage.addAttributes([
						.font: font,
						.foregroundColor: theme.nsForegroundColor
					], range: fullRange)
				}
			}

			// Re-apply diagnostics after theme change (capture current diagnostics)
			let currentDiagnostics = diagnosticRenderer.diagnostics
			diagnosticRenderer.update(diagnostics: currentDiagnostics)
		}
	}
}
