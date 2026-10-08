import AppKit
import AVFoundation

enum ScalingMode: String, CaseIterable, Identifiable {
    case fill, fit, stretch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fill: "Fill"
        case .fit: "Fit"
        case .stretch: "Stretch"
        }
    }

    var help: String {
        switch self {
        case .fill: "Covers the whole screen, cropping the edges of the video if its shape doesn't match."
        case .fit: "Shows the entire video, leaving the rest of the screen untouched."
        case .stretch: "Stretches the video to the exact screen size, ignoring its original proportions."
        }
    }

    var gravity: AVLayerVideoGravity {
        switch self {
        case .fill: .resizeAspectFill
        case .fit: .resizeAspect
        case .stretch: .resize
        }
    }
}

enum OverlayLayering: String, CaseIterable, Identifiable {
    case aboveEverything, belowMenuBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aboveEverything: "Above everything"
        case .belowMenuBar: "Below the menu bar and Dock"
        }
    }

    var windowLevel: NSWindow.Level {
        switch self {
        case .aboveEverything: .screenSaver
        case .belowMenuBar: .floating
        }
    }
}

struct DisplayInfo: Identifiable, Equatable {
    let id: UInt32
    let name: String
    let isPrimary: Bool
}

enum LoadState: Equatable {
    case empty
    case loading
    case ready
    case failed(String)
}

enum SpeedPresets {
    static let all: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2]

    static func nearest(_ value: Double) -> Double {
        all.min(by: { abs($0 - value) < abs($1 - value) }) ?? 1
    }

    static func label(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))×" : "\(value)×"
    }
}

enum AppInfo {
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (s?, b?): return "\(s) (\(b))"
        case let (s?, nil): return s
        default: return "Development build"
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension NSScreen {
    var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
