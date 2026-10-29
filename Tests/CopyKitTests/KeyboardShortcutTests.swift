import Carbon.HIToolbox
import Foundation

#if !COPYKIT_STANDALONE
    @testable import CopyKit
#endif

struct KeyboardShortcutTests {
    func defaultIsControlSemicolon() throws {
        let shortcut = KeyboardShortcut.defaultShortcut
        try expect(shortcut.keyCode == UInt32(kVK_ANSI_Semicolon))
        try expect(shortcut.modifiers == UInt32(controlKey))
        try expect(shortcut.label == "⌃;")
        try expect(shortcut.isValid)
    }

    func rejectsBareKeysAndUnsupportedKeyCodes() throws {
        try expect(!KeyboardShortcut(keyCode: 0, modifiers: 0).isValid)
        try expect(!KeyboardShortcut(keyCode: 0, modifiers: UInt32(optionKey)).isValid)
        try expect(!KeyboardShortcut(keyCode: 255, modifiers: UInt32(controlKey)).isValid)
    }

    func savedShortcutRoundTripsAndInvalidSettingsFallBack() throws {
        let name = "CopyKitTests.\(UUID())"
        let defaults = try require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let shortcut = KeyboardShortcut(keyCode: 9, modifiers: UInt32(controlKey | optionKey))
        shortcut.save(to: defaults)
        try expect(KeyboardShortcut.load(from: defaults) == shortcut)
        defaults.set(Data("invalid".utf8), forKey: "keyboardShortcut")
        try expect(KeyboardShortcut.load(from: defaults) == .defaultShortcut)
    }

    @MainActor func numberRowAndKeypadMapToTheSameSixChoices() throws {
        for (index, code) in [UInt16(18), 19, 20, 21, 23, 22].enumerated() {
            try expect(ClipboardPanelController.index(forKeyCode: code) == index)
            try expect(ClipboardPanelController.index(forKeyCode: UInt16(83 + index)) == index)
        }
        try expect(ClipboardPanelController.index(forKeyCode: 26) == nil)
    }
}
