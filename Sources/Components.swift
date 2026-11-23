import SwiftUI

/// Wrapping row layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let w = rows.map { $0.width }.max() ?? 0
        let h = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [], cur = Row()
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let needed = cur.items.isEmpty ? s.width : cur.width + spacing + s.width
            if needed > width, !cur.items.isEmpty { rows.append(cur); cur = Row() }
            cur.width = cur.items.isEmpty ? s.width : cur.width + spacing + s.width
            cur.height = max(cur.height, s.height)
            cur.items.append(i)
        }
        if !cur.items.isEmpty { rows.append(cur) }
        return rows
    }
}

struct TagChip: View {
    let text: String
    var color: Color = themeColor
    var selected = true
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if let onRemove {
                Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(text)")
            }
        }
        .font(.callout)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .background(Capsule().fill(selected ? color.opacity(0.22) : Color.secondary.opacity(0.08)))
        .overlay(Capsule().strokeBorder(selected ? color.opacity(0.65) : Color.secondary.opacity(0.18), lineWidth: 1))
    }
}

struct EmotionDots: View {
    let emotions: [String]
    var size: CGFloat = 8
    var body: some View {
        HStack(spacing: 3) {
            ForEach(emotions.prefix(5), id: \.self) { Circle().fill(emotionColor($0)).frame(width: size, height: size) }
        }
        .accessibilityLabel(emotions.joined(separator: ", "))
    }
}

struct Card<Content: View>: View {
    let title: String
    var subtitle: String?
    var icon: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let icon { Image(systemName: icon).foregroundStyle(.secondary) }
                Text(title).font(.headline)
                Spacer()
            }
            if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary).padding(.top, -8) }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: 12)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(.indigo)
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: 12)
        .accessibilityElement(children: .combine)
    }
}

struct VividnessPicker: View {
    @Binding var value: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= value ? "sparkle" : "circle")
                    .font(.system(size: i <= value ? 15 : 9, weight: .semibold))
                    .foregroundStyle(i <= value ? Color.indigo : Color.secondary.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .onTapGesture { value = i }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Vividness \(value) of 5")
        .accessibilityAdjustableAction { dir in value = dir == .increment ? min(5, value + 1) : max(1, value - 1) }
    }
}

/// Soft gradient night sky with a few stars, used on the lock screen and welcome sheet.
struct NightSky: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.07, blue: 0.22), Color(red: 0.22, green: 0.15, blue: 0.42),
                                    Color(red: 0.42, green: 0.26, blue: 0.52)], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var rng = SeededRandom(seed: 7)
                for _ in 0..<90 {
                    let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height * 0.85)
                    let r = 0.4 + rng.next() * 1.4
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: r, height: r)), with: .color(.white.opacity(0.3 + rng.next() * 0.6)))
                }
            }
        }
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return CGFloat(state % 10_000) / 10_000
    }
}

struct ReflectionNote: View {
    var body: some View {
        Label("Patterns reflect what you've written — they're for personal reflection, not diagnosis or prediction.",
              systemImage: "leaf")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

extension DateFormatter {
    static let long: DateFormatter = { let f = DateFormatter(); f.dateStyle = .long; return f }()
    static let medium: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; return f }()
    static func fmt(_ format: String) -> DateFormatter { let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate(format); return f }
}
