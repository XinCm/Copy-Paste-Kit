import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let history = HistoryStore()
    private lazy var monitor = PasteboardMonitor(history: history)
    private let hotKey = HotKeyManager()
    private let panel = ClipboardPanelController()
    private var statusItem: NSStatusItem?
    private var shortcutWindow: ShortcutWindowController?
    private var shortcut = KeyboardShortcut.load()
    private let isDemo: Bool

    init(isDemo: Bool) { self.isDemo = isDemo }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        panel.onChoose = { [weak self] entry in
            guard let self else { return false }
            return self.isDemo || self.monitor.copy(entry)
        }
        if isDemo {
            loadDemo()
            showHistory()
            return
        }
        hotKey.onPress = { [weak self] in self?.showHistory() }
        registerShortcut()
        monitor.start()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(suspendRecording), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(
            self, selector: #selector(suspendRecording), name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil)
        center.addObserver(
            self, selector: #selector(resumeRecording), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(
            self, selector: #selector(resumeRecording), name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel.hide()
        monitor.stop()
        hotKey.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyKit")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "CopyKit — Clipboard History"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(
            title: isDemo
                ? "Preview Mode"
                : monitor.isPaused
                    ? "Recording Paused"
                    : monitor.message == nil ? "Recording Clipboard Changes" : "Clipboard Needs Attention",
            action: nil, keyEquivalent: "")
        status.toolTip = monitor.message
        menu.addItem(status)
        addItem("Show History   \(shortcut.label)", action: #selector(showHistory), to: menu)
        menu.addItem(.separator())
        if !isDemo {
            addItem(monitor.isPaused ? "Resume Recording" : "Pause Recording", action: #selector(togglePause), to: menu)
        }
        addItem("Clear History", action: #selector(clearHistory), to: menu)
        if !isDemo {
            menu.addItem(.separator())
            addItem("Change Shortcut…", action: #selector(changeShortcut), to: menu)
            addItem("Retry Clipboard Access", action: #selector(retryAccess), to: menu)
            let loginItem = addItem("Launch at Login", action: #selector(toggleLoginItem), to: menu)
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(.separator())
        addItem("About CopyKit", action: #selector(showAbout), to: menu)
        addItem("Quit CopyKit", action: #selector(quit), to: menu)
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func showHistory() {
        if panel.isVisible {
            panel.hide()
            return
        }
        panel.show(
            entries: history.entries,
            message: monitor.isPaused ? "Recording is paused. Resume from the menu bar." : monitor.message,
            isDemo: isDemo
        )
    }

    @objc private func togglePause() { monitor.togglePause() }
    @objc private func clearHistory() {
        panel.hide()
        monitor.clearHistory()
    }
    @objc private func retryAccess() { monitor.retryAccess() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func suspendRecording() {
        panel.hide()
        monitor.suspend()
    }
    @objc private func resumeRecording() { monitor.resume() }

    @objc private func changeShortcut() {
        panel.hide()
        if let shortcutWindow {
            shortcutWindow.show()
            return
        }
        // Let the recorder receive the current shortcut instead of reopening the history panel.
        hotKey.unregister()
        let controller = ShortcutWindowController(shortcut: shortcut)
        controller.onSave = { [weak self] candidate in
            guard let self else { return "The app is no longer available." }
            do {
                try self.hotKey.register(candidate)
                self.shortcut = candidate
                candidate.save()
                return nil
            } catch { return error.localizedDescription }
        }
        controller.onClose = { [weak self] in
            guard let self else { return }
            self.shortcutWindow = nil
            self.registerShortcut()
        }
        shortcutWindow = controller
        controller.show()
    }

    private func registerShortcut() {
        do { try hotKey.register(shortcut) } catch {
            showAlert("Shortcut Unavailable", message: error.localizedDescription + " Use the menu bar to change it.")
        }
    }

    @objc private func toggleLoginItem() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            showAlert(
                "App Bundle Required",
                message: "Build the app bundle and move it to Applications before enabling Launch at Login.")
            return
        }
        do {
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default:
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch { showAlert("Could Not Update Login Item", message: error.localizedDescription) }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "CopyKit",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "0.1.1",
            .credits: NSAttributedString(
                string:
                    "A small, local clipboard history for macOS.\nText and images. Six recent items. No network access."
            ),
        ])
    }

    private func showAlert(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func loadDemo() {
        let samples = [
            "A small tool for everyday copying.",
            "https://developer.apple.com/documentation/appkit",
            "Shopping list\nCoffee, bread, and fresh fruit",
            "let greeting = \"Hello, world!\"",
            "Meeting notes\nKeep the first release focused and lightweight.",
            "Welcome to CopyKit. Copy once, find it again.",
        ]
        for text in samples { history.insert(ClipboardEntry(content: .text(text))) }
    }
}
