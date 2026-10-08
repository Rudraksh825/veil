import AppKit
import AVFoundation

/// Owns the looping player and one click-through window per target display.
/// Every AVPlayerLayer shares the single player, so multi-display playback stays in sync
/// and the video is decoded only once.
@MainActor
final class OverlayEngine {
    enum Status {
        case ready
        case failed(String)
    }

    var onStatus: ((Status) -> Void)?

    let player = AVQueuePlayer()

    // MARK: - Configuration (applied immediately)

    var isVisible = false {
        didSet { applyVisibility(animated: true); applyPlayback() }
    }

    var isPlaying = false {
        didSet { applyPlayback() }
    }

    var isSuspended = false {
        didSet { applyPlayback() }
    }

    var opacity: Double = 0.15 {
        didSet {
            guard effectiveVisible else { return }
            windows.forEach { $0.alphaValue = opacity }
        }
    }

    var saturation: Double = 1 {
        didSet { applyFilters() }
    }

    var blur: Double = 0 {
        didSet { applyFilters() }
    }

    var scaling: ScalingMode = .fill {
        didSet { windows.forEach { $0.host.playerLayer.videoGravity = scaling.gravity } }
    }

    var layering: OverlayLayering = .aboveEverything {
        didSet { windows.forEach { $0.level = layering.windowLevel } }
    }

    var targetDisplayID: UInt32 = 0 {
        didSet { syncWindowsToScreens() }
    }

    var excludeFromCapture = false {
        didSet { windows.forEach { $0.sharingType = excludeFromCapture ? .none : .readOnly } }
    }

    var speed: Double = 1 {
        didSet {
            let rate = Float(speed)
            player.defaultRate = rate
            if player.rate != 0 { player.rate = rate }
        }
    }

    var volume: Double = 0.3 {
        didSet { player.volume = Float(volume) }
    }

    var isMuted = false {
        didSet { player.isMuted = isMuted }
    }

    // MARK: - Private state

    private var windows: [OverlayWindow] = []
    private var looper: AVPlayerLooper?
    private var looperObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var loadGeneration = 0
    private var visibilityGeneration = 0

    private var hasMedia = false {
        didSet {
            guard oldValue != hasMedia else { return }
            applyVisibility(animated: true)
            applyPlayback()
        }
    }

    private var effectiveVisible: Bool { isVisible && hasMedia }

    init() {
        // An ambient overlay must never keep the display awake or hijack AirPlay.
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = Float(volume)
    }

    // MARK: - Media

    func load(url: URL) {
        unload()
        loadGeneration += 1
        let generation = loadGeneration
        let asset = AVURLAsset(url: url)

        Task { @MainActor [weak self] in
            let playable: Bool
            do {
                playable = try await asset.load(.isPlayable)
            } catch {
                guard let self, generation == self.loadGeneration else { return }
                self.onStatus?(.failed(error.localizedDescription))
                return
            }
            guard let self, generation == self.loadGeneration else { return }
            guard playable else {
                self.onStatus?(.failed("This video format isn't supported by macOS."))
                return
            }
            self.attach(asset: asset)
        }
    }

    func unload() {
        loadGeneration += 1
        hasMedia = false
        looperObservation = nil
        currentItemObservation = nil
        itemStatusObservation = nil
        looper?.disableLooping()
        looper = nil
        player.pause()
        player.removeAllItems()
    }

    private func attach(asset: AVAsset) {
        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .spectral // keeps pitch natural at non-1× speeds

        let looper = AVPlayerLooper(player: player, templateItem: item)
        self.looper = looper

        looperObservation = looper.observe(\.status, options: [.initial, .new]) { [weak self] looper, _ in
            Task { @MainActor [weak self] in self?.looperStatusChanged(looper) }
        }
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in self?.currentItemChanged(player.currentItem) }
        }
    }

    private func looperStatusChanged(_ looper: AVPlayerLooper) {
        guard looper === self.looper else { return }
        switch looper.status {
        case .ready:
            hasMedia = true
            onStatus?(.ready)
            applyPlayback()
        case .failed:
            onStatus?(.failed(looper.error?.localizedDescription ?? "The video couldn't be played."))
        default:
            break
        }
    }

    private func currentItemChanged(_ item: AVPlayerItem?) {
        itemStatusObservation = item?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "The video couldn't be played."
            Task { @MainActor [weak self] in self?.onStatus?(.failed(message)) }
        }
    }

    // MARK: - Playback

    private func applyPlayback() {
        let shouldPlay = hasMedia && isVisible && isPlaying && !isSuspended
        if shouldPlay {
            if player.rate == 0 { player.rate = Float(speed) }
        } else if player.rate != 0 {
            player.pause()
        }
    }

    // MARK: - Windows

    /// Reconciles windows with the current display set without flashing if nothing changed.
    func syncWindowsToScreens() {
        let screens = targetScreens()
        if screens.map(\.displayID) == windows.map(\.displayID) {
            for (window, screen) in zip(windows, screens) {
                window.setFrame(screen.frame, display: true)
            }
            return
        }
        rebuildWindows(for: screens)
    }

    private func rebuildWindows(for screens: [NSScreen]) {
        let old = windows
        windows = screens.map { OverlayWindow(screen: $0, player: player) }
        for window in windows { configure(window) }

        for window in old {
            window.orderOut(nil)
            window.host.playerLayer.player = nil
            window.close()
        }
        applyVisibility(animated: true)
    }

    private func configure(_ window: OverlayWindow) {
        window.level = layering.windowLevel
        window.sharingType = excludeFromCapture ? .none : .readOnly
        window.host.playerLayer.videoGravity = scaling.gravity
        window.host.setFilters(saturation: saturation, blur: blur)
    }

    private func targetScreens() -> [NSScreen] {
        let all = NSScreen.screens
        guard targetDisplayID != 0,
              let chosen = all.first(where: { $0.displayID == targetDisplayID }) else { return all }
        return [chosen]
    }

    private func applyFilters() {
        windows.forEach { $0.host.setFilters(saturation: saturation, blur: blur) }
    }

    private func applyVisibility(animated: Bool) {
        visibilityGeneration += 1
        let generation = visibilityGeneration

        if effectiveVisible {
            for window in windows where !window.isVisible {
                window.alphaValue = 0
                window.orderFrontRegardless()
            }
            fade(to: opacity, animated: animated)
        } else {
            fade(to: 0, animated: animated) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, generation == self.visibilityGeneration else { return }
                    self.windows.forEach { $0.orderOut(nil) }
                }
            }
        }
    }

    private func fade(to alpha: Double, animated: Bool, completion: (@Sendable () -> Void)? = nil) {
        guard animated, !windows.isEmpty else {
            windows.forEach { $0.alphaValue = alpha }
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            windows.forEach { $0.animator().alphaValue = alpha }
        }, completionHandler: completion)
    }
}
