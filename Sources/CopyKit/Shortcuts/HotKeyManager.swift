import Carbon.HIToolbox
import Foundation

@MainActor
final class HotKeyManager {
    struct RegistrationError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            "This shortcut could not be registered (error \(status)). Choose another combination."
        }
    }

    var onPress: (() -> Void)?
    private(set) var shortcut: KeyboardShortcut?
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var identifier: UInt32 = 0
    private var isPressed = false
    private static let signature: OSType = 0x4350_4B54

    func register(_ shortcut: KeyboardShortcut) throws {
        guard shortcut.isValid else { throw RegistrationError(status: OSStatus(paramErr)) }
        if self.shortcut == shortcut, hotKey != nil { return }
        if eventHandler == nil {
            var events = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
            ]
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, context in
                    guard let event, let context else { return OSStatus(eventNotHandledErr) }
                    var id = EventHotKeyID()
                    let status = GetEventParameter(
                        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id
                    )
                    guard status == noErr else { return status }
                    return MainActor.assumeIsolated {
                        let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
                        guard id.signature == HotKeyManager.signature, id.id == manager.identifier else {
                            return OSStatus(eventNotHandledErr)
                        }
                        if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                            manager.isPressed = false
                        } else if !manager.isPressed {
                            manager.isPressed = true
                            manager.onPress?()
                        }
                        return noErr
                    }
                }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &eventHandler
            )
            guard status == noErr else { throw RegistrationError(status: status) }
        }

        let nextIdentifier = identifier &+ 1
        var nextHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: Self.signature, id: nextIdentifier),
            GetApplicationEventTarget(), 0, &nextHotKey
        )
        guard status == noErr else { throw RegistrationError(status: status) }
        unregister()
        hotKey = nextHotKey
        identifier = nextIdentifier
        self.shortcut = shortcut
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        isPressed = false
    }

    func stop() {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }
}
