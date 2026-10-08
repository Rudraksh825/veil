import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hot key using Carbon, which needs no accessibility permission.
final class HotKeyCenter {
    static let signature: OSType = 0x5645494C // "VEIL"

    var onPress: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, userData, &handlerRef)
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// Returns false when the combination is already claimed elsewhere.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { hotKeyRef = nil }
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    fileprivate func fire() {
        Task { @MainActor [onPress] in onPress?() }
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
        return OSStatus(eventNotHandledErr)
    }
    Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue().fire()
    return noErr
}
