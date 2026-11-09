import AppKit

enum ImagePinLayout {
    static func initialFrame(imageSize: NSSize, in visibleFrame: NSRect) -> NSRect {
        let scale = min(1, min(560 / imageSize.width, 420 / imageSize.height))
        let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let frame = NSRect(
            x: visibleFrame.midX - size.width / 2, y: visibleFrame.midY - size.height / 2,
            width: size.width, height: size.height
        )
        return resizedFrame(frame, factor: 1, anchor: NSPoint(x: frame.midX, y: frame.midY), in: visibleFrame)
    }

    static func resizedFrame(_ frame: NSRect, factor: CGFloat, anchor: NSPoint, in visibleFrame: NSRect) -> NSRect {
        guard frame.width > 0, frame.height > 0, factor.isFinite, factor > 0 else { return frame }
        let available = visibleFrame.insetBy(dx: 12, dy: 12)
        guard available.width > 0, available.height > 0 else { return frame }
        let maximum = min(available.width / frame.width, available.height / frame.height)
        let minimum = min(maximum, 64 / max(frame.width, frame.height))
        let scale = min(maximum, max(minimum, factor))
        let size = NSSize(width: frame.width * scale, height: frame.height * scale)
        let origin = NSPoint(
            x: anchor.x - (anchor.x - frame.minX) * scale,
            y: anchor.y - (anchor.y - frame.minY) * scale
        )
        return NSRect(
            x: min(max(origin.x, available.minX), available.maxX - size.width),
            y: min(max(origin.y, available.minY), available.maxY - size.height),
            width: size.width, height: size.height
        )
    }
}
