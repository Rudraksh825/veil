import AppKit
import AVFoundation

/// Metadata and a poster frame for the chosen video, loaded off the main thread.
struct VideoInfo {
    let url: URL
    let duration: Double
    let pixelSize: CGSize
    let fileSize: Int64
    let hasAudio: Bool
    let thumbnail: NSImage?

    var title: String { url.deletingPathExtension().lastPathComponent }

    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "—" }
        let total = Int(duration.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var resolutionText: String {
        guard pixelSize.width > 0 else { return "—" }
        return "\(Int(pixelSize.width))×\(Int(pixelSize.height))"
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var summary: String {
        [durationText, resolutionText, fileSizeText].joined(separator: "  ·  ")
    }

    static func load(_ url: URL) async -> VideoInfo? {
        let asset = AVURLAsset(url: url)
        guard let loaded = try? await asset.load(.duration, .tracks) else { return nil }
        let (duration, tracks) = loaded

        var size = CGSize.zero
        if let track = tracks.first(where: { $0.mediaType == .video }),
           let props = try? await track.load(.naturalSize, .preferredTransform) {
            let transformed = props.0.applying(props.1)
            size = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        }

        let hasAudio = tracks.contains { $0.mediaType == .audio }
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let seconds = duration.seconds
        let sample = seconds.isFinite && seconds > 2 ? min(seconds * 0.1, 5) : 0
        let cgImage = try? await generator.image(at: CMTime(seconds: sample, preferredTimescale: 600)).image
        let thumbnail = cgImage.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }

        return VideoInfo(url: url, duration: seconds, pixelSize: size, fileSize: fileSize,
                         hasAudio: hasAudio, thumbnail: thumbnail)
    }
}
