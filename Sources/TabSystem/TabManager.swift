import SwiftUI
import Combine

/// Manages multiple tabs within a single window
@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [TabDocument] = []
    @Published var activeTabIndex: Int = 0

    /// The currently active tab, if any
    var activeTab: TabDocument? {
        guard tabs.indices.contains(activeTabIndex) else { return nil }
        return tabs[activeTabIndex]
    }

    /// Binding to the active tab's text for editor integration
    var activeTextBinding: Binding<String> {
        Binding(
            get: { [weak self] in
                self?.activeTab?.text ?? ""
            },
            set: { [weak self] newValue in
                guard let self = self,
                      self.tabs.indices.contains(self.activeTabIndex) else { return }
                if self.tabs[self.activeTabIndex].text != newValue {
                    self.tabs[self.activeTabIndex].text = newValue
                    self.tabs[self.activeTabIndex].isDirty = true
                }
            }
        )
    }

    /// Binding to the active tab's language
    var activeLanguageBinding: Binding<Language> {
        Binding(
            get: { [weak self] in
                self?.activeTab?.language ?? .plainText
            },
            set: { [weak self] newValue in
                guard let self = self,
                      self.tabs.indices.contains(self.activeTabIndex) else { return }
                self.tabs[self.activeTabIndex].language = newValue
            }
        )
    }

    init() {
        // Start with one empty tab
        createNewTab()
    }

    // MARK: - Tab Operations

    /// Create a new empty tab and make it active
    func createNewTab() {
        let tab = TabDocument.newUntitled()
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
    }

    /// Open a file in a new tab (or switch to existing tab if already open)
    func openFile(at url: URL) throws {
        // Check if file is already open
        if let existingIndex = tabs.firstIndex(where: { $0.fileURL == url }) {
            activeTabIndex = existingIndex
            return
        }

        let tab = try TabDocument.load(from: url)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
    }

    /// Open a file at a specific line number
    func openFile(at url: URL, line: Int?, column: Int? = nil) throws {
        try openFile(at: url)

        // Navigate to line if specified
        if let line = line,
           tabs.indices.contains(activeTabIndex) {
            tabs[activeTabIndex].cursorPosition = CursorPosition(
                line: line,
                column: column ?? 1
            )
        }
    }

    /// Close the tab at the given index
    func closeTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }

        // Check for unsaved changes
        let tab = tabs[index]
        if tab.isDirty {
            // For now, just close. In production, would show save dialog
        }

        tabs.remove(at: index)

        // Adjust active index
        if tabs.isEmpty {
            createNewTab()
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        }
    }

    /// Close the currently active tab
    func closeActiveTab() {
        closeTab(at: activeTabIndex)
    }

    /// Select the tab at the given index
    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabIndex = index
    }

    /// Select the next tab (wraps around)
    func selectNextTab() {
        guard !tabs.isEmpty else { return }
        activeTabIndex = (activeTabIndex + 1) % tabs.count
    }

    /// Select the previous tab (wraps around)
    func selectPreviousTab() {
        guard !tabs.isEmpty else { return }
        activeTabIndex = (activeTabIndex - 1 + tabs.count) % tabs.count
    }

    // MARK: - Save Operations

    /// Save the active tab
    func saveActiveTab() throws {
        guard tabs.indices.contains(activeTabIndex) else { return }

        if tabs[activeTabIndex].fileURL != nil {
            try tabs[activeTabIndex].save()
        } else {
            // Would trigger Save As dialog
            throw CocoaError(.fileNoSuchFile)
        }
    }

    /// Save the active tab to a new location
    func saveActiveTabAs(to url: URL) throws {
        guard tabs.indices.contains(activeTabIndex) else { return }
        try tabs[activeTabIndex].save(to: url)
    }

    /// Check if any tabs have unsaved changes
    var hasUnsavedChanges: Bool {
        tabs.contains { $0.isDirty }
    }

    // MARK: - Cursor Position

    /// Update cursor position for the active tab
    func updateCursorPosition(_ position: CursorPosition) {
        guard tabs.indices.contains(activeTabIndex) else { return }
        tabs[activeTabIndex].cursorPosition = position
    }
}
