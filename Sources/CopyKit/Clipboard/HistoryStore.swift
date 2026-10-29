import Combine
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    nonisolated static let maximumEntries = 6
    nonisolated static let maximumEntryBytes = 20 * 1_024 * 1_024
    nonisolated static let maximumHistoryBytes = 60 * 1_024 * 1_024

    @Published private(set) var entries: [ClipboardEntry] = []

    var byteCount: Int { entries.reduce(0) { $0 + $1.byteCount } }

    @discardableResult
    func insert(_ entry: ClipboardEntry) -> Bool {
        guard entry.byteCount <= Self.maximumEntryBytes else { return false }
        entries.insert(entry, at: 0)
        while entries.count > Self.maximumEntries || byteCount > Self.maximumHistoryBytes {
            entries.removeLast()
        }
        return true
    }

    func clear() {
        entries.removeAll()
    }
}
