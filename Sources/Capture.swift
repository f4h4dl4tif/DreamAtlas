import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

// MARK: - Global shortcut (⌥⌘D)

/// System-wide hotkey through Carbon's RegisterEventHotKey — needs no Accessibility permission.
final class HotKey {
    static let shared = HotKey()
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    static let display = "⌥⌘D"

    func register() {
        guard ref == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x4452_4D41), id: 1)   // "DRMA"
        RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil; handler = nil
    }
}

// MARK: - Capture preferences

@MainActor
final class CaptureSettings: ObservableObject {
    static let shared = CaptureSettings()

    @AppStorage("menuBarEnabled") var menuBarEnabled = true { didSet { if oldValue != menuBarEnabled { objectWillChange.send() } } }
    @AppStorage("hotKeyEnabled") var hotKeyEnabled = true { didSet { if oldValue != hotKeyEnabled { objectWillChange.send(); applyHotKey() } } }
    @Published var loginError: String?

    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                loginError = nil
            } catch {
                loginError = "Couldn't change the login item. Move DreamAtlas to your Applications folder and try again."
            }
        }
    }

    func applyHotKey() {
        HotKey.shared.action = { MainActor.assumeIsolated { QuickCapture.toggle() } }
        if hotKeyEnabled { HotKey.shared.register() } else { HotKey.shared.unregister() }
    }

    /// Read outside SwiftUI (AppDelegate) — an unset key means the default, on.
    nonisolated static var menuBarEnabledValue: Bool { UserDefaults.standard.object(forKey: "menuBarEnabled") as? Bool ?? true }
}

// MARK: - Quick capture panel

private final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { QuickCapture.hide() }
}

/// A small floating window for jotting a dream down half-awake, from anywhere, without opening the journal.
/// It only adds — it never shows existing dreams — so it works even while the journal is locked.
@MainActor
enum QuickCapture {
    private static var panel: NSPanel?
    static var isVisible: Bool { panel?.isVisible ?? false }

    static func toggle() { isVisible ? hide() : show() }

    static func show() {
        if panel == nil {
            let p = CapturePanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 420),
                                 styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isMovableByWindowBackground = true
            p.level = .floating
            p.isReleasedWhenClosed = false
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.standardWindowButton(.miniaturizeButton)?.isHidden = true
            p.standardWindowButton(.zoomButton)?.isHidden = true
            panel = p
        }
        guard let panel else { return }
        // Fresh view each time so the previous draft never lingers on screen.
        let host = NSHostingView(rootView: QuickCaptureView().environmentObject(JournalStore.shared).tint(.indigo))
        if GlassTheme.isOn, #available(macOS 26, *) {
            // Liquid Glass panel: the window itself goes clear and a glass view fills it.
            panel.isOpaque = false
            panel.backgroundColor = .clear
            let glass = NSGlassEffectView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
            glass.cornerRadius = 16
            host.frame = glass.bounds
            host.autoresizingMask = [.width, .height]
            glass.contentView = host
            panel.contentView = glass
        } else {
            panel.isOpaque = true
            panel.backgroundColor = .windowBackgroundColor
            panel.contentView = host
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2, y: f.midY - panel.frame.height / 2 + f.height * 0.12))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    static func hide() { panel?.orderOut(nil) }

    /// Window for snapshots.
    static var window: NSWindow? { panel }
}

struct QuickCaptureView: View {
    @EnvironmentObject var store: JournalStore
    @State private var text = ""
    @State private var emotions: [String] = []
    @State private var lastNight = true
    @FocusState private var focused: Bool

    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill").foregroundStyle(.indigo)
                Text("Quick capture").font(.headline)
                Spacer()
                Picker("", selection: $lastNight) {
                    Text("Last night").tag(true)
                    Text("Earlier").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("“Earlier” saves it to yesterday morning")
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                if text.isEmpty {
                    Text("What do you remember? Fragments are fine — a place, a face, a feeling…")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))

            Text("HOW DID IT FEEL?").font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
            FlowLayout(spacing: 5) {
                ForEach(Catalog.emotions.prefix(10).map(\.0), id: \.self) { e in
                    TagChip(text: e, color: emotionColor(e), selected: emotions.contains(e))
                        .font(.caption)
                        .onTapGesture { if let i = emotions.firstIndex(of: e) { emotions.remove(at: i) } else { emotions.append(e) } }
                }
            }

            HStack {
                Text("Add themes and details later in the journal.").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel") { QuickCapture.hide() }.keyboardShortcut(.cancelAction)
                Button("Save & Open") { save(open: true) }.disabled(!canSave)
                Button("Save") { save(open: false) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .prominentButton()
                    .disabled(!canSave)
            }
        }
        .padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 18)
        .frame(width: 540, height: 420)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }

    private func save(open: Bool) {
        guard LicenseManager.shared.canAddDream(currentCount: store.data.dreams.count) else {
            QuickCapture.hide()
            AppState.shared.showMain()
            AppState.shared.upgrade("The free version holds up to \(LicenseManager.freeDreamLimit) dreams. Everything you've written stays yours.")
            return
        }
        var d = Dream()
        if !lastNight { d.date = Calendar.current.date(byAdding: .day, value: -1, to: Date().day)! }
        d.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        d.emotions = emotions
        store.add(d)
        store.saveNow()
        Reminders.shared.reschedule()
        QuickCapture.hide()
        if open {
            AppState.shared.open(d.id)
            AppState.shared.showMain()
        }
    }
}

// MARK: - Menu bar

struct MenuBarContent: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var lock: LockManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Quick Capture…  \(HotKey.display)") { QuickCapture.show() }
        Button("New Dream in Journal") {
            AppState.shared.openMain = { openWindow(id: "main") }
            AppState.shared.showMain()
            AppState.shared.newDream()
        }
        .disabled(lock.isLocked)
        Button("Open DreamAtlas") {
            AppState.shared.openMain = { openWindow(id: "main") }
            AppState.shared.showMain()
        }
        Divider()
        if !lock.isLocked {
            let s = store.streak
            Text(s > 0 ? "\(s)-day streak · \(store.data.dreams.count) dreams" : "\(store.data.dreams.count) dreams recorded")
            Divider()
        }
        if lock.enabled && !lock.isLocked { Button("Lock Journal") { lock.lockNow() } }
        SettingsLink { Text("Settings…") }
        Button("Quit DreamAtlas") { NSApp.terminate(nil) }
    }
}
