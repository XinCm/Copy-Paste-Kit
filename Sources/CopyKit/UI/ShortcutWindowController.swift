import AppKit

@MainActor
final class ShortcutWindowController: NSWindowController, NSWindowDelegate {
    var onSave: ((KeyboardShortcut) -> String?)?
    var onClose: (() -> Void)?
    private var candidate: KeyboardShortcut
    private let recorder = ShortcutRecorderView()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init(shortcut: KeyboardShortcut) {
        candidate = shortcut
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "Keyboard Shortcut"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(recorder)
    }

    private func buildContent() {
        let description = NSTextField(
            wrappingLabelWithString:
                "Press a letter, number, or punctuation key with Control or Command. Labels use US key positions."
        )
        description.textColor = .secondaryLabelColor
        recorder.label.stringValue = candidate.label
        recorder.onChange = { [weak self] shortcut in
            self?.candidate = shortcut
            self?.recorder.label.stringValue = shortcut.label
            self?.errorLabel.stringValue = ""
        }
        recorder.onSave = { [weak self] in self?.save() }
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let reset = NSButton(title: "Use Default", target: self, action: #selector(resetShortcut))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [reset, spacer, cancel, save])
        buttons.orientation = .horizontal
        let stack = NSStackView(views: [description, recorder, errorLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        guard let content = window?.contentView else { return }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            recorder.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recorder.heightAnchor.constraint(equalToConstant: 56),
            errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func resetShortcut() {
        candidate = .defaultShortcut
        recorder.label.stringValue = candidate.label
        errorLabel.stringValue = ""
        window?.makeFirstResponder(recorder)
    }

    @objc private func cancel() { window?.close() }

    @objc private func save() {
        if let error = onSave?(candidate) {
            errorLabel.stringValue = error
        } else {
            window?.close()
        }
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}

@MainActor
private final class ShortcutRecorderView: NSView {
    let label = NSTextField(labelWithString: "")
    var onChange: ((KeyboardShortcut) -> Void)?
    var onSave: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityLabel("Shortcut recorder")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        border.lineWidth = 2
        border.stroke()
    }

    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.close()
            return
        }
        if event.keyCode == 36 {
            onSave?()
            return
        }
        guard !event.isARepeat, let shortcut = KeyboardShortcut(event: event) else {
            NSSound.beep()
            return
        }
        onChange?(shortcut)
    }
}
