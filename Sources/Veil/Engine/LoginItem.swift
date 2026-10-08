import Foundation
import ServiceManagement

enum LoginItem {
    struct NotBundledError: LocalizedError {
        var errorDescription: String? {
            "Launch at login is only available when Veil runs from a built .app bundle."
        }
    }

    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else { throw NotBundledError() }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
