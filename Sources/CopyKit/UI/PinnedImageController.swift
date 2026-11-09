import AppKit

@MainActor
final class ImagePinStore {
    private(set) var pins: [UUID: PinnedImageController] = [:]

    @discardableResult
    func pin(_ entry: ClipboardEntry) -> Bool {
        if let existing = pins[entry.id] {
            existing.show()
            return true
        }
        guard let controller = PinnedImageController(entry: entry) else { return false }
        let id = entry.id
        controller.onClose = { [weak self] in self?.pins.removeValue(forKey: id) }
        pins[entry.id] = controller
        controller.show()
        return true
    }

    func closeAll() {
        let current = Array(pins.values)
        for controller in current { controller.panel.close() }
    }
}

@MainActor
final class PinnedImageController: NSObject, NSWindowDelegate {
    let panel: PinnedImagePanel
    var onClose: (() -> Void)?

    init?(entry: ClipboardEntry) {
        guard case .image(let data, _, _, let width, let height) = entry.content,
            width > 0, height > 0, let image = NSImage(data: data), image.isValid,
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        else { return nil }
        let frame = ImagePinLayout.initialFrame(
            imageSize: NSSize(width: width, height: height), in: screen.visibleFrame
        )
        panel = PinnedImagePanel(
            contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false
        )
        super.init()
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.title = "CopyKit Pinned Image"
        let view = PinnedImageView(image: image)
        view.setAccessibilityLabel("Pinned image, \(width) by \(height) pixels")
        view.setAccessibilityHelp("Drag to move. Scroll to resize, or click then pinch. Press Escape to close.")
        view.toolTip = "Drag to move · Scroll or click then pinch to resize · Esc to close"
        panel.contentView = view
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    func show() {
        // Trackpad magnification is delivered to the active app, unlike wheel scrolling.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
    }

    func windowDidBecomeKey(_ notification: Notification) { panel.contentView?.needsDisplay = true }
    func windowDidResignKey(_ notification: Notification) { panel.contentView?.needsDisplay = true }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        onClose?()
        onClose = nil
    }

    @objc private func screenParametersChanged() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        panel.setFrame(
            ImagePinLayout.resizedFrame(
                panel.frame, factor: 1, anchor: NSPoint(x: panel.frame.midX, y: panel.frame.midY),
                in: screen.visibleFrame
            ), display: true
        )
    }
}

@MainActor
final class PinnedImagePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            close()
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
private final class PinnedImageView: NSView {
    private let image: NSImage
    override var acceptsFirstResponder: Bool { true }

    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        if window?.isKeyWindow == true {
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
            border.lineWidth = 2
            border.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        window?.performDrag(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.01 : 0.08
        resize(by: exp(min(1, max(-1, event.scrollingDeltaY * sensitivity))), event: event)
    }

    override func magnify(with event: NSEvent) {
        resize(by: max(0.1, 1 + event.magnification), event: event)
    }

    private func resize(by factor: CGFloat, event: NSEvent) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let anchor = window.convertPoint(toScreen: event.locationInWindow)
        window.setFrame(
            ImagePinLayout.resizedFrame(window.frame, factor: factor, anchor: anchor, in: screen.visibleFrame),
            display: true
        )
    }
}
