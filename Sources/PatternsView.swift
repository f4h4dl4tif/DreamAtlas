import Charts
import SwiftUI

struct PatternsView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    @AppStorage("patternsRange") private var rangeRaw = TimeRange.quarter.rawValue

    private var range: TimeRange { TimeRange(rawValue: rangeRaw) ?? .quarter }

    var body: some View {
        let dreams = store.dreams(in: range)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Picker("Range", selection: $rangeRaw) {
                        ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 360)
                    Spacer()
                }
                if dreams.count < 3 {
                    ContentUnavailableView("Patterns need a few dreams", systemImage: "chart.bar.xaxis",
                                           description: Text("Record at least three dreams in this period and your recurring themes and feelings will appear here."))
                        .padding(.top, 40)
                } else {
                    stats(dreams)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16, alignment: .top), GridItem(.flexible(), spacing: 16, alignment: .top)], spacing: 16) {
                        themesCard(dreams)
                        emotionsCard(dreams)
                    }
                    emotionTimeline(dreams)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16, alignment: .top), GridItem(.flexible(), spacing: 16, alignment: .top)], spacing: 16) {
                        wordsCard(dreams)
                        pairsCard(dreams)
                        moodCard(dreams)
                        weekdayCard(dreams)
                    }
                }
                ReflectionNote().padding(.top, 4)
            }
            .padding(24)
        }
        .navigationTitle("Patterns")
        .navigationSubtitle(range == .all ? "All time" : "Last \(range.rawValue.lowercased())")
    }

    // MARK: Cards

    private func stats(_ dreams: [Dream]) -> some View {
        let nights = Set(dreams.map(\.date.day)).count
        let avgViv = Double(dreams.map(\.vividness).reduce(0, +)) / Double(max(1, dreams.count))
        return HStack(spacing: 12) {
            StatTile(value: "\(dreams.count)", label: "dreams recorded", icon: "moon.stars")
            StatTile(value: "\(nights)", label: "nights remembered", icon: "calendar")
            StatTile(value: String(format: "%.1f", avgViv), label: "average vividness", icon: "sparkle")
            StatTile(value: "\(dreams.filter(\.lucid).count)", label: "lucid dreams", icon: "eye")
            StatTile(value: "\(dreams.filter(\.recurring).count)", label: "felt familiar", icon: "arrow.triangle.2.circlepath")
            StatTile(value: "\(store.streak)", label: "day streak", icon: "flame")
        }
    }

    private func themesCard(_ dreams: [Dream]) -> some View {
        let top = Array(store.usage(.theme, in: dreams).prefix(8))
        return Card(title: "Recurring themes", subtitle: "Click a theme to explore it", icon: "number") {
            if top.isEmpty { empty("Tag themes on your dreams to see them here.") } else {
                let maxC = CGFloat(top.first?.count ?? 1)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(top, id: \.name) { t in
                        Button { state.selection = .tag(.theme, t.name) } label: {
                            HStack(spacing: 10) {
                                Text(t.name).frame(width: 120, alignment: .leading).lineLimit(1)
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 4).fill(Color.indigo.gradient)
                                        .frame(width: max(6, g.size.width * CGFloat(t.count) / maxC))
                                }
                                .frame(height: 14)
                                Text("\(t.count)").foregroundStyle(.secondary).monospacedDigit().frame(width: 24, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Explore \(t.name)")
                    }
                }
            }
        }
    }

    private func emotionsCard(_ dreams: [Dream]) -> some View {
        let top = Array(store.usage(.emotion, in: dreams).prefix(8))
        return Card(title: "Emotional palette", subtitle: "How your dreams have felt", icon: "heart") {
            if top.isEmpty { empty("Tag emotions on your dreams to see them here.") } else {
                HStack(alignment: .center, spacing: 20) {
                    Chart(top, id: \.name) { t in
                        SectorMark(angle: .value("Dreams", t.count), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .foregroundStyle(emotionColor(t.name))
                            .cornerRadius(3)
                    }
                    .frame(width: 170, height: 170)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(top, id: \.name) { t in
                            Button { state.selection = .tag(.emotion, t.name) } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(emotionColor(t.name)).frame(width: 9, height: 9)
                                    Text(t.name)
                                    Spacer()
                                    Text("\(t.count)").foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func emotionTimeline(_ dreams: [Dream]) -> some View {
        let byWeek = range == .month || range == .quarter
        let unit: Calendar.Component = byWeek ? .weekOfYear : .month
        let top = Set(store.usage(.emotion, in: dreams).prefix(6).map(\.name))
        let cal = Calendar.current
        var rows: [String: [Date: Int]] = [:]
        for d in dreams {
            let bucket = cal.dateInterval(of: unit, for: d.date)!.start
            for e in Set(d.emotions) where top.contains(e) { rows[e, default: [:]][bucket, default: 0] += 1 }
        }
        let points = rows.flatMap { e, m in m.map { EmotionPoint(emotion: e, date: $0.key, count: $0.value) } }
        let names = store.usage(.emotion, in: dreams).prefix(6).map(\.name)

        return Card(title: "Emotions over time", subtitle: "Your six most frequent emotions, \(byWeek ? "week" : "month") by \(byWeek ? "week" : "month")", icon: "waveform.path.ecg") {
            if points.isEmpty { empty("Tag emotions on your dreams to see how they shift over time.") } else {
                Chart(points) { p in
                    BarMark(x: .value("Period", p.date, unit: unit), y: .value("Dreams", p.count))
                        .foregroundStyle(by: .value("Emotion", p.emotion))
                        .cornerRadius(2)
                }
                .chartForegroundStyleScale(domain: names, range: names.map(emotionColor))
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
            }
        }
    }

    private func wordsCard(_ dreams: [Dream]) -> some View {
        let words = store.recurringWords(in: dreams, limit: 28)
        let maxC = Double(words.first?.count ?? 1)
        return Card(title: "Recurring images", subtitle: "Things that keep showing up in your writing", icon: "text.magnifyingglass") {
            if words.isEmpty { empty("Words that appear in more than one dream will show up here.") } else {
                FlowLayout(spacing: 10, lineSpacing: 4) {
                    ForEach(words, id: \.word) { w in
                        Button {
                            state.search = w.word; state.selection = .journal
                        } label: {
                            Text(w.word)
                                .font(.system(size: 12 + 14 * Double(w.count) / maxC, weight: w.count == Int(maxC) ? .semibold : .regular, design: .serif))
                                .foregroundStyle(Color.indigo.opacity(0.45 + 0.55 * Double(w.count) / maxC))
                        }
                        .buttonStyle(.plain)
                        .help("In \(w.count) dreams — click to find them")
                    }
                }
                Text("Found on-device. Nothing is sent anywhere.").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func pairsCard(_ dreams: [Dream]) -> some View {
        let pairs = store.themePairs(in: dreams)
        return Card(title: "Themes that travel together", subtitle: "Themes that often appear in the same dream", icon: "link") {
            if pairs.isEmpty { empty("When two themes share several dreams, they'll appear here.") } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pairs, id: \.a) { p in
                        HStack(spacing: 6) {
                            tagLink(p.a, .theme)
                            Image(systemName: "plus").font(.caption2).foregroundStyle(.secondary)
                            tagLink(p.b, .theme)
                            Spacer()
                            Text("\(p.count) dreams").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func moodCard(_ dreams: [Dream]) -> some View {
        let cal = Calendar.current
        let unit: Calendar.Component = (range == .month || range == .quarter) ? .weekOfYear : .month
        let grouped = Dictionary(grouping: dreams) { cal.dateInterval(of: unit, for: $0.date)!.start }
        let points = grouped.map { (date: $0.key, mood: Double($0.value.map(\.wakingMood).reduce(0, +)) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
        return Card(title: "Waking mood", subtitle: "How you felt on waking, on average", icon: "sun.horizon") {
            Chart(points, id: \.date) { p in
                AreaMark(x: .value("Period", p.date, unit: unit), yStart: .value("Base", -2), yEnd: .value("Mood", p.mood))
                    .foregroundStyle(LinearGradient(colors: [.indigo.opacity(0.25), .indigo.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Period", p.date, unit: unit), y: .value("Mood", p.mood))
                    .foregroundStyle(.indigo)
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle().strokeBorder(lineWidth: 1.5))
            }
            .chartYScale(domain: -2...2)
            .chartYAxis {
                AxisMarks(values: [-2, 0, 2]) { v in
                    AxisGridLine()
                    AxisValueLabel { Text(Catalog.moodLabel(v.as(Int.self) ?? 0)) }
                }
            }
            .frame(height: 170)
        }
    }

    private func weekdayCard(_ dreams: [Dream]) -> some View {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 }
        var counts = [Int](repeating: 0, count: 7)
        for d in dreams { counts[cal.component(.weekday, from: d.date) - 1] += 1 }
        let rows = order.map { (day: symbols[$0], count: counts[$0]) }
        return Card(title: "Weekly rhythm", subtitle: "Which mornings you remember dreams", icon: "calendar.badge.clock") {
            Chart(rows, id: \.day) { r in
                BarMark(x: .value("Day", r.day), y: .value("Dreams", r.count))
                    .foregroundStyle(Color.indigo.opacity(0.75).gradient)
                    .cornerRadius(4)
            }
            .chartXScale(domain: rows.map(\.day))
            .frame(height: 170)
        }
    }

    // MARK: Helpers

    private func tagLink(_ name: String, _ kind: TagKind) -> some View {
        Button { state.selection = .tag(kind, name) } label: {
            TagChip(text: name, color: kind == .emotion ? emotionColor(name) : themeColor).font(.caption)
        }
        .buttonStyle(.plain)
    }

    private func empty(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
    }
}

/// Everything about one emotion or theme: when it shows up, what comes with it, and every dream it's in.
struct TagDetailView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    let kind: TagKind
    let name: String

    var body: some View {
        let dreams = store.sortedDreams.filter { $0.tags(kind).contains(name) }
        let color = kind == .emotion ? emotionColor(name) : themeColor
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Circle().fill(color.gradient).frame(width: 40, height: 40)
                        .overlay(Image(systemName: kind == .emotion ? "heart.fill" : "number").foregroundStyle(.white))
                    VStack(alignment: .leading) {
                        Text(name).font(.largeTitle.weight(.semibold))
                        Text(summary(dreams)).foregroundStyle(.secondary)
                    }
                }
                if !dreams.isEmpty {
                    Card(title: "When it shows up", subtitle: "Dreams with “\(name)” per month", icon: "chart.bar") {
                        let cal = Calendar.current
                        let grouped = Dictionary(grouping: dreams) { cal.dateInterval(of: .month, for: $0.date)!.start }.mapValues(\.count)
                        Chart(grouped.sorted { $0.key < $1.key }, id: \.key) { k, v in
                            BarMark(x: .value("Month", k, unit: .month), y: .value("Dreams", v))
                                .foregroundStyle(color.gradient).cornerRadius(3)
                        }
                        .frame(height: 150)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        Card(title: "Often felt with it", icon: "heart") { related(dreams, .emotion) }
                        Card(title: "Often appears with", icon: "number") { related(dreams, .theme) }
                    }
                }
                Text("Dreams").font(.headline).padding(.top, 4)
                ForEach(dreams) { d in
                    Button { state.open(d.id) } label: {
                        DreamRow(dream: d)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                }
                ReflectionNote()
            }
            .padding(24)
        }
        .navigationTitle(name)
        .navigationSubtitle(kind.singular.capitalized)
    }

    private func summary(_ dreams: [Dream]) -> String {
        guard let first = dreams.last, let last = dreams.first else { return "Not in any dreams yet" }
        let share = Int((Double(dreams.count) / Double(max(1, store.data.dreams.count)) * 100).rounded())
        return "In \(dreams.count) of your dreams (\(share)%) · first \(DateFormatter.medium.string(from: first.date)) · most recent \(DateFormatter.medium.string(from: last.date))"
    }

    @ViewBuilder private func related(_ dreams: [Dream], _ k: TagKind) -> some View {
        let items = store.usage(k, in: dreams).filter { $0.name != name }.prefix(8)
        if items.isEmpty {
            Text("Nothing yet").foregroundStyle(.secondary)
        } else {
            FlowLayout {
                ForEach(Array(items), id: \.name) { t in
                    Button { state.selection = .tag(k, t.name) } label: {
                        TagChip(text: "\(t.name) · \(t.count)", color: k == .emotion ? emotionColor(t.name) : themeColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EmotionPoint: Identifiable {
    let emotion: String
    let date: Date
    let count: Int
    var id: String { "\(emotion)-\(date.timeIntervalSince1970)" }
}
