#if DEBUG
import AppKit

/// Debug-only: when VEIL_SNAPSHOT_DIR is set, renders every settings pane and the
/// menu bar panel to PNG files (no screen-recording permission needed), then quits.
/// Used to review the UI from the command line; compiled out of release builds.
@MainActor
enum DebugSnapshots {
    static func runIfRequested(settings: SettingsWindowController, statusBar: StatusBarController, model: AppModel) {
        guard let dir = ProcessInfo.processInfo.environment["VEIL_SNAPSHOT_DIR"] else { return }
        let root = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            print("state: load=\(model.loadState) hotKeyError=\(model.hotKeyError ?? "none") displays=\(model.displays.map(\.name)) info=\(model.videoInfo?.summary ?? "nil")")
            await captureAll(prefix: "", settings: settings, statusBar: statusBar, root: root)

            model.removeVideo()
            try? await Task.sleep(for: .milliseconds(300))
            await captureAll(prefix: "empty-", settings: settings, statusBar: statusBar, root: root, tabs: [.video])

            NSApp.terminate(nil)
        }
    }

    private static func captureAll(prefix: String,
                                   settings: SettingsWindowController,
                                   statusBar: StatusBarController,
                                   root: URL,
                                   tabs: [SettingsTab] = SettingsTab.allCases) async {
        for tab in tabs {
            settings.show(tab: tab)
            try? await Task.sleep(for: .milliseconds(800))
            if let frame = settings.window?.contentView?.superview {
                write(frame, to: root.appendingPathComponent("\(prefix)settings-\(tab.title.lowercased()).png"))
            }
        }
        settings.window?.orderOut(nil)

        if let view = statusBar.presentPopoverForSnapshot() {
            try? await Task.sleep(for: .milliseconds(800))
            write(view, to: root.appendingPathComponent("\(prefix)popover.png"))
            statusBar.closePopover()
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    private static func write(_ view: NSView, to url: URL) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])?.write(to: url)
        print("snapshot:", url.lastPathComponent, Int(view.bounds.width), "x", Int(view.bounds.height))
    }
}
#endif
