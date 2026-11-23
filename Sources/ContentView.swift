import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    @EnvironmentObject var license: LicenseManager
    @EnvironmentObject var lock: LockManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if lock.isLocked {
                LockScreen()
            } else {
                NavigationSplitView {
                    Sidebar().navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
                } detail: {
                    detail
                }
            }
        }
        .onAppear { state.openMain = { openWindow(id: "main") } }
        .sheet(isPresented: $state.showUpgrade) { UpgradeView(reason: state.upgradeReason) }
        .sheet(isPresented: $state.showWelcome) { WelcomeView() }
        .alert("Something went wrong", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    @ViewBuilder private var detail: some View {
        switch state.selection ?? .journal {
        case .journal: JournalView()
        case .timeline: TimelineView()
        case .patterns: PatternsView()
        case .tag(let kind, let name): TagDetailView(kind: kind, name: name).id("\(kind)-\(name)")
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var state: AppState
    @EnvironmentObject var license: LicenseManager

    @AppStorage(GlassTheme.key) private var glass = false

    var body: some View {
        sidebarContent
        .toolbar {
            ToolbarItem {
                Button { state.newDream() } label: { Label("New Dream", systemImage: "square.and.pencil") }
                    .help("Record a new dream (⌘N)")
            }
        }
    }

    private var list: some View {
        List(selection: $state.selection) {
            Section {
                Label("Journal", systemImage: "book.closed").tag(SidebarItem.journal)
                Label("Timeline", systemImage: "calendar.day.timeline.left").tag(SidebarItem.timeline)
                Label("Patterns", systemImage: "chart.bar.xaxis").tag(SidebarItem.patterns)
            }
            tagSection(.emotion)
            tagSection(.theme)
        }
        .listStyle(.sidebar)
    }

    /// With the glass theme the footer card sits below the list rather than over it,
    /// so tag rows end above the card and never show around or beneath it.
    @ViewBuilder private var sidebarContent: some View {
        if glass, #available(macOS 26, *) {
            VStack(spacing: 0) {
                list
                footer
            }
        } else {
            list.safeAreaInset(edge: .bottom) { footer }
        }
    }

    @ViewBuilder private func tagSection(_ kind: TagKind) -> some View {
        let used = store.usage(kind)
        if !used.isEmpty {
            Section(kind.title) {
                ForEach(used.prefix(12), id: \.name) { t in
                    HStack(spacing: 8) {
                        if kind == .emotion {
                            Circle().fill(emotionColor(t.name)).frame(width: 9, height: 9)
                        } else {
                            Image(systemName: "number").foregroundStyle(.secondary).font(.caption)
                        }
                        Text(t.name).lineLimit(1)
                        Spacer()
                        Text("\(t.count)").foregroundStyle(.secondary).monospacedDigit().font(.callout)
                    }
                    .tag(SidebarItem.tag(kind, t.name))
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if !license.isLicensed {
            VStack(alignment: .leading, spacing: 6) {
                Text("Free · \(min(store.data.dreams.count, LicenseManager.freeDreamLimit)) of \(LicenseManager.freeDreamLimit) dreams")
                    .font(.caption).foregroundStyle(.secondary)
                ProgressView(value: Double(min(store.data.dreams.count, LicenseManager.freeDreamLimit)), total: Double(LicenseManager.freeDreamLimit))
                Button("Unlock Lifetime — \(LicenseManager.price)") { state.upgrade(nil) }
                    .buttonStyle(.link).font(.callout)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SidebarFooterSurface())
        }
    }
}

/// Gives the sidebar footer its own surface so the tag list scrolling underneath
/// no longer shows through the text: a floating glass card with the glass theme,
/// otherwise a standard bar with a divider.
private struct SidebarFooterSurface: ViewModifier {
    @AppStorage(GlassTheme.key) private var glass = false
    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        } else {
            content
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

