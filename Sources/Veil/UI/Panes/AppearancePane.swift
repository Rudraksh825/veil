import SwiftUI

struct AppearancePane: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                SliderRow(title: "Opacity", value: $model.opacity, range: 0.01...1) { Format.percent($0) }
                SliderRow(title: "Saturation", value: $model.saturation, range: 0...2) { Format.percent($0) }
                SliderRow(title: "Blur", value: $model.blur, range: 0...40) {
                    $0 < 0.5 ? "Off" : "\(Int($0.rounded())) pt"
                }
                Picker("Scaling", selection: $model.scaling) {
                    ForEach(ScalingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Look")
            } footer: {
                Text(model.scaling.help)
            }

            Section {
                Picker("Show on", selection: $model.targetDisplayID) {
                    Text("All Displays").tag(UInt32(0))
                    ForEach(model.displays) { display in
                        Text(display.isPrimary ? "\(display.name) (Primary)" : display.name).tag(display.id)
                    }
                    if model.targetDisplayMissing {
                        Text("Disconnected Display").tag(model.targetDisplayID)
                    }
                }
                if model.targetDisplayMissing {
                    Label("That display isn't connected right now, so the overlay is showing on all displays.",
                          systemImage: "display.trianglebadge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Layer", selection: $model.layering) {
                    ForEach(OverlayLayering.allCases) { layering in
                        Text(layering.title).tag(layering)
                    }
                }

                Toggle("Hide from screenshots and screen sharing", isOn: $model.excludeFromCapture)
            } header: {
                Text("Placement")
            } footer: {
                Text("The overlay never takes clicks or keyboard focus, whatever layer it sits on.")
            }
        }
        .formStyle(.grouped)
    }
}
