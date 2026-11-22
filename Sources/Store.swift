import AppKit
import Foundation
import NaturalLanguage
import SwiftUI

/// Single source of truth. Everything lives in ~/Library/Application Support/DreamAtlas/journal.json
/// on this Mac only — DreamAtlas makes no network requests.
@MainActor
final class JournalStore: ObservableObject {
    static let shared = JournalStore()

    @Published var data = JournalData() { didSet { scheduleSave() } }
    @Published var lastError: String?

    let folder: URL
    private var fileURL: URL { folder.appendingPathComponent("journal.json") }
    private var saveWork: DispatchWorkItem?
    private var loading = false
    private var wordCache: [UUID: (Date, [String])] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("DreamAtlas", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Owner-only permissions on the journal folder.
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        load()
    }

    // MARK: Persistence

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func load() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        do {
            loading = true
            data = try Self.decoder.decode(JournalData.self, from: raw)
            loading = false
        } catch {
            loading = false
            let bad = folder.appendingPathComponent("journal-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: bad)
            lastError = "Your journal file couldn't be read. A copy was kept at \(bad.path)."
        }
    }

    private func scheduleSave() {
        guard !loading else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveNow() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        do {
            try Self.encoder.encode(data).write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    func exportBackup(to url: URL) throws {
        try Self.encoder.encode(data).write(to: url, options: .atomic)
    }

    func importBackup(from url: URL) throws {
        let imported = try Self.decoder.decode(JournalData.self, from: Data(contentsOf: url))
        saveNow()
        let safety = folder.appendingPathComponent("journal-before-import-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.copyItem(at: fileURL, to: safety)
        data = imported
    }

    func exportMarkdown(to url: URL) throws {
        let df = DateFormatter(); df.dateStyle = .full
        var out = "# Dream Journal\n\n_Exported from DreamAtlas on \(df.string(from: Date()))_\n\n"
        for d in sortedDreams.reversed() {
            out += "## \(d.displayTitle)\n\n**\(df.string(from: d.date))**"
            if d.lucid { out += " · lucid" }
            if d.recurring { out += " · recurring" }
            out += " · vividness \(d.vividness)/5 · woke feeling \(Catalog.moodLabel(d.wakingMood).lowercased())\n\n"
            if !d.emotions.isEmpty { out += "Emotions: \(d.emotions.joined(separator: ", "))  \n" }
            if !d.themes.isEmpty { out += "Themes: \(d.themes.joined(separator: ", "))\n" }
            out += "\n\(d.text)\n\n---\n\n"
        }
        try out.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Dreams

    var sortedDreams: [Dream] { data.dreams.sorted { ($0.date, $0.created) > ($1.date, $1.created) } }
    func dream(_ id: UUID?) -> Dream? { id.flatMap { id in data.dreams.first { $0.id == id } } }

    func add(_ dream: Dream) { data.dreams.append(dream) }

    func update(_ dream: Dream) {
        guard let i = data.dreams.firstIndex(where: { $0.id == dream.id }), data.dreams[i] != dream else { return }
        var d = dream
        d.modified = Date()
        data.dreams[i] = d
    }

    func delete(_ id: UUID) {
        data.dreams.removeAll { $0.id == id }
        wordCache[id] = nil
    }

    // MARK: Tags

    /// Every tag of a kind: built-ins, custom ones and anything used in a dream.
    func catalog(_ kind: TagKind) -> [String] {
        let builtIn = kind == .emotion ? Catalog.emotions.map(\.0) : Catalog.themes
        let custom = kind == .emotion ? data.customEmotions : data.customThemes
        var seen = Set<String>(), out: [String] = []
        for t in builtIn + custom + data.dreams.flatMap({ $0.tags(kind) }) where seen.insert(t.lowercased()).inserted {
            out.append(t)
        }
        return out
    }

    func addCustom(_ name: String, kind: TagKind) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = catalog(kind).first(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) { return existing }
        if kind == .emotion { data.customEmotions.append(n) } else { data.customThemes.append(n) }
        return n
    }

    /// Tags actually used, most frequent first.
    func usage(_ kind: TagKind, in dreams: [Dream]? = nil) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for d in dreams ?? data.dreams { for t in Set(d.tags(kind)) { counts[t, default: 0] += 1 } }
        let items: [(name: String, count: Int)] = counts.map { (name: $0.key, count: $0.value) }
        return items.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    func rename(_ old: String, to new: String, kind: TagKind) {
        let n = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, n != old else { return }
        var d = data
        for i in d.dreams.indices {
            var tags = d.dreams[i].tags(kind)
            guard tags.contains(old) else { continue }
            tags = tags.map { $0 == old ? n : $0 }
            var seen = Set<String>(); tags = tags.filter { seen.insert($0).inserted }   // merging two tags
            if kind == .emotion { d.dreams[i].emotions = tags } else { d.dreams[i].themes = tags }
        }
        if kind == .emotion {
            d.customEmotions = d.customEmotions.map { $0 == old ? n : $0 }
            if !Catalog.emotions.contains(where: { $0.0 == n }), !d.customEmotions.contains(n) { d.customEmotions.append(n) }
        } else {
            d.customThemes = d.customThemes.map { $0 == old ? n : $0 }
            if !Catalog.themes.contains(n), !d.customThemes.contains(n) { d.customThemes.append(n) }
        }
        data = d
    }

    func removeTag(_ name: String, kind: TagKind) {
        var d = data
        for i in d.dreams.indices {
            if kind == .emotion { d.dreams[i].emotions.removeAll { $0 == name } } else { d.dreams[i].themes.removeAll { $0 == name } }
        }
        d.customEmotions.removeAll { $0 == name }
        d.customThemes.removeAll { $0 == name }
        data = d
    }

    // MARK: Patterns

    func dreams(in range: TimeRange) -> [Dream] {
        guard let start = range.start else { return data.dreams }
        return data.dreams.filter { $0.date >= start }
    }

    /// Consecutive days (ending today or yesterday) with at least one dream recorded.
    var streak: Int {
        let days = Set(data.dreams.map(\.date.day))
        let cal = Calendar.current
        var day = Date().day
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while days.contains(day) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        return n
    }

    /// Meaningful nouns from a dream's text, lemmatised on-device with NaturalLanguage. Cached per edit.
    func words(for dream: Dream) -> [String] {
        if let (stamp, w) = wordCache[dream.id], stamp == dream.modified { return w }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = dream.text
        var out: [String] = []
        let opts: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        tagger.enumerateTags(in: dream.text.startIndex..<dream.text.endIndex, unit: .word, scheme: .lexicalClass, options: opts) { tag, range in
            guard tag == .noun else { return true }
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? String(dream.text[range])
            let w = lemma.lowercased()
            if w.count > 2, !Self.stopWords.contains(w) { out.append(w) }
            return true
        }
        wordCache[dream.id] = (dream.modified, out)
        return out
    }

    func recurringWords(in dreams: [Dream], limit: Int = 30) -> [(word: String, count: Int)] {
        var counts: [String: Int] = [:]
        for d in dreams { for w in Set(words(for: d)) { counts[w, default: 0] += 1 } }
        let items: [(word: String, count: Int)] = counts.filter { $0.value > 1 }.map { (word: $0.key, count: $0.value) }
        let sorted = items.sorted { $0.count != $1.count ? $0.count > $1.count : $0.word < $1.word }
        return Array(sorted.prefix(limit))
    }

    func themePairs(in dreams: [Dream], limit: Int = 6) -> [(a: String, b: String, count: Int)] {
        var counts: [String: Int] = [:]
        for d in dreams {
            let t = Array(Set(d.themes)).sorted()
            for i in t.indices { for j in t.indices where j > i { counts[t[i] + "\u{1}" + t[j], default: 0] += 1 } }
        }
        let sorted: [(key: String, value: Int)] = counts.filter { $0.value > 1 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        var out: [(a: String, b: String, count: Int)] = []
        for (k, v) in sorted.prefix(limit) {
            let parts = k.split(separator: "\u{1}").map(String.init)
            out.append((a: parts[0], b: parts[1], count: v))
        }
        return out
    }

    static let stopWords: Set<String> = [
        "dream", "thing", "time", "way", "something", "someone", "anything", "everything", "nothing", "everyone",
        "lot", "bit", "kind", "sort", "part", "moment", "point", "end", "side", "while", "day", "night", "morning",
        "people", "person", "one", "back", "front", "top", "bottom", "middle", "lots", "stuff", "place",
    ]
}
