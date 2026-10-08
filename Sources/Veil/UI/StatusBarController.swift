import AppKit
import Observation
import SwiftUI

/// Menu bar icon: click for the control panel, right-click for a quick menu,
/// ⌥-click to toggle the overlay without opening anything.
@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let item: NSStatusItem
    private let popover = NSPopover()

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(rootView: MenuPanelView(model: model))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Veil — click for controls, ⌥-click to toggle the overlay"
        }
        observeState()
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    #if DEBUG
    /// Shows the panel and returns its content view so DebugSnapshots can render it.
    func presentPopoverForSnapshot() -> NSView? {
        guard let button = item.button else { return nil }
        popover.appearance = NSAppearance(named: .aqua) // opaque light text for offscreen rendering
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        return popover.contentViewController?.view
    }
    #endif

    // MARK: - Icon

    private func observeState() {
        withObservationTracking {
            updateIcon()
        } onChange: {
            Task { @MainActor [weak self] in self?.observeState() }
        }
    }

    private func updateIcon() {
        let hasVideo = model.videoURL != nil
        let visible = model.isOverlayVisible && hasVideo
        let playing = visible && model.isPlaying && !model.isSuspended

        let name: String
        let description: String
        switch (visible, playing) {
        case (true, true): (name, description) = ("play.rectangle.on.rectangle.fill", "Veil: playing")
        case (true, false): (name, description) = ("rectangle.on.rectangle", "Veil: paused")
        default: (name, description) = ("rectangle.on.rectangle.slash", "Veil: hidden")
        }

        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
            ?? NSImage(systemSymbolName: "film", accessibilityDescription: description)
        image?.isTemplate = true
        item.button?.image = image
        item.button?.appearsDisabled = !visible
    }

    // MARK: - Clicks

    @objc private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { togglePopover(); return }
        if event.type == .rightMouseUp {
            showQuickMenu()
        } else if event.modifierFlags.contains(.option) {
            model.toggleOverlay()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = item.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showQuickMenu() {
        let menu = NSMenu()
        let hasVideo = model.videoURL != nil

        let toggle = menu.addItem(withTitle: model.isOverlayVisible ? "Hide Overlay" : "Show Overlay",
                                  action: #selector(toggleOverlay), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = hasVideo

        let play = menu.addItem(withTitle: model.isPlaying ? "Pause" : "Play",
                                action: #selector(togglePlayback), keyEquivalent: "")
        play.target = self
        play.isEnabled = hasVideo

        menu.addItem(.separator())
        menu.addItem(withTitle: "Choose Video…", action: #selector(chooseVideo), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Veil", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func toggleOverlay() { model.toggleOverlay() }
    @objc private func togglePlayback() { model.togglePlayback() }
    @objc private func chooseVideo() { model.chooseVideo() }
    @objc private func openSettings() { AppDelegate.shared?.showSettings(tab: nil) }
}
