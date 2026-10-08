import SwiftUI

struct PlaybackPane: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Overlay") {
                Toggle("Show overlay", isOn: $model.isOverlayVisible)
                Toggle("Play video", isOn: $model.isPlaying)
                Picker("Speed", selection: $model.speed) {
                    ForEach(SpeedPresets.all, id: \.self) { speed in
                        Text(SpeedPresets.label(speed)).tag(speed)
                    }
                }
                Toggle("Pause while the screen is locked or asleep", isOn: $model.pauseWhenLocked)
            }

            Section {
                LabeledContent("Volume") {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                        Slider(value: $model.volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                        Text(Format.percent(model.volume))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .disabled(model.isMuted)
                Toggle("Mute", isOn: $model.isMuted)
            } header: {
                Text("Audio")
            } footer: {
                Text("Only the overlay video is affected. Your system volume and other apps stay exactly as they are.")
            }
        }
        .formStyle(.grouped)
    }
}
