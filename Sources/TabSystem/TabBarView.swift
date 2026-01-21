import SwiftUI

/// Tab bar displaying all open tabs
struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            // Space for traffic light buttons
            Color.clear
                .frame(width: 76)

            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            tab: tab,
                            isActive: index == tabManager.activeTabIndex,
                            onSelect: { tabManager.selectTab(at: index) },
                            onClose: { tabManager.closeTab(at: index) }
                        )
                    }
                }
            }

            Spacer()

            // New tab button
            Button(action: { tabManager.createNewTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(themeManager.currentTheme.backgroundColor)
    }
}

/// Individual tab item in the tab bar
struct TabItemView: View {
    let tab: TabDocument
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // File icon
            Image(systemName: iconForLanguage(tab.language))
                .font(.system(size: 11))
                .foregroundColor(iconColor)

            // File name
            Text(tab.displayName)
                .font(.system(size: 12))
                .foregroundColor(textColor)
                .lineLimit(1)

            // Dirty indicator or close button
            Button(action: onClose) {
                ZStack {
                    // Dirty indicator (when not hovering)
                    if tab.isDirty && !isHovering {
                        Circle()
                            .fill(themeManager.currentTheme.syntaxKeyword)
                            .frame(width: 8, height: 8)
                    }

                    // Close button (always visible on hover, or when not dirty)
                    if isHovering || !tab.isDirty {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(
                                isHovering
                                    ? themeManager.currentTheme.foregroundColor
                                    : themeManager.currentTheme.foregroundColor.opacity(0.4)
                            )
                    }
                }
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isActive ? themeManager.currentTheme.syntaxKeyword.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .onTapGesture { onSelect() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isActive {
            return themeManager.currentTheme.backgroundColor
        } else if isHovering {
            return themeManager.currentTheme.currentLineBackground
        } else {
            return themeManager.currentTheme.statusBarBackground.opacity(0.5)
        }
    }

    private var textColor: Color {
        if isActive {
            return themeManager.currentTheme.foregroundColor
        } else {
            return themeManager.currentTheme.foregroundColor.opacity(0.8)
        }
    }

    private var iconColor: Color {
        if isActive {
            return themeManager.currentTheme.syntaxKeyword
        } else {
            return themeManager.currentTheme.foregroundColor.opacity(0.6)
        }
    }

    private func iconForLanguage(_ language: Language) -> String {
        switch language {
        case .swift: return "swift"
        case .python: return "p.square"
        case .javascript, .typescript: return "j.square"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .css: return "paintbrush"
        case .json: return "curlybraces"
        case .markdown: return "doc.text"
        case .bash: return "terminal"
        case .c, .cpp: return "c.square"
        case .rust: return "gear"
        case .go: return "g.square"
        case .ruby: return "diamond"
        default: return "doc"
        }
    }
}
