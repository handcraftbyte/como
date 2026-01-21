import SwiftUI

@main
struct ComoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var appState = AppState.shared
    @StateObject private var tabManager = TabManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(appState)
                .environmentObject(tabManager)
                .onOpenURL { url in
                    // Handle file open requests
                    try? tabManager.openFile(at: url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // File commands
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    tabManager.createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Open...") {
                    openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Close Tab") {
                    tabManager.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveActiveTab()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    saveActiveTabAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Toggle Console") {
                    appState.showConsole.toggle()
                }
                .keyboardShortcut("`", modifiers: .command)

                Divider()

                Button("Next Tab") {
                    tabManager.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    tabManager.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                Menu("Theme") {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Button(theme.displayName) {
                            themeManager.currentTheme = theme
                        }
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(themeManager)
        }
    }

    // MARK: - File Operations

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = TextDocument.readableContentTypes

        if panel.runModal() == .OK {
            for url in panel.urls {
                try? tabManager.openFile(at: url)
            }
        }
    }

    private func saveActiveTab() {
        guard let tab = tabManager.activeTab else { return }

        if tab.fileURL != nil {
            try? tabManager.saveActiveTab()
        } else {
            saveActiveTabAs()
        }
    }

    private func saveActiveTabAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = TextDocument.readableContentTypes
        panel.canCreateDirectories = true

        if let activeTab = tabManager.activeTab {
            panel.nameFieldStringValue = activeTab.displayName
        }

        if panel.runModal() == .OK, let url = panel.url {
            try? tabManager.saveActiveTabAs(to: url)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the app and bring it to foreground
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Configure app appearance
        NSApp.appearance = ThemeManager.shared.nsAppearance

        // Configure window for seamless appearance
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(ThemeManager.shared.currentTheme.backgroundColor)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle file open via Finder
        for url in urls {
            try? AppState.shared.tabManager?.openFile(at: url)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showSettings = false
    @Published var showConsole = false

    // Reference to tab manager for file opening from AppDelegate
    weak var tabManager: TabManager?

    private init() {}
}
