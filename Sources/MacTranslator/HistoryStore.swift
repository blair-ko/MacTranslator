import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []

    private let maxItems = 200
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("MacTranslator", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("history.json")
        load()
    }

    func add(sourceText: String, translatedText: String, sourceLangCode: String, targetLangCode: String) {
        let s = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !t.isEmpty else { return }

        var existingFav = false
        if let idx = items.firstIndex(where: { $0.sourceText == s && $0.targetLangCode == targetLangCode }) {
            existingFav = items[idx].isFavorite
            items.remove(at: idx)
        }

        let newItem = HistoryItem(
            timestamp: Date(),
            sourceText: s,
            translatedText: t,
            sourceLangCode: sourceLangCode,
            targetLangCode: targetLangCode,
            isFavorite: existingFav
        )

        items.insert(newItem, at: 0)

        if items.count > maxItems {
            // 優先保留已收藏項目
            let favorites = items.filter { $0.isFavorite }
            let nonFavorites = items.filter { !$0.isFavorite }
            let allowedNonFavCount = max(0, maxItems - favorites.count)
            items = (favorites + nonFavorites.prefix(allowedNonFavCount))
                .sorted { $0.timestamp > $1.timestamp }
        }

        save()
    }

    func toggleFavorite(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isFavorite.toggle()
        save()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearAll(keepFavorites: Bool = true) {
        if keepFavorites {
            items.removeAll { !$0.isFavorite }
        } else {
            items.removeAll()
        }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        self.items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
