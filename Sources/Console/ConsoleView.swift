import SwiftUI

/// Bottom panel console view
struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    let onEscape: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var consoleHeight: CGFloat = 200
    @State private var requestInputFocus: Bool = true

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            ResizeHandle(height: $consoleHeight, minHeight: minHeight, maxHeight: maxHeight)

            // Output area
            ConsoleOutputView(
                lines: viewModel.outputLines,
                onPathClick: { path, line, column in
                    viewModel.handlePathClick(path: path, line: line, column: column)
                }
            )
            .environmentObject(themeManager)
            .frame(height: consoleHeight)

            Divider()
                .background(themeManager.currentTheme.lineNumberColor.opacity(0.3))

            // Input area
            ConsoleInputView(
                text: $viewModel.inputText,
                requestFocus: $requestInputFocus,
                mode: viewModel.inputMode,
                workingDirectory: viewModel.workingDirectory,
                onSubmit: { viewModel.processInput() },
                onHistoryUp: { viewModel.navigateHistoryUp() },
                onHistoryDown: { viewModel.navigateHistoryDown() },
                onEscape: onEscape
            )
            .environmentObject(themeManager)
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
}

/// Resize handle for the console
struct ResizeHandle: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 6)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(isDragging ? 0.6 : 0.3))
                    .frame(width: 40, height: 4)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height - value.translation.height
                        height = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

/// Console output view using NSTextView for native text selection
struct ConsoleOutputView: NSViewRepresentable {
    let lines: [ConsoleLine]
    let onPathClick: (String, Int?, Int?) -> Void

    @EnvironmentObject var themeManager: ThemeManager

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = ConsoleTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(themeManager.currentTheme.backgroundColor.opacity(0.5))
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Store callback for path clicks
        textView.onPathClick = onPathClick

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ConsoleTextView else { return }

        textView.backgroundColor = NSColor(themeManager.currentTheme.backgroundColor.opacity(0.5))
        textView.onPathClick = onPathClick

        // Only rebuild content if lines actually changed
        guard lines.count != context.coordinator.lastLineCount else { return }
        context.coordinator.lastLineCount = lines.count

        // Build attributed string from lines
        let attributedString = buildAttributedString()
        let previousLength = textView.textStorage?.length ?? 0

        textView.textStorage?.setAttributedString(attributedString)

        // Auto-scroll to bottom if new content was added
        if attributedString.length > previousLength {
            textView.scrollToEndOfDocument(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var textView: ConsoleTextView?
        weak var scrollView: NSScrollView?
        var lastLineCount: Int = 0
    }

    private func buildAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let theme = themeManager.currentTheme

        for (index, line) in lines.enumerated() {
            for segment in line.segments {
                let color = colorForSegment(segment, lineKind: line.kind, theme: theme)
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor(color)
                ]

                // Add link attribute for clickable paths
                if let action = segment.action {
                    switch action {
                    case .openFile(let path, let lineNum, let column):
                        // Encode path info as a custom URL
                        var urlString = "temperedit://open?path=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path)"
                        if let lineNum = lineNum {
                            urlString += "&line=\(lineNum)"
                        }
                        if let column = column {
                            urlString += "&column=\(column)"
                        }
                        if let url = URL(string: urlString) {
                            attributes[.link] = url
                            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                        }
                    default:
                        break
                    }
                }

                result.append(NSAttributedString(string: segment.text, attributes: attributes))
            }

            // Add newline between lines (except for last line)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor(theme.foregroundColor)
                ]))
            }
        }

        return result
    }

    private func colorForSegment(_ segment: ConsoleLineSegment, lineKind: ConsoleLine.Kind, theme: Theme) -> Color {
        switch segment.style {
        case .plain:
            switch lineKind {
            case .stderr:
                return theme.syntaxError
            default:
                return theme.foregroundColor
            }
        case .prompt:
            return theme.syntaxKeyword
        case .command:
            return theme.foregroundColor
        case .path:
            return theme.syntaxFunction
        case .error:
            return theme.syntaxError
        case .warning:
            return theme.syntaxConstant
        case .success:
            return theme.syntaxString
        case .link:
            return theme.syntaxFunction
        case .ansi(let foreground, _, _, _):
            return foreground ?? theme.foregroundColor
        }
    }
}

/// Custom NSTextView that handles link clicks
class ConsoleTextView: NSTextView, NSTextViewDelegate {
    var onPathClick: ((String, Int?, Int?) -> Void)?

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        self.delegate = self
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
    }

    // Handle link clicks via delegate
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL, url.scheme == "temperedit" {
            // Parse our custom URL
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let pathItem = components.queryItems?.first(where: { $0.name == "path" }),
               let path = pathItem.value?.removingPercentEncoding {

                let line = components.queryItems?.first(where: { $0.name == "line" })?.value.flatMap { Int($0) }
                let column = components.queryItems?.first(where: { $0.name == "column" })?.value.flatMap { Int($0) }

                onPathClick?(path, line, column)
                return true
            }
        }
        return false
    }
}

/// Console input area
struct ConsoleInputView: View {
    @Binding var text: String
    @Binding var requestFocus: Bool
    let mode: ConsoleInputMode
    let workingDirectory: URL
    let onSubmit: () -> Void
    let onHistoryUp: () -> Void
    let onHistoryDown: () -> Void
    let onEscape: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            // Prompt
            Text(promptText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.syntaxKeyword)

            // Input field
            ConsoleTextField(
                text: $text,
                requestFocus: $requestFocus,
                onSubmit: onSubmit,
                onHistoryUp: onHistoryUp,
                onHistoryDown: onHistoryDown,
                onEscape: onEscape
            )
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(themeManager.currentTheme.foregroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.currentTheme.backgroundColor.opacity(0.3))
    }

    private var promptText: String {
        switch mode {
        case .shell:
            return "$"
        case .editorCommand, .lineNavigation:
            return ":"
        case .symbolSearch:
            return "@"
        case .quickOpen:
            return ">"
        }
    }
}

/// Custom text field for console input with key handling
struct ConsoleTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var requestFocus: Bool
    let onSubmit: () -> Void
    let onHistoryUp: () -> Void
    let onHistoryDown: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.stringValue = text
        field.isBordered = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        field.textColor = NSColor(ThemeManager.shared.currentTheme.foregroundColor)

        // Focus on creation
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // Handle focus request
        if requestFocus {
            nsView.window?.makeFirstResponder(nsView)
            DispatchQueue.main.async {
                self.requestFocus = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ConsoleTextField

        init(_ parent: ConsoleTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onHistoryUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onHistoryDown()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            default:
                return false
            }
        }
    }
}

