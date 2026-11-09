import AppKit

#if !COPYKIT_STANDALONE
    @testable import CopyKit
#endif

@MainActor
struct ImagePinTests {
    func initialImagesFitEachDisplayWithoutDistortion() throws {
        for screen in [
            NSRect(x: 0, y: 86, width: 1512, height: 858),
            NSRect(x: -1920, y: -200, width: 1824, height: 1056),
            NSRect(x: 0, y: 0, width: 320, height: 240),
        ] {
            for size in [NSSize(width: 4000, height: 3000), NSSize(width: 10, height: 2000)] {
                let frame = ImagePinLayout.initialFrame(imageSize: size, in: screen)
                try expect(screen.contains(frame))
                try expect(abs(frame.width / frame.height - size.width / size.height) < 0.001)
                try expect(abs(frame.midX - screen.midX) < 0.001)
                try expect(abs(frame.midY - screen.midY) < 0.001)
            }
        }
    }

    func zoomPreservesTheCursorAnchorAndClampsAtDisplayEdges() throws {
        let screen = NSRect(x: -1920, y: -200, width: 1920, height: 1080)
        let frame = NSRect(x: -1500, y: 100, width: 400, height: 200)
        let anchor = NSPoint(x: -1400, y: 150)
        let zoomed = ImagePinLayout.resizedFrame(frame, factor: 1.5, anchor: anchor, in: screen)
        try expect(zoomed.width == 600 && zoomed.height == 300)
        try expect((anchor.x - zoomed.minX) / zoomed.width == 0.25)
        try expect((anchor.y - zoomed.minY) / zoomed.height == 0.25)
        for factor in [0.0001, 10000] {
            let result = ImagePinLayout.resizedFrame(frame, factor: factor, anchor: anchor, in: screen)
            try expect(screen.contains(result))
            try expect(max(result.width, result.height) >= 64)
            try expect(abs(result.width / result.height - 2) < 0.001)
        }
    }

    func mousePinsImagesWhileKeyboardAndCopyButtonsStillCopy() throws {
        _ = NSApplication.shared
        let image = try imageEntry()
        let text = ClipboardEntry(content: .text("Example"))
        let controller = ClipboardPanelController()
        var copied: [UUID] = []
        var pinned: [UUID] = []
        controller.onChoose = {
            copied.append($0.id)
            return true
        }
        controller.onPin = {
            pinned.append($0.id)
            return true
        }
        controller.state.entries = [image, text]
        controller.choose(0, pinImage: true)
        try expect(pinned == [image.id] && copied.isEmpty)
        try expect(controller.state.entries.isEmpty)
        controller.state.entries = [image, text]
        controller.choose(0)
        try expect(copied == [image.id])
        controller.state.entries = [image, text]
        controller.choose(1, pinImage: true)
        try expect(copied == [image.id, text.id] && pinned == [image.id])
    }

    func escapeClosesOnlyTheTargetImageAndReleasesItsCallback() throws {
        _ = NSApplication.shared
        let first = try require(PinnedImageController(entry: imageEntry()))
        let second = try require(PinnedImageController(entry: imageEntry()))
        defer { second.panel.close() }
        var firstClosed = false
        var secondClosed = false
        first.onClose = { firstClosed = true }
        second.onClose = { secondClosed = true }
        try expect(first.panel.level == .floating)
        try expect(first.panel.canBecomeKey && !first.panel.canBecomeMain)
        let escape = try require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: first.panel.windowNumber, context: nil,
                characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53
            ))
        first.panel.sendEvent(escape)
        try expect(firstClosed && !secondClosed)
        try expect(first.onClose == nil)
    }

    func invalidImagesFailWithoutDismissingHistory() throws {
        _ = NSApplication.shared
        let invalid = ClipboardEntry(
            content: .image(data: Data([0, 1]), type: "public.png", thumbnail: Data(), width: 10, height: 10)
        )
        try expect(PinnedImageController(entry: invalid) == nil)
        try expect(PinnedImageController(entry: ClipboardEntry(content: .text("Text"))) == nil)
        let controller = ClipboardPanelController()
        defer { controller.hide() }
        controller.state.entries = [invalid]
        controller.onPin = { _ in false }
        controller.choose(0, pinImage: true)
        try expect(controller.state.entries.count == 1)
        try expect(controller.state.message == "Could not open this image. Please try again.")
    }

    private func imageEntry() throws -> ClipboardEntry {
        let bitmap = try require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 40, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0
            ))
        let data = try require(bitmap.representation(using: .png, properties: [:]))
        return ClipboardEntry(content: .image(data: data, type: "public.png", thumbnail: data, width: 80, height: 40))
    }
}
