import SwiftUI

struct JournalView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState

    private var dreams: [Dream] {
        let q = state.search.trimmingCharacters(in: .whitespaces)
        let all = store.sortedDreams
        guard !q.isEmpty else { return all }
        return all.filter { d in
            d.title.localizedCaseInsensitiveContains(q) || d.text.localizedCaseInsensitiveContains(q)
                || (d.emotions + d.themes).contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        HSplitView {
            DreamList(dreams: dreams)
                .frame(minWidth: 250, idealWidth: 290, maxWidth: 380)
            Group {
                if let id = state.selectedDream, store.dream(id) != nil {
                    DreamEditor(id: id).id(id)
                } else if store.data.dreams.isEmpty {
                    ContentUnavailableView {
                        Label("Your dream journal is empty", systemImage: "moon.zzz")
                    } description: {
                        Text("Dreams fade fast — jot down whatever you remember as soon as you wake up.")
                    } actions: {
                        Button("Record a Dream") { state.newDream() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView("Select a dream", systemImage: "sparkles", description: Text("Or press ⌘N to record a new one."))
                }
            }
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $state.search, placement: .toolbar, prompt: "Search dreams, emotions, themes")
        .navigationTitle("Journal")
        .navigationSubtitle("\(store.data.dreams.count) dreams")
        .onAppear {
            if state.selectedDream == nil { state.selectedDream = dreams.first?.id }
        }
    }
}

struct DreamList: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    let dreams: [Dream]

    var body: some View {
        List(selection: $state.selectedDream) {
            ForEach(groups, id: \.0) { month, items in
                Section(month) {
                    ForEach(items) { d in
                        DreamRow(dream: d).tag(d.id)
                            .contextMenu {
                                Button("Delete Dream…", role: .destructive) { confirmDelete(d) }
                            }
                    }
                }
            }
        }
        .listStyle(.inset)
        .onDeleteCommand { if let d = store.dream(state.selectedDream) { confirmDelete(d) } }
        .overlay {
            if dreams.isEmpty && !state.search.isEmpty {
                ContentUnavailableView.search(text: state.search)
            }
        }
    }

    private var groups: [(String, [Dream])] {
        let f = DateFormatter.fmt("MMMM yyyy")
        var out: [(String, [Dream])] = []
        for d in dreams {
            let key = f.string(from: d.date)
            if out.last?.0 == key { out[out.count - 1].1.append(d) } else { out.append((key, [d])) }
        }
        return out
    }

    private func confirmDelete(_ d: Dream) {
        let a = NSAlert()
        a.messageText = "Delete “\(d.displayTitle)”?"
        a.informativeText = "This can't be undone. Consider backing up your journal first (File › Back Up Journal…)."
        a.addButton(withTitle: "Delete")
        a.addButton(withTitle: "Cancel")
        a.buttons.first?.hasDestructiveAction = true
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let next = dreams.firstIndex(of: d).flatMap { i in dreams.indices.contains(i + 1) ? dreams[i + 1].id : (i > 0 ? dreams[i - 1].id : nil) }
        store.delete(d.id)
        state.selectedDream = next
    }
}

struct DreamRow: View {
    let dream: Dream
    private static let dayF = DateFormatter.fmt("d")
    private static let wdF = DateFormatter.fmt("EEE")

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Text(Self.dayF.string(from: dream.date)).font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(Self.wdF.string(from: dream.date).uppercased()).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(dream.displayTitle).font(.headline).lineLimit(1)
                    if dream.lucid { Image(systemName: "eye").font(.caption2).foregroundStyle(.indigo).help("Lucid") }
                    if dream.recurring { Image(systemName: "arrow.triangle.2.circlepath").font(.caption2).foregroundStyle(.indigo).help("Recurring") }
                }
                if !dream.excerpt.isEmpty {
                    Text(dream.excerpt).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
                if !dream.emotions.isEmpty || !dream.themes.isEmpty {
                    HStack(spacing: 6) {
                        EmotionDots(emotions: dream.emotions)
                        Text(dream.themes.prefix(3).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DreamEditor: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    let id: UUID
    @FocusState private var titleFocused: Bool

    private var dream: Binding<Dream> {
        Binding(get: { store.dream(id) ?? Dream() }, set: { store.update($0) })
    }

    var body: some View {
        HSplitView {
            writing.frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
            ScrollView { DreamInspector(dream: dream).padding(18) }
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 340)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var writing: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(DateFormatter.long.string(from: dream.wrappedValue.date))
                .font(.callout.weight(.medium)).foregroundStyle(.indigo)
            TextField("Give this dream a title", text: dream.title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .textFieldStyle(.plain)
                .focused($titleFocused)
            ZStack(alignment: .topLeading) {
                TextEditor(text: dream.text)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                if dream.wrappedValue.text.isEmpty {
                    Text("Write down everything you remember — places, people, colours, what happened, how it felt…")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            HStack {
                Text("\(dream.wrappedValue.text.split { $0.isWhitespace || $0.isNewline }.count) words")
                Spacer()
                Text("Edited \(dream.wrappedValue.modified.formatted(.relative(presentation: .named)))")
            }
            .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 12)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            if state.focusTitle { titleFocused = true; state.focusTitle = false }
        }
    }
}

struct DreamInspector: View {
    @EnvironmentObject var store: JournalStore
    @Binding var dream: Dream
    @State private var newEmotion = ""
    @State private var newTheme = ""
    @State private var showAllEmotions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Woke up on") {
                DatePicker("", selection: $dream.date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.field)
            }

            section("How did it feel?") {
                let all = store.catalog(.emotion)
                let shown = showAllEmotions ? all : Array(all.prefix(10)) + dream.emotions.filter { !all.prefix(10).contains($0) }
                FlowLayout {
                    ForEach(shown, id: \.self) { e in
                        TagChip(text: e, color: emotionColor(e), selected: dream.emotions.contains(e))
                            .onTapGesture { toggle(e, in: \.emotions) }
                            .accessibilityAddTraits(dream.emotions.contains(e) ? [.isButton, .isSelected] : .isButton)
                    }
                }
                HStack {
                    Button(showAllEmotions ? "Fewer" : "More emotions") { showAllEmotions.toggle() }
                        .buttonStyle(.link).font(.caption)
                    Spacer()
                }
                addField("Add your own emotion", text: $newEmotion) {
                    let n = store.addCustom(newEmotion, kind: .emotion)
                    if !dream.emotions.contains(n) { dream.emotions.append(n) }
                }
            }

            section("Themes & symbols") {
                if !dream.themes.isEmpty {
                    FlowLayout {
                        ForEach(dream.themes, id: \.self) { t in
                            TagChip(text: t) { dream.themes.removeAll { $0 == t } }
                        }
                    }
                }
                addField("Add a theme (e.g. water, old house)", text: $newTheme) {
                    let n = store.addCustom(newTheme, kind: .theme)
                    if !dream.themes.contains(n) { dream.themes.append(n) }
                }
                let suggestions = themeSuggestions
                if !suggestions.isEmpty {
                    Text(newTheme.isEmpty ? "Often used" : "Matching").font(.caption).foregroundStyle(.secondary)
                    FlowLayout {
                        ForEach(suggestions, id: \.self) { t in
                            TagChip(text: "+ \(t)", selected: false)
                                .onTapGesture { dream.themes.append(t); newTheme = "" }
                        }
                    }
                }
            }

            section("Details") {
                Toggle(isOn: $dream.lucid) { Label("Lucid — I knew I was dreaming", systemImage: "eye") }
                Toggle(isOn: $dream.recurring) { Label("I've had this dream before", systemImage: "arrow.triangle.2.circlepath") }
                LabeledContent("Vividness") { VividnessPicker(value: $dream.vividness) }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Woke up feeling")
                    Picker("Woke up feeling", selection: $dream.wakingMood) {
                        ForEach(-2...2, id: \.self) { Text(Catalog.moodLabel($0)).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
            }
        }
        .toggleStyle(.checkbox)
    }

    private var themeSuggestions: [String] {
        let q = newTheme.trimmingCharacters(in: .whitespaces)
        let used = store.usage(.theme).map(\.name)
        let pool = used + store.catalog(.theme).filter { !used.contains($0) }
        return pool.filter { !dream.themes.contains($0) && (q.isEmpty || $0.localizedCaseInsensitiveContains(q)) }.prefix(q.isEmpty ? 8 : 10).map { $0 }
    }

    private func toggle(_ tag: String, in path: WritableKeyPath<Dream, [String]>) {
        if let i = dream[keyPath: path].firstIndex(of: tag) { dream[keyPath: path].remove(at: i) } else { dream[keyPath: path].append(tag) }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
            content()
        }
    }

    private func addField(_ prompt: String, text: Binding<String>, onAdd: @escaping () -> Void) -> some View {
        HStack {
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    guard !text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onAdd(); text.wrappedValue = ""
                }
        }
    }
}
