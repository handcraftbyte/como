import SwiftUI
import Foundation

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabManager: TabManager
    @State private var cursorPosition: CursorPosition = .init(line: 1, column: 1)
    @State private var diagnostics: [Diagnostic] = []
    @State private var showDiagnosticsPanel: Bool = false
    @State private var editorKey: UUID = UUID()
    @State private var navigateToPosition: Int? = nil
    @State private var requestEditorFocus: Bool = false
    @State private var pendingTextOperation: TextOperation? = nil
    @State private var currentSelection: String = ""
    @State private var currentSelectionRange: NSRange = NSRange(location: 0, length: 0)
    @StateObject private var consoleViewModel = ConsoleViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(tabManager: tabManager)
                .environmentObject(themeManager)

                // Editor for active tab
                if let activeTab = tabManager.activeTab {
                    EditorView(
                        text: tabManager.activeTextBinding,
                        language: activeTab.language,
                        cursorPosition: $cursorPosition,
                        navigateToPosition: $navigateToPosition,
                        requestFocus: $requestEditorFocus,
                        pendingTextOperation: $pendingTextOperation,
                        onSelectionChange: { text, range in
                            currentSelection = text
                            currentSelectionRange = range
                        },
                        onDiagnosticsUpdate: { newDiagnostics in
                            diagnostics = newDiagnostics
                        }
                    )
                    .id(editorKey)
                    .environmentObject(themeManager)
                } else {
                    // Empty state
                    VStack {
                        Spacer()
                        Text("No file open")
                            .font(.title2)
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                        Text("Press Cmd+T to create a new tab or Cmd+O to open a file")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.3))
                        Spacer()
                    }
                }

                // Diagnostics panel (collapsible)
                if showDiagnosticsPanel {
                    Divider()
                    DiagnosticsPanel(
                        diagnostics: diagnostics,
                        onDiagnosticClick: { diagnostic in
                            navigateToPosition = diagnostic.range.lowerBound
                        }
                    )
                    .environmentObject(themeManager)
                }

                // Console panel (toggled with Cmd+`)
                if appState.showConsole {
                    Divider()
                    ConsoleView(viewModel: consoleViewModel, onEscape: {
                        appState.showConsole = false
                    })
                        .environmentObject(themeManager)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                StatusBar(
                    language: tabManager.activeTab?.language ?? .plainText,
                    cursorPosition: cursorPosition,
                    encoding: "UTF-8",
                    lineEnding: "LF",
                    errorCount: diagnostics.filter { $0.severity == .error }.count,
                    warningCount: diagnostics.filter { $0.severity == .warning }.count,
                    showDiagnosticsPanel: $showDiagnosticsPanel
                )
        }
        .background(themeManager.currentTheme.backgroundColor)
        .ignoresSafeArea()
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            // Register tab manager with AppState for external file opening
            appState.tabManager = tabManager
            // Connect console to tab manager
            consoleViewModel.tabManager = tabManager
            // Connect selection callback for pipe commands
            consoleViewModel.getSelection = { [self] in
                currentSelection
            }
        }
        .onChange(of: tabManager.activeTabIndex) { _, _ in
            // Reset state when switching tabs
            editorKey = UUID()
            diagnostics = []
            if let tab = tabManager.activeTab {
                cursorPosition = tab.cursorPosition
            }
        }
        .onChange(of: tabManager.activeTab?.language) { _, _ in
            // Force editor recreation to reconfigure language service
            editorKey = UUID()
            diagnostics = []
        }
        .onChange(of: cursorPosition) { _, newPosition in
            // Sync cursor position back to tab
            tabManager.updateCursorPosition(newPosition)
        }
        .onReceive(consoleViewModel.$pendingNavigation) { action in
            // Handle navigation from console commands
            if let action = action {
                handleNavigation(action)
                Task { @MainActor in
                    consoleViewModel.pendingNavigation = nil
                }
            }
        }
        .onReceive(consoleViewModel.$pendingTextOperation) { operation in
            // Handle text operations from pipe commands
            if let operation = operation {
                pendingTextOperation = operation
                Task { @MainActor in
                    consoleViewModel.pendingTextOperation = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.showConsole)
        .onChange(of: appState.showConsole) { _, isShowing in
            // Focus editor when console is hidden
            if !isShowing {
                requestEditorFocus = true
            }
        }
    }

    // MARK: - Line Navigation Helpers

    private func offsetForLine(_ line: Int, in text: String) -> Int {
        var currentLine = 1
        for (index, char) in text.enumerated() {
            if currentLine == line { return index }
            if char == "\n" { currentLine += 1 }
        }
        return text.count
    }

    private func handleNavigation(_ action: NavigationAction) {
        guard let text = tabManager.activeTab?.text else { return }

        switch action {
        case .line(let line):
            navigateToPosition = offsetForLine(line, in: text)
        case .offset(let offset):
            navigateToPosition = offset
        case .position(let line, _):
            navigateToPosition = offsetForLine(line, in: text)
        }
    }
}

struct CursorPosition: Equatable {
    var line: Int
    var column: Int

    var displayString: String {
        "Ln \(line), Col \(column)"
    }
}
