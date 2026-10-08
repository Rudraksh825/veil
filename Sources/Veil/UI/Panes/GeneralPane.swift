import AppKit
import SwiftUI

struct GeneralPane: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
                if let error = model.loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if model.loginItemNeedsApproval {
                    HStack {
                        Text("Needs your approval in System Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items…") { LoginItem.openSystemSettings() }
                            .controlSize(.small)
                    }
                }
                Toggle("Show icon in Dock", isOn: $model.showInDock)
            }

            Section {
                Toggle("Toggle the overlay from any app", isOn: $model.hotKeyEnabled)
                ShortcutPicker(combo: $model.hotKey)
                    .disabled(!model.hotKeyEnabled)
                if let error = model.hotKeyError, model.hotKeyEnabled {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text(model.hotKeyEnabled
                     ? "Press \(model.hotKey.display) anywhere to show or hide the overlay. You can also ⌥-click the menu bar icon."
                     : "You can still ⌥-click the menu bar icon to show or hide the overlay.")
            }

            Section("About") {
                LabeledContent("Version", value: AppInfo.version)
                HStack {
                    Text("Veil keeps running in the menu bar until you quit it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit Veil") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutPicker: View {
    @Binding var combo: KeyCombo

    var body: some View {
        LabeledContent("Shortcut") {
            HStack(spacing: 6) {
                ForEach(KeyCombo.Modifiers.ordered, id: \.rawValue) { modifier in
                    Toggle(isOn: binding(for: modifier)) {
                        Text(modifier.symbol)
                            .font(.system(.body, design: .rounded))
                            .frame(width: 16)
                    }
                    .toggleStyle(.button)
                    .help(modifier.name)
                }

                Picker("Key", selection: $combo.key) {
                    ForEach(KeyCombo.availableKeys, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .labelsHidden()
                .frame(width: 64)

                Spacer()

                Text(combo.display)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
    }

    /// At least one modifier always stays on, so the shortcut can never become a bare key.
    private func binding(for modifier: KeyCombo.Modifiers) -> Binding<Bool> {
        Binding {
            combo.modifiers.contains(modifier)
        } set: { isOn in
            var modifiers = combo.modifiers
            if isOn { modifiers.insert(modifier) } else { modifiers.remove(modifier) }
            guard !modifiers.isEmpty else { return }
            combo.modifiers = modifiers
        }
    }
}
