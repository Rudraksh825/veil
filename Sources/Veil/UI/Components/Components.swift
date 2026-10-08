import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag & drop

enum VideoDrop {
    static let acceptedTypes: [UTType] = [.movie, .video]

    static func isVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return acceptedTypes.contains { type.conforms(to: $0) }
    }

    /// Extracts the first dropped video file URL and hands it back on the main actor.
    @discardableResult
    static func handle(_ providers: [NSItemProvider], completion: @escaping @MainActor (URL) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, isVideo(url) else { return }
            Task { @MainActor in completion(url) }
        }
        return true
    }
}

/// Highlight drawn over a view while a video is being dragged across it.
struct DropHighlight: View {
    let isTargeted: Bool

    var body: some View {
        if isTargeted {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                Label("Drop to use this video", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(8)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

// MARK: - Thumbnail

struct ThumbnailView: View {
    let image: NSImage?
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(red: 0.25, green: 0.2, blue: 0.55), Color(red: 0.45, green: 0.3, blue: 0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "film")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Sliders

/// Form row: label on the left, slider plus live value on the right.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    let format: (Double) -> String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}

/// Compact slider for the menu bar panel: icon, slider, value.
struct CompactSlider: View {
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let text: String
    let help: String
    var onSymbolTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let onSymbolTap {
                    Button(action: onSymbolTap) {
                        Image(systemName: symbol).frame(width: 20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: symbol).frame(width: 20)
                }
            }
            .foregroundStyle(.secondary)
            .contentTransition(.symbolEffect(.replace))

            Slider(value: $value, in: range)
                .controlSize(.small)

            Text(text)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .help(help)
    }
}

// MARK: - Formatting

enum Format {
    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
