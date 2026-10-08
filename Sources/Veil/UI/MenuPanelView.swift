import AppKit
import SwiftUI

/// The popover shown from the menu bar icon: status, transport, opacity and volume.
struct MenuPanelView: View {
    @Bindable var model: AppModel
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if model.videoURL == nil {
                Button {
                    model.chooseVideo()
                } label: {
                    Label("Choose Video…", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: .command)
            } else {
                transport
                sliders
            }

            Divider().padding(.top, 2)
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            VideoDrop.handle(providers) { model.loadVideo($0) }
        }
        .overlay { DropHighlight(isTargeted: isTargeted) }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            ThumbnailView(image: model.videoInfo?.thumbnail)
                .frame(width: 64, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var transport: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $model.isOverlayVisible) {
                Label(model.isOverlayVisible ? "Shown" : "Hidden",
                      systemImage: model.isOverlayVisible ? "eye.fill" : "eye.slash")
                    .frame(maxWidth: .infinity)
            }
            .help("Show or hide the overlay (\(model.hotKeyEnabled ? model.hotKey.display : "⌥-click the menu bar icon"))")

            Toggle(isOn: $model.isPlaying) {
                Label(model.isPlaying ? "Playing" : "Paused",
                      systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .help(model.isPlaying ? "Pause on the current frame" : "Resume playback")
        }
        .toggleStyle(.button)
        .controlSize(.large)
        .disabled(isFailed)
    }

    private var sliders: some View {
        VStack(spacing: 10) {
            CompactSlider(symbol: "circle.lefthalf.filled",
                          value: $model.opacity,
                          range: 0.01...1,
                          text: Format.percent(model.opacity),
                          help: "Opacity")

            CompactSlider(symbol: model.volumeSymbol,
                          value: $model.volume,
                          range: 0...1,
                          text: model.isMuted ? "Muted" : Format.percent(model.volume),
                          help: model.isMuted ? "Unmute" : "Volume of the overlay video only",
                          onSymbolTap: { model.isMuted.toggle() })
                .opacity(model.isMuted ? 0.55 : 1)
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack {
            Button {
                AppDelegate.shared?.showSettings(tab: nil)
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(.accessoryBar)
    }

    // MARK: Derived

    private var title: String {
        model.videoInfo?.title ?? model.videoURL?.deletingPathExtension().lastPathComponent ?? "Veil"
    }

    private var subtitle: String {
        if case .ready = model.loadState, let info = model.videoInfo {
            return "\(info.durationText)  ·  \(model.statusText)"
        }
        return model.statusText
    }

    private var isFailed: Bool {
        if case .failed = model.loadState { return true }
        return false
    }
}
