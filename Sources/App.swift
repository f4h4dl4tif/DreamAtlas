import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case journal
    case timeline
    case patterns
    case tag(TagKind, String)
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var selection: SidebarItem? = .journal
    @Published var selectedDream: UUID?
    @Published var search = ""
    @Published var upgradeReason: String?
    @Published var showUpgrade = false
    @Published var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenWelcome")
    @Published var focusTitle = false
    /// Set from SwiftUI views (which hold the openWindow action) so AppKit code can reopen the journal window.
    var openMain: (() -> Void)?

    func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            openMain?()
        }
    }

    func newDream() {
        let store = JournalStore.shared
        guard LicenseManager.shared.canAddDream(currentCount: store.data.dreams.count) else {
            upgrade("The free version holds up to \(LicenseManager.freeDreamLimit) dreams. Everything you've written stays yours.")
            return
        }
        let d = Dream()
        store.add(d)
        Reminders.shared.reschedule()
        search = ""
        selection = .journal
        selectedDream = d.id
        focusTitle = true
    }

    func open(_ id: UUID) {
        search = ""
        selection = .journal
        selectedDream = id
    }

    func upgrade(_ reason: String?) {
        upgradeReason = reason
        showUpgrade = true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// With the menu bar icon on, DreamAtlas keeps running so quick capture and reminders stay available.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !CaptureSettings.menuBarEnabledValue }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { JournalStore.shared.saveNow() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if Snapshot.outputDir == nil && !CommandLine.arguments.contains("--glass-snapshot") {
                CaptureSettings.shared.applyHotKey()
                Reminders.shared.start()
            }
        }
        if let dir = Snapshot.outputDir { MainActor.assumeIsolated { Snapshot.run(to: dir) } }
        #if DEBUG
        if let dir = GlassSnapshot.outputDir { MainActor.assumeIsolated { GlassSnapshot.run(to: dir) } }
        #endif
    }
}

@main
struct DreamAtlasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = JournalStore.shared
    @StateObject private var state = AppState.shared
    @StateObject private var license = LicenseManager.shared
    @StateObject private var lock = LockManager.shared
    @StateObject private var capture = CaptureSettings.shared

    var body: some Scene {
        Window("DreamAtlas", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(state)
                .environmentObject(license)
                .environmentObject(lock)
                .frame(minWidth: 1060, minHeight: 640)
                .tint(.indigo)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Dream") { state.newDream() }.keyboardShortcut("n").disabled(lock.isLocked)
                Button("Quick Capture…") { QuickCapture.show() }.keyboardShortcut("d", modifiers: [.command, .option])
            }
            CommandGroup(after: .importExport) {
                Button("Export as Markdown…") { DataPanels.exportMarkdown() }.disabled(lock.isLocked)
                Divider()
                Button("Back Up Journal…") { DataPanels.export() }.disabled(lock.isLocked)
                Button("Restore from Backup…") { DataPanels.restore() }.disabled(lock.isLocked)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About DreamAtlas") { NSApp.orderFrontStandardAboutPanel(nil) }
                Button(license.isLicensed ? "License…" : "Unlock Lifetime License…") { state.upgrade(nil) }
            }
            CommandMenu("Go") {
                Button("Journal") { state.selection = .journal }.keyboardShortcut("1")
                Button("Timeline") { state.selection = .timeline }.keyboardShortcut("2")
                Button("Patterns") { state.selection = .patterns }.keyboardShortcut("3")
                Divider()
                Button("Lock Journal") { lock.lockNow() }.keyboardShortcut("l", modifiers: [.command, .control]).disabled(!lock.enabled)
            }
        }
        Settings {
            SettingsView()
                .environmentObject(store).environmentObject(license).environmentObject(lock)
                .environmentObject(capture).environmentObject(Reminders.shared)
                .tint(.indigo)
        }
        MenuBarExtra(isInserted: Binding(get: { capture.menuBarEnabled },
                                         set: { if $0 != capture.menuBarEnabled { capture.menuBarEnabled = $0 } })) {
            MenuBarContent().environmentObject(store).environmentObject(lock)
        } label: {
            Image(systemName: "moon.stars")
        }
    }
}

@MainActor
enum DataPanels {
    static var stamp: String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }

    static func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "DreamAtlas Backup \(stamp).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try JournalStore.shared.exportBackup(to: url) } catch { alert("Backup failed", error.localizedDescription) }
    }

    static func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "Dream Journal \(stamp).md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try JournalStore.shared.exportMarkdown(to: url) } catch { alert("Export failed", error.localizedDescription) }
    }

    static func restore() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let a = NSAlert()
        a.messageText = "Replace your journal with this backup?"
        a.informativeText = "A copy of your current journal is saved in the DreamAtlas folder first, so nothing is lost."
        a.addButton(withTitle: "Restore")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        do { try JournalStore.shared.importBackup(from: url) } catch { alert("Restore failed", "That file isn't a DreamAtlas backup.") }
    }

    static func alert(_ title: String, _ text: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal()
    }
}
