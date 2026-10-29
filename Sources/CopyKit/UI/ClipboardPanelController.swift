import AppKit
import SwiftUI

@MainActor
final class PanelState: ObservableObject {
    @Published var entries: [ClipboardEntry] = []
    @Published var selectedIndex = 0
    @Published var message: String?
    var isDemo = false
}

@MainActor
final class ClipboardPanelController: NSObject, NSWindowDelegate {
    var onChoose: ((ClipboardEntry) -> Bool)?
    let state = PanelState()
    private let panel: ClipboardPanel
    private var contentController: PanelContentController?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = ClipboardPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        super.init()
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.title = "CopyKit Clipboard History"
        panel.handleKey = { [weak self] event in self?.handleKey(event) ?? false }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    func show(entries: [ClipboardEntry], message: String? = nil, isDemo: Bool = false) {
        // Freeze the visible snapshot so incoming copies cannot change numbered choices.
        state.entries = entries
        state.selectedIndex = 0
        state.message = message
        state.isDemo = isDemo
        rebuildContent()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        positionPanel(on: screen)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        installClickMonitors()
    }

    func hide() {
        removeClickMonitors()
        panel.orderOut(nil)
        panel.contentViewController = nil
        contentController = nil
        // Release the snapshot after dismissal; the store owns the retained history.
        state.entries = []
    }

    func windowDidResignKey(_ notification: Notification) { hide() }

    private func rebuildContent() {
        // Create the hosting controller after updating the snapshot so its first measurement is current.
        let content = PanelContentController(state: state) { [weak self] index in self?.choose(index) }
        contentController = content
        panel.contentViewController = content
    }

    private func positionPanel(on screen: NSScreen? = nil) {
        guard let screen = screen ?? panel.screen ?? NSScreen.main, let contentController else { return }
        let frame = PanelLayout.frame(for: contentController.measuredSize, in: screen.visibleFrame)
        panel.setFrame(frame, display: true)
    }

    @objc private func screenParametersChanged() {
        if panel.isVisible { positionPanel() }
    }

    private func choose(_ index: Int) {
        guard state.entries.indices.contains(index) else {
            NSSound.beep()
            return
        }
        if onChoose?(state.entries[index]) == true {
            hide()
        } else {
            state.message = "Could not copy this item. Please try again."
            rebuildContent()
            positionPanel()
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            hide()
            return true
        }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers.isEmpty else { return false }
        if let index = Self.index(forKeyCode: event.keyCode) {
            if !event.isARepeat { choose(index) }
            return true
        }
        switch event.keyCode {
        case 125:
            state.selectedIndex = min(state.selectedIndex + 1, max(state.entries.count - 1, 0))
        case 126:
            state.selectedIndex = max(state.selectedIndex - 1, 0)
        case 36, 76:
            if !event.isARepeat { choose(state.selectedIndex) }
        default: return false
        }
        return true
    }

    static func index(forKeyCode code: UInt16) -> Int? {
        // Hardware positions also work while a non-Latin input method is active.
        [
            18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5,
            83: 0, 84: 1, 85: 2, 86: 3, 87: 4, 88: 5,
        ][code]
    }

    private func installClickMonitors() {
        removeClickMonitors()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in MainActor.assumeIsolated { self?.hide() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            MainActor.assumeIsolated {
                if let self, event.window !== self.panel { self.hide() }
            }
            return event
        }
    }

    private func removeClickMonitors() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        outsideClickMonitor = nil
        localClickMonitor = nil
    }
}

@MainActor
private final class ClipboardPanel: NSPanel {
    var handleKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleKey?(event) == true { return }
        super.sendEvent(event)
    }
}
