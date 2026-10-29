import AppKit

#if !COPYKIT_STANDALONE
    @testable import CopyKit
#endif

struct PanelLayoutTests {
    func keepsAllHistorySizesAboveTheBottomDock() throws {
        let visibleFrame = NSRect(x: 0, y: 86, width: 1512, height: 858)
        for height in [234.0, 336.0, 464.0, 520.0] {
            let frame = PanelLayout.frame(for: NSSize(width: 370, height: height), in: visibleFrame)
            try expect(visibleFrame.contains(frame))
            try expect(frame.minY == 106)
            try expect(frame.maxX == visibleFrame.maxX - 20)
        }
    }

    func respectsSideDocksAndDisplaysWithNegativeCoordinates() throws {
        for visibleFrame in [
            NSRect(x: -1920, y: -200, width: 1824, height: 1056),
            NSRect(x: 96, y: 0, width: 1416, height: 958),
            NSRect(x: 0, y: 982, width: 1512, height: 958),
        ] {
            let frame = PanelLayout.frame(for: NSSize(width: 370, height: 464), in: visibleFrame)
            try expect(visibleFrame.contains(frame))
            try expect(frame.minY == visibleFrame.minY + 20)
            try expect(frame.maxX == visibleFrame.maxX - 20)
        }
    }

    @MainActor
    func measuresTheCurrentSnapshotBeforePlacingTheWindow() throws {
        _ = NSApplication.shared
        var heights: [CGFloat] = []
        for count in [0, 4, 6] {
            let state = PanelState()
            state.entries = (0..<count).map { ClipboardEntry(content: .text("Sample \($0)")) }
            let content = PanelContentController(state: state, onChoose: { _ in })
            let size = content.measuredSize
            try expect(size.width == 370)
            try expect(size.height > CGFloat(count * 60))
            heights.append(size.height)
        }
        try expect(heights[0] < heights[1] && heights[1] < heights[2])
    }

    @MainActor
    func errorMessagesAreIncludedInTheWindowHeight() throws {
        _ = NSApplication.shared
        let state = PanelState()
        state.entries = (0..<6).map { ClipboardEntry(content: .text("Sample \($0)")) }
        let normalHeight = PanelContentController(state: state, onChoose: { _ in }).measuredSize.height
        state.message = "Could not copy this item. Please try again."
        let errorHeight = PanelContentController(state: state, onChoose: { _ in }).measuredSize.height
        try expect(errorHeight > normalHeight)
    }

    @MainActor
    func lateLayoutDoesNotResizeThePositionedWindow() async throws {
        _ = NSApplication.shared
        let state = PanelState()
        state.entries = (0..<4).map { ClipboardEntry(content: .text("Sample \($0)")) }
        let content = PanelContentController(state: state, onChoose: { _ in })
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentViewController = content
        defer {
            panel.contentViewController = nil
            panel.close()
        }
        let expected = PanelLayout.frame(
            for: content.measuredSize, in: NSRect(x: 0, y: 86, width: 1512, height: 858)
        )
        panel.setFrame(expected, display: false)
        // Exercise an asynchronous size invalidation without opening a window or touching the clipboard.
        state.message = "A longer message that changes the SwiftUI content height after the initial layout."
        try await Task.sleep(for: .milliseconds(100))
        content.view.layoutSubtreeIfNeeded()
        try expect(panel.frame == expected)
    }
}
