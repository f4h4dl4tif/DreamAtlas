import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            CaptureSettingsView().tabItem { Label("Capture", systemImage: "moon.stars") }
            PrivacySettings().tabItem { Label("Privacy", systemImage: "lock") }
            TagSettings().tabItem { Label("Tags", systemImage: "tag") }
            DataSettings().tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 540, height: 470)
    }
}

struct PrivacySettings: View {
    @EnvironmentObject var lock: LockManager

    var body: some View {
        Form {
            Section {
                Toggle("Lock DreamAtlas with \(lock.canUseTouchID ? "Touch ID or your Mac password" : "your Mac password")",
                       isOn: Binding(get: { lock.enabled }, set: { lock.setEnabled($0) }))
                Picker("Lock again after", selection: $lock.lockAfterMinutes) {
                    Text("Leaving the app").tag(0)
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("1 hour").tag(60)
                }
                .disabled(!lock.enabled)
            } footer: {
                Text("DreamAtlas also locks when your display sleeps. Press ⌃⌘L to lock it right away.")
            }
            Section("Your journal stays yours") {
                Label("Stored only on this Mac — no account, no cloud, no analytics.", systemImage: "desktopcomputer")
                Label("DreamAtlas never connects to the internet.", systemImage: "wifi.slash")
                Label("Pattern finding runs on-device.", systemImage: "cpu")
                Label("Turn on FileVault in System Settings to encrypt your whole disk.", systemImage: "lock.shield")
            }
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

struct TagSettings: View {
    @EnvironmentObject var store: JournalStore
    @State private var kind: TagKind = .theme
    @State private var renaming: String?
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $kind) { ForEach(TagKind.allCases, id: \.self) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).labelsHidden()
            let counts = Dictionary(uniqueKeysWithValues: store.usage(kind).map { ($0.name, $0.count) })
            List {
                ForEach(store.catalog(kind), id: \.self) { t in
                    HStack {
                        if kind == .emotion { Circle().fill(emotionColor(t)).frame(width: 9, height: 9) }
                        Text(t)
                        Spacer()
                        Text(counts[t].map { "\($0) dreams" } ?? "unused").foregroundStyle(.secondary).font(.callout)
                        Button("Rename") { renaming = t; newName = t }.buttonStyle(.borderless)
                        Button(role: .destructive) { confirmRemove(t, uses: counts[t] ?? 0) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .disabled(counts[t] == nil && isBuiltIn(t))
                            .help("Remove from all dreams")
                    }
                }
            }
            Text("Renaming a tag to one that already exists merges them.").font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .alert("Rename “\(renaming ?? "")”", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("New name", text: $newName)
            Button("Rename") { if let r = renaming { store.rename(r, to: newName, kind: kind) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func isBuiltIn(_ t: String) -> Bool {
        kind == .emotion ? Catalog.emotions.contains { $0.0 == t } : Catalog.themes.contains(t)
    }

    private func confirmRemove(_ t: String, uses: Int) {
        if uses > 0 {
            let a = NSAlert()
            a.messageText = "Remove “\(t)” from \(uses) dream\(uses == 1 ? "" : "s")?"
            a.informativeText = "The dreams themselves are kept."
            a.addButton(withTitle: "Remove"); a.addButton(withTitle: "Cancel")
            guard a.runModal() == .alertFirstButtonReturn else { return }
        }
        store.removeTag(t, kind: kind)
    }
}

struct DataSettings: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var license: LicenseManager

    var body: some View {
        Form {
            Section("Journal") {
                LabeledContent("Dreams", value: "\(store.data.dreams.count)")
                LabeledContent("Journal folder") {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.folder]) }
                }
                LabeledContent("Export") {
                    Button("Markdown…") { DataPanels.exportMarkdown() }
                }
                LabeledContent("Backup") {
                    HStack { Button("Back Up…") { DataPanels.export() }; Button("Restore…") { DataPanels.restore() } }
                }
            }
            Section("License") {
                LabeledContent("Status", value: license.isLicensed ? "Lifetime — \(license.licensee ?? "")" : "Free (up to \(LicenseManager.freeDreamLimit) dreams)")
                Button(license.isLicensed ? "Manage License…" : "Unlock Lifetime — \(LicenseManager.price)…") { AppState.shared.upgrade(nil) }
            }
        }
        .formStyle(.grouped)
    }
}

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NightSky()
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84)
                    Text("Welcome to DreamAtlas").font(.largeTitle.weight(.semibold)).foregroundStyle(.white)
                    Text("A private place to remember your dreams and notice your own patterns.")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, 28)
            }
            .frame(height: 210)
            VStack(alignment: .leading, spacing: 16) {
                row("square.and.pencil", "Record dreams", "Write them down when you wake, then tag how they felt and what was in them.")
                row("chart.bar.xaxis", "See what recurs", "Your timeline and patterns show themes, feelings and images that keep coming back.")
                row("lock.shield", "Private by design", "Everything stays on this Mac. No account, no cloud. Lock it with Touch ID in Settings.")
                row("leaf", "For reflection, not interpretation", "DreamAtlas doesn't analyse, diagnose or predict anything — it only shows you what you've written, so you can draw your own meaning.")
            }
            .padding(28)
            HStack {
                Spacer()
                Button("Start Journaling") {
                    UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).controlSize(.large).buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .bottom], 24)
        }
        .frame(width: 540)
    }

    private func row(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(.indigo).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CaptureSettingsView: View {
    @EnvironmentObject var capture: CaptureSettings
    @EnvironmentObject var reminders: Reminders

    var body: some View {
        Form {
            Section {
                Toggle("Quick capture shortcut  \(HotKey.display)", isOn: $capture.hotKeyEnabled)
                Toggle("Show DreamAtlas in the menu bar", isOn: $capture.menuBarEnabled)
                Toggle("Open at login", isOn: Binding(get: { capture.openAtLogin }, set: { capture.openAtLogin = $0 }))
                if let e = capture.loginError { Text(e).font(.callout).foregroundStyle(.red) }
                Button("Try Quick Capture") { QuickCapture.show() }
            } header: {
                Text("Quick capture")
            } footer: {
                Text("Press \(HotKey.display) from any app to jot a dream down before it fades. It works while the journal is locked, since it only adds and never shows past dreams. With the menu bar icon on, DreamAtlas keeps running after you close its window.")
            }
            Section {
                Toggle("Remind me each morning", isOn: Binding(get: { reminders.enabled }, set: { reminders.setEnabled($0) }))
                DatePicker("Time", selection: Binding(get: { reminders.time }, set: { reminders.time = $0 }), displayedComponents: .hourAndMinute)
                    .disabled(!reminders.enabled)
                if reminders.denied {
                    HStack {
                        Text("Notifications are turned off for DreamAtlas.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Notification Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                        }
                    }
                }
            } header: {
                Text("Morning reminder")
            } footer: {
                Text("Skipped on mornings you've already recorded a dream. Clicking the notification opens quick capture.")
            }
        }
        .formStyle(.grouped)
        .onAppear { reminders.refreshDenied() }
    }
}
