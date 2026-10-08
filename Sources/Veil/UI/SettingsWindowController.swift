import AppKit
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case video, appearance, playback, general

    var title: String {
        switch self {
        case .video: "Video"
        case .appearance: "Appearance"
        case .playback: "Playback"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .video: "film"
        case .appearance: "paintbrush.pointed"
        case .playback: "play.circle"
        case .general: "gearshape"
        }
    }

    var size: NSSize {
        switch self {
        case .video: NSSize(width: 540, height: 420)
        case .appearance: NSSize(width: 540, height: 500)
        case .playback: NSSize(width: 540, height: 440)
        case .general: NSSize(width: 540, height: 500)
        }
    }
}

/// A classic toolbar-tabbed settings window whose panes are SwiftUI views.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let tabs = SettingsTabViewController()
    private var hasShown = false

    init(model: AppModel) {
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: Self.pane(for: tab, model: model))
            host.title = tab.title // NSTabViewController mirrors this into the window title
            host.preferredContentSize = tab.size
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Veil"
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 320)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(tab: SettingsTab?) {
        guard let window else { return }
        if let tab { tabs.selectedTabViewItemIndex = tab.rawValue }
        if !hasShown {
            hasShown = true
            tabs.applySize(animated: false)
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @ViewBuilder
    private static func pane(for tab: SettingsTab, model: AppModel) -> some View {
        switch tab {
        case .video: VideoPane(model: model)
        case .appearance: AppearancePane(model: model)
        case .playback: PlaybackPane(model: model)
        case .general: GeneralPane(model: model)
        }
    }
}

private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        applySize(animated: true)
    }

    /// Resizes the window to the selected pane, keeping the top-left corner anchored.
    func applySize(animated: Bool) {
        guard let window = view.window, selectedTabViewItemIndex >= 0 else { return }
        let item = tabViewItems[selectedTabViewItemIndex]
        window.title = item.label
        guard let size = item.viewController?.preferredContentSize, size != .zero else { return }

        let current = window.frame
        var target = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        target.origin = NSPoint(x: current.minX, y: current.maxY - target.height)
        window.setFrame(target, display: true, animate: animated)
    }
}
