import AppKit
import SwiftUI

/// Non-activating panel that doesn't steal focus from the editor
final class CompletionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Controller for managing the completion popup using NSPanel (not NSPopover)
/// This approach keeps keyboard focus in the editor while showing completions
final class CompletionPopoverController: NSObject {
    private var panel: CompletionPanel?
    private var tableView: NSTableView?
    private var completions: [CompletionItem] = []
    private var selectedIndex: Int = 0
    private var onSelect: ((CompletionItem) -> Void)?
    private weak var parentView: NSView?

    override init() {
        super.init()
        setupPanel()
    }

    /// Show completions at the specified rect
    func show(
        completions: [CompletionItem],
        relativeTo rect: NSRect,
        in view: NSView,
        onSelect: @escaping (CompletionItem) -> Void
    ) {
        guard !completions.isEmpty else {
            hide()
            return
        }

        self.completions = completions
        self.selectedIndex = 0
        self.onSelect = onSelect
        self.parentView = view

        tableView?.reloadData()
        tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        // Calculate panel size
        let rowHeight = Constants.Completion.rowHeight
        let maxVisibleRows = CGFloat(Constants.Completion.maxVisibleRows)
        let height = min(CGFloat(completions.count), maxVisibleRows) * rowHeight + 4
        let width = Constants.Completion.popoverWidth

        // Convert rect to screen coordinates
        guard let window = view.window else { return }
        let viewRect = view.convert(rect, to: nil)
        let screenRect = window.convertToScreen(viewRect)

        // Position panel below the cursor
        let panelOrigin = NSPoint(
            x: screenRect.origin.x,
            y: screenRect.origin.y - height - 2
        )

        panel?.setFrame(NSRect(origin: panelOrigin, size: NSSize(width: width, height: height)), display: true)
        panel?.orderFront(nil)
    }

    /// Hide the panel
    func hide() {
        panel?.orderOut(nil)
    }

    /// Check if panel is visible
    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Move selection up or down
    func moveSelection(by delta: Int) {
        guard !completions.isEmpty else { return }

        selectedIndex = (selectedIndex + delta + completions.count) % completions.count
        tableView?.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView?.scrollRowToVisible(selectedIndex)
    }

    /// Confirm current selection
    func confirmSelection() {
        guard selectedIndex >= 0, selectedIndex < completions.count else { return }
        let item = completions[selectedIndex]
        hide()
        onSelect?(item)
    }

    private func setupPanel() {
        // Create non-activating panel
        let panel = CompletionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.backgroundColor = .clear

        // Create visual effect background
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 6

        // Create table view
        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.rowHeight = 22
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.refusesFirstResponder = true
        tableView.doubleAction = #selector(handleDoubleClick)
        tableView.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
        column.width = 260
        tableView.addTableColumn(column)

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        // Layout
        visualEffect.frame = NSRect(x: 0, y: 0, width: 280, height: 200)
        visualEffect.autoresizingMask = [.width, .height]

        scrollView.frame = NSRect(x: 2, y: 2, width: 276, height: 196)
        scrollView.autoresizingMask = [.width, .height]

        visualEffect.addSubview(scrollView)
        panel.contentView = visualEffect

        self.panel = panel
        self.tableView = tableView
    }

    @objc private func handleDoubleClick() {
        confirmSelection()
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource

extension CompletionPopoverController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        completions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = completions[row]

        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("CompletionCell")

        // Icon
        let imageView = NSImageView()
        if let image = NSImage(systemSymbolName: item.kind.symbolName, accessibilityDescription: item.kind.rawValue) {
            imageView.image = image
            imageView.contentTintColor = item.kind.color
        }
        imageView.frame = NSRect(x: 4, y: 3, width: 16, height: 16)

        // Label
        let textField = NSTextField(labelWithString: item.label)
        textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textField.textColor = .labelColor
        textField.frame = NSRect(x: 24, y: 2, width: 230, height: 18)
        textField.lineBreakMode = .byTruncatingTail

        cellView.addSubview(imageView)
        cellView.addSubview(textField)
        cellView.imageView = imageView
        cellView.textField = textField

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView, tableView.selectedRow >= 0 {
            selectedIndex = tableView.selectedRow
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }
}
