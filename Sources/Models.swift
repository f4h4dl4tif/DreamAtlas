import Foundation
import SwiftUI

enum TagKind: String, Codable, Hashable, CaseIterable {
    case emotion, theme
    var title: String { self == .emotion ? "Emotions" : "Themes" }
    var singular: String { self == .emotion ? "emotion" : "theme" }
}

struct Dream: Identifiable, Codable, Hashable {
    var id = UUID()
    /// The morning you woke up from it.
    var date: Date = Calendar.current.startOfDay(for: Date())
    var title = ""
    var text = ""
    var emotions: [String] = []
    var themes: [String] = []
    var vividness = 3          // 1...5
    var wakingMood = 0         // -2...2
    var lucid = false
    var recurring = false
    var created = Date()
    var modified = Date()

    init() {}

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        if firstLine.isEmpty { return "Untitled dream" }
        return firstLine.count > 60 ? String(firstLine.prefix(57)) + "…" : firstLine
    }

    var excerpt: String {
        text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    }

    func tags(_ kind: TagKind) -> [String] { kind == .emotion ? emotions : themes }

    // Tolerant decoding so older or newer journal files always open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        emotions = try c.decodeIfPresent([String].self, forKey: .emotions) ?? []
        themes = try c.decodeIfPresent([String].self, forKey: .themes) ?? []
        vividness = try c.decodeIfPresent(Int.self, forKey: .vividness) ?? 3
        wakingMood = try c.decodeIfPresent(Int.self, forKey: .wakingMood) ?? 0
        lucid = try c.decodeIfPresent(Bool.self, forKey: .lucid) ?? false
        recurring = try c.decodeIfPresent(Bool.self, forKey: .recurring) ?? false
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? date
        modified = try c.decodeIfPresent(Date.self, forKey: .modified) ?? created
    }
}

struct JournalData: Codable {
    var version = 1
    var dreams: [Dream] = []
    /// Tags the user created that aren't in the built-in lists (kept even if no dream uses them yet).
    var customEmotions: [String] = []
    var customThemes: [String] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        dreams = try c.decodeIfPresent([Dream].self, forKey: .dreams) ?? []
        customEmotions = try c.decodeIfPresent([String].self, forKey: .customEmotions) ?? []
        customThemes = try c.decodeIfPresent([String].self, forKey: .customThemes) ?? []
    }
}

enum Catalog {
    static let emotions: [(String, Double)] = [
        ("Joy", 0.13), ("Wonder", 0.76), ("Calm", 0.48), ("Love", 0.94), ("Excitement", 0.07),
        ("Curiosity", 0.55), ("Relief", 0.36), ("Nostalgia", 0.10), ("Confusion", 0.25),
        ("Anxiety", 0.03), ("Fear", 0.0), ("Sadness", 0.60), ("Anger", 0.98), ("Shame", 0.84),
        ("Loneliness", 0.66),
    ]
    static let themes = [
        "Flying", "Falling", "Being chased", "Water", "Home", "Childhood", "School", "Work",
        "Travel", "Family", "Friends", "Strangers", "Animals", "Nature", "City", "Being lost",
        "Losing something", "Teeth", "Exams", "Late", "Vehicles", "Food", "Celebration", "Darkness",
    ]
    static let moods = ["Heavy", "Uneasy", "Neutral", "Light", "Bright"]   // waking mood -2...2

    static func moodLabel(_ v: Int) -> String { moods[max(0, min(4, v + 2))] }
}

/// Stable colour for an emotion (built-ins get a hand-picked hue, custom ones a hue derived from the name).
func emotionColor(_ name: String) -> Color {
    if let hue = Catalog.emotions.first(where: { $0.0.caseInsensitiveCompare(name) == .orderedSame })?.1 {
        return Color(hue: hue, saturation: 0.58, brightness: 0.86)
    }
    let sum = name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    return Color(hue: Double(sum % 360) / 360, saturation: 0.45, brightness: 0.8)
}

let themeColor = Color.indigo

enum TimeRange: String, CaseIterable, Identifiable {
    case month = "30 days", quarter = "90 days", year = "Year", all = "All time"
    var id: String { rawValue }
    var start: Date? {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        switch self {
        case .month: return cal.date(byAdding: .day, value: -29, to: today)
        case .quarter: return cal.date(byAdding: .day, value: -89, to: today)
        case .year: return cal.date(byAdding: .year, value: -1, to: today)
        case .all: return nil
        }
    }
}

extension Date {
    var day: Date { Calendar.current.startOfDay(for: self) }
}
