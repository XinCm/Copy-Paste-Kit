import AppKit
import SwiftUI

enum PanelLayout {
    static let margin: CGFloat = 20

    static func frame(for contentSize: NSSize, in visibleFrame: NSRect) -> NSRect {
        let size = NSSize(width: ceil(contentSize.width), height: ceil(contentSize.height))
        return NSRect(
            origin: NSPoint(
                x: max(visibleFrame.minX, visibleFrame.maxX - size.width - margin),
                y: max(visibleFrame.minY, min(visibleFrame.minY + margin, visibleFrame.maxY - size.height))
            ),
            size: size
        )
    }
}

@MainActor
final class PanelContentController: NSHostingController<ClipboardPanelView> {
    init(state: PanelState, onChoose: @escaping (Int) -> Void) {
        super.init(rootView: ClipboardPanelView(state: state, onChoose: onChoose))
        // AppKit owns the complete window frame. Late SwiftUI constraints must not move its bottom edge.
        sizingOptions = []
    }

    required init?(coder: NSCoder) { nil }

    var measuredSize: NSSize {
        sizeThatFits(in: NSSize(width: 370, height: CGFloat.greatestFiniteMagnitude))
    }
}
