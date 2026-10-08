import Carbon.HIToolbox

/// A global keyboard shortcut: a single key plus a set of modifiers.
struct KeyCombo: Equatable {
    struct Modifiers: OptionSet, Hashable {
        let rawValue: Int

        static let control = Modifiers(rawValue: 1 << 0)
        static let option  = Modifiers(rawValue: 1 << 1)
        static let shift   = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)

        /// Display order, matching macOS convention.
        static let ordered: [Modifiers] = [.control, .option, .shift, .command]

        var symbol: String {
            switch self {
            case .control: "⌃"
            case .option: "⌥"
            case .shift: "⇧"
            case .command: "⌘"
            default: ""
            }
        }

        var name: String {
            switch self {
            case .control: "Control"
            case .option: "Option"
            case .shift: "Shift"
            case .command: "Command"
            default: ""
            }
        }

        var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if contains(.control) { flags |= UInt32(controlKey) }
            if contains(.option) { flags |= UInt32(optionKey) }
            if contains(.shift) { flags |= UInt32(shiftKey) }
            if contains(.command) { flags |= UInt32(cmdKey) }
            return flags
        }
    }

    var key: String
    var modifiers: Modifiers

    static let `default` = KeyCombo(key: "V", modifiers: [.control, .option, .command])

    static let availableKeys: [String] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").map(String.init)

    var display: String {
        Modifiers.ordered.filter { modifiers.contains($0) }.map(\.symbol).joined() + key
    }

    var keyCode: UInt32? { Self.keyCodes[key.uppercased()] }

    private static let keyCodes: [String: UInt32] = [
        "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B), "C": UInt32(kVK_ANSI_C), "D": UInt32(kVK_ANSI_D),
        "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F), "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H),
        "I": UInt32(kVK_ANSI_I), "J": UInt32(kVK_ANSI_J), "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
        "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N), "O": UInt32(kVK_ANSI_O), "P": UInt32(kVK_ANSI_P),
        "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R), "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T),
        "U": UInt32(kVK_ANSI_U), "V": UInt32(kVK_ANSI_V), "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
        "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2), "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5), "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8), "9": UInt32(kVK_ANSI_9),
    ]
}
