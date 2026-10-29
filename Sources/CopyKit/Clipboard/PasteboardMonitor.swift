import AppKit
import Combine

@MainActor
final class PasteboardMonitor: ObservableObject {
    @Published private(set) var isPaused = false
    @Published private(set) var message: String?

    private let pasteboard: NSPasteboard
    private let history: HistoryStore
    private var timer: Timer?
    private var processingTask: Task<Void, Never>?
    private var lastChangeCount: Int
    private var generation = 0
    private var attemptedPermissionRead = false
    private var isSuspended = false

    init(history: HistoryStore, pasteboard: NSPasteboard = .general) {
        self.history = history
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil, !isPaused, !isSuspended else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancelPendingRead()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            stop()
        } else {
            attemptedPermissionRead = false
            start()
        }
    }

    func suspend() {
        isSuspended = true
        stop()
    }

    func resume() {
        isSuspended = false
        start()
    }

    func clearHistory() {
        cancelPendingRead()
        lastChangeCount = pasteboard.changeCount
        history.clear()
        message = nil
    }

    func retryAccess() {
        attemptedPermissionRead = false
        lastChangeCount = -1
        poll()
    }

    func poll() {
        guard !isPaused, !isSuspended, processingTask == nil,
            pasteboard.changeCount != lastChangeCount
        else { return }

        if #available(macOS 15.4, *) {
            switch pasteboard.accessBehavior {
            case .alwaysDeny:
                message = "Clipboard access is denied. Allow CopyKit in System Settings, then retry from the menu."
                return
            case .ask where attemptedPermissionRead:
                message = "Allow clipboard access in System Settings, then choose Retry Clipboard Access from the menu."
                return
            default: break
            }
        }

        let changeCount = pasteboard.changeCount
        lastChangeCount = changeCount
        attemptedPermissionRead = true
        do {
            guard let snapshot = try ClipboardReader.snapshot(from: pasteboard) else { return }
            // Discard a snapshot if another app replaced the clipboard while it was being read.
            guard pasteboard.changeCount == changeCount else { return }
            let expectedGeneration = generation
            processingTask = Task { [weak self] in
                let result = await Task.detached(priority: .utility) {
                    Result { try snapshot.makeEntry() }
                }.value
                guard let self, !Task.isCancelled, self.generation == expectedGeneration else { return }
                self.processingTask = nil
                switch result {
                case .success(let entry):
                    self.message =
                        self.history.insert(entry)
                        ? nil : ClipboardReadError.tooLarge.localizedDescription
                case .failure(let error):
                    self.message = error.localizedDescription
                }
            }
        } catch {
            message = error.localizedDescription
        }
    }

    @discardableResult
    func copy(_ entry: ClipboardEntry) -> Bool {
        let item = NSPasteboardItem()
        let prepared: Bool
        switch entry.content {
        case .text(let text): prepared = item.setString(text, forType: .string)
        case .image(let data, let type, _, _, _):
            prepared = item.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
        guard prepared else { return false }
        pasteboard.clearContents()
        let succeeded = pasteboard.writeObjects([item])
        // Our own write must never become a new history entry.
        lastChangeCount = pasteboard.changeCount
        if !succeeded { message = "Could not write to the clipboard. Please try again." }
        return succeeded
    }

    private func cancelPendingRead() {
        generation += 1
        processingTask?.cancel()
        processingTask = nil
    }
}
