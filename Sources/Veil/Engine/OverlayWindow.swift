import AppKit
import AVFoundation
import CoreImage

/// Hosts the AVPlayerLayer. Completely inert: no hit testing, no focus.
final class PlayerHostView: NSView {
    let playerLayer = AVPlayerLayer()
    private var overscan: CGFloat = 0

    init(player: AVPlayer) {
        super.init(frame: .zero)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        layer?.backgroundColor = NSColor.clear.cgColor
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Overscan hides the transparent fringe a blur filter leaves at the edges.
        playerLayer.frame = bounds.insetBy(dx: -overscan, dy: -overscan)
        CATransaction.commit()
    }

    func setFilters(saturation: Double, blur: Double) {
        var filters: [CIFilter] = []
        if abs(saturation - 1) > 0.005, let filter = CIFilter(name: "CIColorControls") {
            filter.setDefaults()
            filter.setValue(saturation, forKey: kCIInputSaturationKey)
            filters.append(filter)
        }
        if blur >= 0.5, let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(blur, forKey: kCIInputRadiusKey)
            filters.append(filter)
        }
        playerLayer.filters = filters.isEmpty ? nil : filters
        overscan = blur >= 0.5 ? CGFloat(blur) * 2 : 0
        needsLayout = true
    }
}

/// A borderless, click-through panel covering one screen on every Space.
final class OverlayWindow: NSPanel {
    let host: PlayerHostView
    let displayID: UInt32

    init(screen: NSScreen, player: AVPlayer) {
        host = PlayerHostView(player: player)
        displayID = screen.displayID
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        alphaValue = 0
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
