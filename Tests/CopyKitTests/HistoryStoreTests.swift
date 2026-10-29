import Foundation

#if !COPYKIT_STANDALONE
    @testable import CopyKit
#endif

@MainActor
struct HistoryStoreTests {
    func keepsTheLatestSixCopiesInOrder() throws {
        let store = HistoryStore()
        let entries = (1...8).map { ClipboardEntry(content: .text("Item \($0)")) }
        for entry in entries { store.insert(entry) }
        try expect(store.entries.map(\.id) == entries.suffix(6).reversed().map(\.id))
    }

    func preservesSeparateExternalCopiesOfTheSameText() throws {
        let store = HistoryStore()
        store.insert(ClipboardEntry(content: .text("Repeated")))
        store.insert(ClipboardEntry(content: .text("Repeated")))
        try expect(store.entries.count == 2)
        try expect(store.entries[0].id != store.entries[1].id)
    }

    func rejectsOversizedEntriesWithoutEvictingHistory() throws {
        let store = HistoryStore()
        let original = ClipboardEntry(content: .text("Keep me"))
        store.insert(original)
        let large = ClipboardEntry(content: .text(String(repeating: "x", count: HistoryStore.maximumEntryBytes + 1)))
        try expect(!store.insert(large))
        try expect(store.entries.map(\.id) == [original.id])
    }

    func evictsOldestEntriesToRespectTheMemoryBudget() throws {
        let store = HistoryStore()
        let text = String(repeating: "x", count: 16 * 1_024 * 1_024)
        let entries = (0..<4).map { _ in ClipboardEntry(content: .text(text)) }
        for entry in entries { store.insert(entry) }
        try expect(store.entries.map(\.id) == entries.suffix(3).reversed().map(\.id))
        try expect(store.byteCount <= HistoryStore.maximumHistoryBytes)
    }

    func clearingRemovesAllRetainedHistory() throws {
        let store = HistoryStore()
        store.insert(ClipboardEntry(content: .text("Temporary")))
        store.clear()
        try expect(store.entries.isEmpty)
        try expect(store.byteCount == 0)
    }
}
