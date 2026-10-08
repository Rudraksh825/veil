import AppKit
import SwiftUI

struct VideoPane: View {
    @Bindable var model: AppModel
    @State private var isTargeted = false

    var body: some View {
        Form {
            Section {
                if model.videoURL == nil {
                    EmptyVideoState(isTargeted: isTargeted) { model.chooseVideo() }
                } else {
                    VideoCard(model: model)
                }
            } footer: {
                Text(model.videoURL == nil
                     ? "Veil loops the video as a faint, click-through layer over everything on your screen. You keep working underneath it."
                     : "Drop another video anywhere in this window to replace it.")
            }

            if !model.recentVideos.isEmpty {
                recents
            }
        }
        .formStyle(.grouped)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            VideoDrop.handle(providers) { model.loadVideo($0) }
        }
        .overlay { DropHighlight(isTargeted: isTargeted) }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private var recents: some View {
        Section {
            ForEach(model.recentVideos, id: \.self) { url in
                RecentRow(url: url, isCurrent: url == model.videoURL) {
                    model.loadVideo(url)
                }
                .contextMenu {
                    Button("Show in Finder") { model.revealInFinder(url) }
                    Button("Remove from Recents") { model.removeRecent(url) }
                }
            }
        } header: {
            HStack {
                Text("Recent")
                Spacer()
                Button("Clear") { model.clearRecents() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyVideoState: View {
    let isTargeted: Bool
    let choose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            Text("Drop a video here")
                .font(.headline)
            Text("MP4, MOV, M4V, HEVC and anything else QuickTime can play.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Choose Video…", action: choose)
                .keyboardShortcut("o", modifiers: .command)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        }
        .padding(.vertical, 4)
    }
}

private struct VideoCard: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ThumbnailView(image: model.videoInfo?.thumbnail)
                .frame(width: 144, height: 81)

            VStack(alignment: .leading, spacing: 5) {
                Text(model.videoInfo?.title ?? model.videoURL?.deletingPathExtension().lastPathComponent ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let info = model.videoInfo {
                    Text(info.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                status

                HStack(spacing: 8) {
                    Button("Choose…") { model.chooseVideo() }
                    Button("Show in Finder") { model.revealInFinder() }
                    Button("Remove", role: .destructive) { model.removeVideo() }
                }
                .controlSize(.small)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var status: some View {
        switch model.loadState {
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Loading…").foregroundStyle(.secondary)
            }
            .font(.caption)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .ready:
            HStack(spacing: 10) {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let info = model.videoInfo, !info.hasAudio {
                    Label("No audio track", systemImage: "speaker.slash")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        case .empty:
            EmptyView()
        }
    }
}

private struct RecentRow: View {
    let url: URL
    let isCurrent: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text((url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                        .font(.caption.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(url.path)
    }
}
