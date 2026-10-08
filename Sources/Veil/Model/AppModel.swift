import AppKit
import AVFoundation
import Observation
import UniformTypeIdentifiers

/// Single source of truth for the app. Every setting is persisted on write and
/// pushed straight into the overlay engine, so views only ever bind to this object.
@MainActor
@Observable
final class AppModel {
    private enum Key {
        static let videoPath = "videoPath"
        static let recents = "recentVideoPaths"
        static let overlayVisible = "overlayVisible"
        static let playing = "playing"
        static let opacity = "opacity"
        static let saturation = "saturation"
        static let blur = "blur"
        static let scaling = "scaling"
        static let layering = "layering"
        static let displayID = "displayID"
        static let excludeFromCapture = "excludeFromCapture"
        static let speed = "speed"
        static let volume = "volume"
        static let muted = "muted"
        static let pauseWhenLocked = "pauseWhenLocked"
        static let hotKeyEnabled = "hotKeyEnabled"
        static let hotKeyKey = "hotKeyKey"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let showInDock = "showInDock"
    }

    private static let factoryDefaults: [String: Any] = [
        Key.overlayVisible: true,
        Key.playing: true,
        Key.opacity: 0.15,
        Key.saturation: 1.0,
        Key.blur: 0.0,
        Key.scaling: ScalingMode.fill.rawValue,
        Key.layering: OverlayLayering.aboveEverything.rawValue,
        Key.displayID: 0,
        Key.excludeFromCapture: false,
        Key.speed: 1.0,
        Key.volume: 0.3,
        Key.muted: false,
        Key.pauseWhenLocked: true,
        Key.hotKeyEnabled: true,
        Key.hotKeyKey: KeyCombo.default.key,
        Key.hotKeyModifiers: KeyCombo.default.modifiers.rawValue,
        Key.showInDock: false,
    ]

    static let maxRecents = 8

    // MARK: - Dependencies

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let engine = OverlayEngine()
    @ObservationIgnored private let hotKeys = HotKeyCenter()
    @ObservationIgnored private let system = SystemEvents()
    @ObservationIgnored private var infoTask: Task<Void, Never>?
    @ObservationIgnored private var systemWantsSuspend = false

    // MARK: - Video

    private(set) var videoURL: URL?
    private(set) var videoInfo: VideoInfo?
    private(set) var loadState: LoadState = .empty
    private(set) var recentVideos: [URL] = []

    // MARK: - Environment

    private(set) var displays: [DisplayInfo] = []
    /// True while playback is paused because the screen is locked or asleep.
    private(set) var isSuspended = false
    var loginItemError: String?
    var hotKeyError: String?

    // MARK: - Overlay state

    var isOverlayVisible: Bool {
        didSet {
            guard oldValue != isOverlayVisible else { return }
            defaults.set(isOverlayVisible, forKey: Key.overlayVisible)
            engine.isVisible = isOverlayVisible
        }
    }

    var isPlaying: Bool {
        didSet {
            guard oldValue != isPlaying else { return }
            defaults.set(isPlaying, forKey: Key.playing)
            engine.isPlaying = isPlaying
        }
    }

    // MARK: - Appearance

    var opacity: Double {
        didSet { defaults.set(opacity, forKey: Key.opacity); engine.opacity = opacity }
    }

    var saturation: Double {
        didSet { defaults.set(saturation, forKey: Key.saturation); engine.saturation = saturation }
    }

    var blur: Double {
        didSet { defaults.set(blur, forKey: Key.blur); engine.blur = blur }
    }

    var scaling: ScalingMode {
        didSet { defaults.set(scaling.rawValue, forKey: Key.scaling); engine.scaling = scaling }
    }

    var layering: OverlayLayering {
        didSet { defaults.set(layering.rawValue, forKey: Key.layering); engine.layering = layering }
    }

    /// 0 means "all displays"; otherwise a CGDirectDisplayID.
    var targetDisplayID: UInt32 {
        didSet { defaults.set(Int(targetDisplayID), forKey: Key.displayID); engine.targetDisplayID = targetDisplayID }
    }

    var excludeFromCapture: Bool {
        didSet { defaults.set(excludeFromCapture, forKey: Key.excludeFromCapture); engine.excludeFromCapture = excludeFromCapture }
    }

    // MARK: - Playback

    var speed: Double {
        didSet { defaults.set(speed, forKey: Key.speed); engine.speed = speed }
    }

    var volume: Double {
        didSet { defaults.set(volume, forKey: Key.volume); engine.volume = volume }
    }

    var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: Key.muted); engine.isMuted = isMuted }
    }

    var pauseWhenLocked: Bool {
        didSet { defaults.set(pauseWhenLocked, forKey: Key.pauseWhenLocked); applySuspension() }
    }

    // MARK: - General

    var hotKeyEnabled: Bool {
        didSet { defaults.set(hotKeyEnabled, forKey: Key.hotKeyEnabled); registerHotKey() }
    }

    var hotKey: KeyCombo {
        didSet {
            defaults.set(hotKey.key, forKey: Key.hotKeyKey)
            defaults.set(hotKey.modifiers.rawValue, forKey: Key.hotKeyModifiers)
            registerHotKey()
        }
    }

    var showInDock: Bool {
        didSet { defaults.set(showInDock, forKey: Key.showInDock) }
    }

    /// Bumped whenever the login item is touched so SwiftUI re-reads the live status.
    private var loginItemVersion = 0

    var launchAtLogin: Bool {
        get {
            _ = loginItemVersion
            return LoginItem.isEnabled
        }
        set {
            do {
                try LoginItem.setEnabled(newValue)
                loginItemError = nil
            } catch {
                loginItemError = error.localizedDescription
            }
            loginItemVersion += 1
        }
    }

    var loginItemNeedsApproval: Bool {
        _ = loginItemVersion
        return LoginItem.needsApproval
    }

    // MARK: - Init

    init() {
        defaults.register(defaults: Self.factoryDefaults)

        isOverlayVisible = defaults.bool(forKey: Key.overlayVisible)
        isPlaying = defaults.bool(forKey: Key.playing)
        opacity = defaults.double(forKey: Key.opacity).clamped(to: 0.01...1)
        saturation = defaults.double(forKey: Key.saturation).clamped(to: 0...2)
        blur = defaults.double(forKey: Key.blur).clamped(to: 0...40)
        scaling = ScalingMode(rawValue: defaults.string(forKey: Key.scaling) ?? "") ?? .fill
        layering = OverlayLayering(rawValue: defaults.string(forKey: Key.layering) ?? "") ?? .aboveEverything
        targetDisplayID = UInt32(clamping: defaults.integer(forKey: Key.displayID))
        excludeFromCapture = defaults.bool(forKey: Key.excludeFromCapture)
        speed = SpeedPresets.nearest(defaults.double(forKey: Key.speed))
        volume = defaults.double(forKey: Key.volume).clamped(to: 0...1)
        isMuted = defaults.bool(forKey: Key.muted)
        pauseWhenLocked = defaults.bool(forKey: Key.pauseWhenLocked)
        hotKeyEnabled = defaults.bool(forKey: Key.hotKeyEnabled)
        hotKey = KeyCombo(
            key: defaults.string(forKey: Key.hotKeyKey) ?? KeyCombo.default.key,
            modifiers: KeyCombo.Modifiers(rawValue: defaults.integer(forKey: Key.hotKeyModifiers))
        )
        showInDock = defaults.bool(forKey: Key.showInDock)
        recentVideos = (defaults.stringArray(forKey: Key.recents) ?? []).map { URL(fileURLWithPath: $0) }
        if hotKey.modifiers.isEmpty || hotKey.keyCode == nil { hotKey = .default }

        engine.onStatus = { [weak self] status in
            guard let self else { return }
            switch status {
            case .ready: self.loadState = .ready
            case .failed(let message): self.loadState = .failed(message)
            }
        }
        hotKeys.onPress = { [weak self] in self?.toggleOverlay() }
        system.onSuspendStateChange = { [weak self] wantsSuspend in
            self?.systemWantsSuspend = wantsSuspend
            self?.applySuspension()
        }
        system.onScreensChanged = { [weak self] in self?.refreshDisplays() }
    }

    /// Pushes persisted settings into the engine and starts listening to the system.
    func start() {
        engine.opacity = opacity
        engine.saturation = saturation
        engine.blur = blur
        engine.scaling = scaling
        engine.layering = layering
        engine.targetDisplayID = targetDisplayID
        engine.excludeFromCapture = excludeFromCapture
        engine.speed = speed
        engine.volume = volume
        engine.isMuted = isMuted
        engine.isPlaying = isPlaying
        engine.isVisible = isOverlayVisible

        refreshDisplays()
        system.start()
        registerHotKey()

        if let path = defaults.string(forKey: Key.videoPath) {
            loadVideo(URL(fileURLWithPath: path), remember: false)
        }
    }

    // MARK: - Video management

    /// Loads a video. User-initiated loads are remembered and un-hide the overlay.
    func loadVideo(_ url: URL, remember: Bool = true) {
        let url = url.standardizedFileURL
        videoURL = url
        videoInfo = nil
        defaults.set(url.path, forKey: Key.videoPath)

        if remember {
            addRecent(url)
            isOverlayVisible = true
            isPlaying = true
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            loadState = .failed("The file couldn't be found. It may have been moved or deleted.")
            engine.unload()
            return
        }

        loadState = .loading
        engine.load(url: url)

        infoTask?.cancel()
        infoTask = Task { [weak self] in
            let info = await VideoInfo.load(url)
            guard !Task.isCancelled, let self, self.videoURL == url else { return }
            self.videoInfo = info
        }
    }

    func removeVideo() {
        infoTask?.cancel()
        engine.unload()
        videoURL = nil
        videoInfo = nil
        loadState = .empty
        defaults.removeObject(forKey: Key.videoPath)
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a video to play as a faint layer over your screen."
        panel.prompt = "Use Video"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(url)
        }
    }

    func revealInFinder(_ url: URL? = nil) {
        guard let url = url ?? videoURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func removeRecent(_ url: URL) {
        recentVideos.removeAll { $0 == url }
        saveRecents()
    }

    func clearRecents() {
        recentVideos.removeAll()
        saveRecents()
    }

    private func addRecent(_ url: URL) {
        recentVideos.removeAll { $0 == url }
        recentVideos.insert(url, at: 0)
        if recentVideos.count > Self.maxRecents {
            recentVideos.removeLast(recentVideos.count - Self.maxRecents)
        }
        saveRecents()
    }

    private func saveRecents() {
        defaults.set(recentVideos.map(\.path), forKey: Key.recents)
    }

    // MARK: - Actions

    func toggleOverlay() { isOverlayVisible.toggle() }
    func togglePlayback() { isPlaying.toggle() }

    // MARK: - Displays

    func refreshDisplays() {
        displays = NSScreen.screens.enumerated().map { index, screen in
            DisplayInfo(id: screen.displayID, name: screen.localizedName, isPrimary: index == 0)
        }
        engine.syncWindowsToScreens()
    }

    var targetDisplayMissing: Bool {
        targetDisplayID != 0 && !displays.contains { $0.id == targetDisplayID }
    }

    // MARK: - Derived UI state

    var volumeSymbol: String {
        if isMuted || volume == 0 { return "speaker.slash.fill" }
        if volume < 0.34 { return "speaker.wave.1.fill" }
        if volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var statusText: String {
        switch loadState {
        case .empty: "Choose a video to get started"
        case .loading: "Loading…"
        case .failed(let message): message
        case .ready:
            if !isOverlayVisible { "Hidden" }
            else if isSuspended { "Paused while the screen is locked" }
            else if isPlaying { "Playing" }
            else { "Paused" }
        }
    }

    // MARK: - Private

    private func applySuspension() {
        let suspended = systemWantsSuspend && pauseWhenLocked
        isSuspended = suspended
        engine.isSuspended = suspended
    }

    private func registerHotKey() {
        guard hotKeyEnabled, let code = hotKey.keyCode else {
            hotKeys.unregister()
            hotKeyError = nil
            return
        }
        let ok = hotKeys.register(keyCode: code, modifiers: hotKey.modifiers.carbonFlags)
        hotKeyError = ok ? nil : "\(hotKey.display) is already taken by another app or by macOS. Try a different combination."
    }
}
