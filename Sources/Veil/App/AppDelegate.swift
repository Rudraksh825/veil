import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate? { NSApp.delegate as? AppDelegate }

    private(set) var model: AppModel?
    private var statusBar: StatusBarController?
    private var settings: SettingsWindowController?
    private var pendingURLs: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model

        applyActivationPolicy(model)
        observeDockPreference(model)

        settings = SettingsWindowController(model: model)
        statusBar = StatusBarController(model: model)
        model.start()

        if let url = pendingURLs.first {
            pendingURLs.removeAll()
            model.loadVideo(url)
        } else if model.videoURL == nil {
            // First run: guide the user straight to picking a video.
            showSettings(tab: .video)
        }

        #if DEBUG
        if let settings, let statusBar {
            DebugSnapshots.runIfRequested(settings: settings, statusBar: statusBar, model: model)
        }
        #endif
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let model else { pendingURLs = urls; return }
        if let url = urls.first(where: VideoDrop.isVideo) {
            model.loadVideo(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(tab: nil)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Settings

    func showSettings(tab: SettingsTab?) {
        statusBar?.closePopover()
        settings?.show(tab: tab)
    }

    @objc func showSettingsAction(_ sender: Any?) {
        showSettings(tab: nil)
    }

    // MARK: - Dock icon

    private func observeDockPreference(_ model: AppModel) {
        withObservationTracking {
            _ = model.showInDock
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyActivationPolicy(model)
                self.observeDockPreference(model)
            }
        }
    }

    private func applyActivationPolicy(_ model: AppModel) {
        let policy: NSApplication.ActivationPolicy = model.showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Switching policy briefly deactivates the app; bring the settings window back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let window = self?.settings?.window, window.isVisible else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
