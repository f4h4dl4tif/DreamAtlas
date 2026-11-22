import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    @State private var filter: String?

    private var dreams: [Dream] {
        let all = store.sortedDreams
        guard let filter else { return all }
        return all.filter { $0.emotions.contains(filter) || $0.themes.contains(filter) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                DreamCalendar(dreams: store.data.dreams).padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 12)
                filterBar.padding(.horizontal, 28).padding(.bottom, 8)
                ForEach(months, id: \.0) { title, items in
                    Section {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, d in
                            TimelineRow(dream: d, isLast: i == items.count - 1)
                                .contentShape(Rectangle())
                                .onTapGesture { state.open(d.id) }
                        }
                    } header: {
                        HStack {
                            Text(title).font(.title3.weight(.semibold))
                            Text("\(items.count) \(items.count == 1 ? "dream" : "dreams")").foregroundStyle(.secondary)
                            Spacer()
                            EmotionDots(emotions: topEmotions(items), size: 10)
                        }
                        .padding(.horizontal, 28).padding(.vertical, 8)
                        .background(.bar)
                    }
                }
                if dreams.isEmpty {
                    ContentUnavailableView("No dreams yet", systemImage: "calendar.day.timeline.left",
                                           description: Text("Your timeline fills in as you record dreams."))
                        .padding(.top, 40)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Timeline")
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Text("Highlight:").foregroundStyle(.secondary)
            Menu(filter ?? "All dreams") {
                Button("All dreams") { filter = nil }
                Divider()
                Section("Emotions") { ForEach(store.usage(.emotion).prefix(15), id: \.name) { t in Button(t.name) { filter = t.name } } }
                Section("Themes") { ForEach(store.usage(.theme).prefix(20), id: \.name) { t in Button(t.name) { filter = t.name } } }
            }
            .fixedSize()
            if filter != nil { Button("Clear") { filter = nil }.buttonStyle(.link) }
            Spacer()
        }
        .font(.callout)
    }

    private var months: [(String, [Dream])] {
        let f = DateFormatter.fmt("MMMM yyyy")
        var out: [(String, [Dream])] = []
        for d in dreams {
            let k = f.string(from: d.date)
            if out.last?.0 == k { out[out.count - 1].1.append(d) } else { out.append((k, [d])) }
        }
        return out
    }

    private func topEmotions(_ items: [Dream]) -> [String] {
        store.usage(.emotion, in: items).prefix(5).map(\.name)
    }
}

struct TimelineRow: View {
    let dream: Dream
    let isLast: Bool
    private static let dayF = DateFormatter.fmt("EEE d")

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(Self.dayF.string(from: dream.date))
                .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing).padding(.top, 14)
            ZStack(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 2).padding(.bottom, isLast ? 40 : 0)
                Circle()
                    .fill(dream.emotions.first.map(emotionColor) ?? Color.secondary.opacity(0.5))
                    .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                    .frame(width: 10 + CGFloat(dream.vividness) * 2, height: 10 + CGFloat(dream.vividness) * 2)
                    .padding(.top, 14)
            }
            .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(dream.displayTitle).font(.headline)
                    if dream.lucid { Label("Lucid", systemImage: "eye").labelStyle(.iconOnly).foregroundStyle(.indigo) }
                    if dream.recurring { Label("Recurring", systemImage: "arrow.triangle.2.circlepath").labelStyle(.iconOnly).foregroundStyle(.indigo) }
                    Spacer()
                    Text("woke \(Catalog.moodLabel(dream.wakingMood).lowercased())").font(.caption).foregroundStyle(.secondary)
                }
                if !dream.excerpt.isEmpty {
                    Text(dream.excerpt).foregroundStyle(.secondary).lineLimit(2)
                }
                if !dream.emotions.isEmpty || !dream.themes.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(dream.emotions, id: \.self) { TagChip(text: $0, color: emotionColor($0)) }
                        ForEach(dream.themes, id: \.self) { TagChip(text: $0, selected: false) }
                    }
                    .font(.caption)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
            .padding(.vertical, 5)
        }
        .padding(.horizontal, 28)
    }
}

/// A year of nights at a glance: one square per day, darker when more dreams were recorded.
struct DreamCalendar: View {
    let dreams: [Dream]
    @EnvironmentObject var state: AppState
    private let cell: CGFloat = 11, gap: CGFloat = 3

    var body: some View {
        let cal = Calendar.current
        let today = Date().day
        let counts = Dictionary(grouping: dreams, by: { $0.date.day }).mapValues(\.count)
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)!.start
        let start = cal.date(byAdding: .weekOfYear, value: -52, to: thisWeek)!
        let recorded = counts.filter { $0.key >= start }.count

        Card(title: "Dream calendar", subtitle: "\(recorded) nights remembered in the last year · \(JournalStore.shared.streak)-day streak", icon: "calendar") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(0..<53, id: \.self) { w in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { d in
                                let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                                let n = counts[date] ?? 0
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(date > today ? Color.clear : n == 0 ? Color.secondary.opacity(0.12) : Color.indigo.opacity(min(1, 0.35 + 0.3 * Double(n))))
                                    .frame(width: cell, height: cell)
                                    .help(n == 0 ? DateFormatter.medium.string(from: date) : "\(DateFormatter.medium.string(from: date)): \(n) dream\(n == 1 ? "" : "s")")
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
            HStack(spacing: 4) {
                Spacer()
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.12, 0.45, 0.7, 1.0], id: \.self) { o in
                    RoundedRectangle(cornerRadius: 2).fill(o == 0.12 ? Color.secondary.opacity(o) : Color.indigo.opacity(o)).frame(width: 9, height: 9)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
