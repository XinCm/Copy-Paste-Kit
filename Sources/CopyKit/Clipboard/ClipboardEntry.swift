import Foundation

struct ClipboardEntry: Identifiable, Sendable {
    enum Content: Sendable {
        case text(String)
        case image(data: Data, type: String, thumbnail: Data, width: Int, height: Int)
    }

    let id = UUID()
    let content: Content

    var byteCount: Int {
        switch content {
        case .text(let text): text.utf8.count
        case .image(let data, _, let thumbnail, _, _): data.count + thumbnail.count
        }
    }

    var accessibilitySummary: String {
        switch content {
        case .text(let text): String(text.prefix(160))
        case .image(_, _, _, let width, let height): "Image, \(width) by \(height) pixels"
        }
    }
}
