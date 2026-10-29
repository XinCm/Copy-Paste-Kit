import AppKit
import Carbon.HIToolbox

struct KeyboardShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_Semicolon), modifiers: UInt32(controlKey)
    )
    private static let defaultsKey = "keyboardShortcut"
    private static let supportedModifiers = UInt32(controlKey | optionKey | shiftKey | cmdKey)

    static let keyLabels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        49: "Space", 50: "`",
    ]

    var isValid: Bool {
        Self.keyLabels[keyCode] != nil
            && modifiers & UInt32(controlKey | cmdKey) != 0
            && modifiers & ~Self.supportedModifiers == 0
    }

    var label: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + (Self.keyLabels[keyCode] ?? "?")
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        if !isValid { return nil }
    }

    static func load(from defaults: UserDefaults = .standard) -> KeyboardShortcut {
        guard let data = defaults.data(forKey: defaultsKey),
            let shortcut = try? JSONDecoder().decode(Self.self, from: data), shortcut.isValid
        else { return .defaultShortcut }
        return shortcut
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }
}
