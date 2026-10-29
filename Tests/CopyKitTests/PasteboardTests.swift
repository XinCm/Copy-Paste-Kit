import AppKit
import ImageIO
import UniformTypeIdentifiers

#if !COPYKIT_STANDALONE
    @testable import CopyKit
#endif

@MainActor
struct PasteboardTests {
    func textRoundTripPreservesUnicodeAndWhitespace() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let text = "  café 👋\n\tSecond line\n"
        pasteboard.setString(text, forType: .string)
        let snapshot = try require(ClipboardReader.snapshot(from: pasteboard))
        let entry = try snapshot.makeEntry()
        let monitor = PasteboardMonitor(history: HistoryStore(), pasteboard: pasteboard)
        try expect(monitor.copy(entry))
        try expect(pasteboard.string(forType: .string) == text)
    }

    func imageRoundTripPreservesOriginalBytesAndDimensions() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let data = try makePNG()
        pasteboard.setData(data, forType: .png)
        let snapshot = try require(ClipboardReader.snapshot(from: pasteboard))
        let entry = try snapshot.makeEntry()
        guard case .image(let original, let type, let thumbnail, let width, let height) = entry.content else {
            throw CheckFailure(message: "Expected image content")
        }
        try expect(original == data)
        try expect(type == NSPasteboard.PasteboardType.png.rawValue)
        try expect(width == 16 && height == 8)
        try expect(NSImage(data: thumbnail) != nil)
        let monitor = PasteboardMonitor(history: HistoryStore(), pasteboard: pasteboard)
        try expect(monitor.copy(entry))
        try expect(pasteboard.data(forType: .png) == data)
    }

    func copiedImageFileIsCapturedAsImageContent() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("copykit-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try makePNG()
        try data.write(to: url)
        pasteboard.setString(url.absoluteString, forType: .fileURL)
        let snapshot = try require(ClipboardReader.snapshot(from: pasteboard))
        let entry = try snapshot.makeEntry()
        try FileManager.default.removeItem(at: url)
        let monitor = PasteboardMonitor(history: HistoryStore(), pasteboard: pasteboard)
        try expect(monitor.copy(entry))
        try expect(pasteboard.data(forType: .png) == data)
    }

    func ignoresMarkedContent(marker: String) throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Do not retain", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
        pasteboard.writeObjects([item])
        try expect(try ClipboardReader.snapshot(from: pasteboard) == nil)
    }

    func ignoresMultipleItemsWithoutSilentlyTruncatingThem() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let items = ["First", "Second"].map { text in
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            return item
        }
        pasteboard.writeObjects(items)
        try expect(try ClipboardReader.snapshot(from: pasteboard) == nil)
    }

    func ignoresNonImageFileReferences() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("file:///tmp/example.txt", forType: .fileURL)
        try expect(try ClipboardReader.snapshot(from: pasteboard) == nil)
    }

    func rejectsInvalidImageData() throws {
        try expect(throws: ClipboardReadError.self) {
            _ = try ClipboardSnapshot.image(Data([0, 1, 2]), type: UTType.png.identifier).makeEntry()
        }
    }

    func monitorCapturesExternalChangesAndIgnoresItsOwnWrites() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let history = HistoryStore()
        let monitor = PasteboardMonitor(history: history, pasteboard: pasteboard)
        defer { monitor.stop() }
        pasteboard.clearContents()
        pasteboard.setString("First", forType: .string)
        monitor.poll()
        try await waitForCount(1, in: history)
        let original = try require(history.entries.first)
        pasteboard.clearContents()
        pasteboard.setString("Second", forType: .string)
        monitor.poll()
        try await waitForCount(2, in: history)
        try expect(monitor.copy(original))
        monitor.poll()
        try expect(history.entries.count == 2)
        try expect(pasteboard.string(forType: .string) == "First")
    }

    func clearHistoryDoesNotClearTheSystemPasteboard() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let history = HistoryStore()
        let monitor = PasteboardMonitor(history: history, pasteboard: pasteboard)
        defer { monitor.stop() }
        pasteboard.clearContents()
        pasteboard.setString("Still available", forType: .string)
        monitor.poll()
        try await waitForCount(1, in: history)
        monitor.clearHistory()
        monitor.poll()
        try expect(history.entries.isEmpty)
        try expect(pasteboard.string(forType: .string) == "Still available")
    }

    func pauseDoesNotImportChangesMadeWhilePaused() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let history = HistoryStore()
        let monitor = PasteboardMonitor(history: history, pasteboard: pasteboard)
        defer { monitor.stop() }
        monitor.togglePause()
        pasteboard.clearContents()
        pasteboard.setString("While paused", forType: .string)
        monitor.poll()
        try expect(history.entries.isEmpty)
        monitor.togglePause()
        monitor.poll()
        try expect(history.entries.isEmpty)
        pasteboard.clearContents()
        pasteboard.setString("After resume", forType: .string)
        monitor.poll()
        try await waitForCount(1, in: history)
        try expect(history.entries[0].accessibilitySummary == "After resume")
    }

    func clearingAnInFlightReadDoesNotRestoreOldHistory() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let history = HistoryStore()
        let monitor = PasteboardMonitor(history: history, pasteboard: pasteboard)
        defer { monitor.stop() }
        pasteboard.clearContents()
        pasteboard.setString("Before clear", forType: .string)
        monitor.poll()
        monitor.clearHistory()
        pasteboard.clearContents()
        pasteboard.setString("After clear", forType: .string)
        monitor.poll()
        try await waitForCount(1, in: history)
        try await Task.sleep(for: .milliseconds(100))
        try expect(history.entries.count == 1)
        try expect(history.entries[0].accessibilitySummary == "After clear")
    }

    private func waitForCount(_ count: Int, in history: HistoryStore) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while history.entries.count != count && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(history.entries.count == count)
    }

    private func makePNG() throws -> Data {
        let context = try require(
            CGContext(
                data: nil, width: 16, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
        context.setFillColor(CGColor(red: 0.15, green: 0.55, blue: 0.75, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 8))
        let image = try require(context.makeImage())
        let output = try require(CFDataCreateMutable(nil, 0))
        let destination = try require(
            CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
