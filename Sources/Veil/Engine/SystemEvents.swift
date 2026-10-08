import AppKit

/// Watches for screen lock, sleep and display-configuration changes.
@MainActor
final class SystemEvents {
    /// Called with `true` while the screen is locked or asleep.
    var onSuspendStateChange: ((Bool) -> Void)?
    var onScreensChanged: (() -> Void)?

    private var isLocked = false
    private var isAsleep = false
    private var lastPublished: Bool?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var screenTask: Task<Void, Never>?

    func start() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        let app = NotificationCenter.default

        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.isLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.isLocked = false }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.isAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.isAsleep = false }
        observe(workspace, NSWorkspace.willSleepNotification) { $0.isAsleep = true }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.isAsleep = false }
        observe(app, NSApplication.didChangeScreenParametersNotification) { $0.screensChanged() }
    }

    deinit {
        for (center, token) in observers { center.removeObserver(token) }
    }

    private func observe(_ center: NotificationCenter,
                         _ name: Notification.Name,
                         _ handler: @escaping @MainActor (SystemEvents) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
                self.publish()
            }
        }
        observers.append((center, token))
    }

    private func publish() {
        let suspended = isLocked || isAsleep
        guard suspended != lastPublished else { return }
        lastPublished = suspended
        onSuspendStateChange?(suspended)
    }

    /// Display changes arrive in bursts; coalesce them.
    private func screensChanged() {
        screenTask?.cancel()
        screenTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.onScreensChanged?()
        }
    }
}
