import AppKit
import SwiftUI

/// Developer aid: `DreamAtlas --snapshot <dir> [--dark] [--welcome]` loads sample dreams, captures each screen to PNG and quits.
/// Run with CFFIXED_USER_HOME pointing at a scratch folder so it never touches a real journal.
@MainActor
enum Snapshot {
    static var outputDir: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }

    static func run(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        LockManager.shared.disabledForSnapshot = true
        let store = JournalStore.shared
        if store.data.dreams.isEmpty { store.data = SampleData.make() }
        let state = AppState.shared
        let dark = CommandLine.arguments.contains("--dark")
        let welcome = CommandLine.arguments.contains("--welcome")
        state.showWelcome = welcome
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)

        func wait(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
        wait(1.0)
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) else { exit(2) }
        window.setContentSize(NSSize(width: 1320, height: 840))
        let suffix = dark ? "-dark" : ""
        if CommandLine.arguments.contains("--capture") {
            QuickCapture.show()
            wait(1.0)
            if let w = QuickCapture.window { save(w, to: "\(dir)/capture\(suffix).png") }
            exit(0)
        }
        if welcome {
            wait(1.0)
            if let sheet = window.attachedSheet { save(sheet, to: "\(dir)/welcome\(suffix).png") }
            exit(0)
        }

        let topTheme = store.usage(.theme).first?.name ?? "Water"
        let steps: [(String, () -> Void, Double)] = [
            ("journal", { state.selection = .journal; state.selectedDream = store.sortedDreams.first?.id }, 1.2),
            ("timeline", { state.selection = .timeline }, 1.2),
            ("patterns", { state.selection = .patterns }, 2.0),
            ("tag", { state.selection = .tag(.theme, topTheme) }, 1.5),
        ]
        for (name, action, delay) in steps {
            action()
            wait(delay)
            save(window, to: "\(dir)/\(name)\(suffix).png")
        }
        exit(0)
    }

    private static func save(_ window: NSWindow, to path: String) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}

#if DEBUG
/// Developer aid: `DreamAtlas --glass-snapshot <dir>` captures each screen with the glass theme off and on, in light and dark,
/// using a real on-screen window capture (cacheDisplay can't render Liquid Glass). Run with CFFIXED_USER_HOME set to a scratch folder.
@MainActor
enum GlassSnapshot {
    static var outputDir: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--glass-snapshot"), i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }

    static func run(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        LockManager.shared.disabledForSnapshot = true
        let defaults = UserDefaults.standard
        let savedGlass = defaults.object(forKey: GlassTheme.key)
        let store = JournalStore.shared
        if store.data.dreams.isEmpty { store.data = SampleData.make() }
        let state = AppState.shared
        state.showWelcome = false
        func wait(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
        wait(1.0)
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) else { exit(2) }
        window.setContentSize(NSSize(width: 1320, height: 840))
        window.center()
        let topTheme = store.usage(.theme).first?.name ?? "Water"

        let settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 240), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settings.title = "Appearance"
        settings.isReleasedWhenClosed = false

        for dark in [false, true] {
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            for glass in [false, true] {
                defaults.set(glass, forKey: GlassTheme.key)
                let tag = "\(glass ? "glass" : "plain")-\(dark ? "dark" : "light")"
                window.makeKeyAndOrderFront(nil)
                let steps: [(String, () -> Void)] = [
                    ("journal", { state.selection = .journal; state.selectedDream = store.sortedDreams.first?.id }),
                    ("timeline", { state.selection = .timeline }),
                    ("patterns", { state.selection = .patterns }),
                    ("tag", { state.selection = .tag(.theme, topTheme) }),
                ]
                for (name, action) in steps {
                    action(); wait(1.5)
                    capture(window, "\(dir)/\(name)-\(tag).png")
                }
                state.showWelcome = true; wait(1.5)
                if let sheet = window.attachedSheet { capture(sheet, "\(dir)/welcome-\(tag).png") }
                state.showWelcome = false; wait(0.8)

                state.selection = .patterns
                QuickCapture.show()
                if let w = QuickCapture.window {
                    w.setFrameOrigin(NSPoint(x: window.frame.midX - w.frame.width / 2, y: window.frame.midY - w.frame.height / 2))
                    wait(1.5)
                    capture(w, "\(dir)/capture-\(tag).png")
                    captureOver(w, "\(dir)/capture-over-\(tag).png")
                }
                QuickCapture.hide()

                settings.contentView = NSHostingView(rootView: AppearanceSettings().tint(.indigo))
                settings.center(); settings.makeKeyAndOrderFront(nil); wait(1.2)
                capture(settings, "\(dir)/settings-\(tag).png")
                settings.orderOut(nil)
            }
        }
        if let savedGlass { defaults.set(savedGlass, forKey: GlassTheme.key) } else { defaults.removeObject(forKey: GlassTheme.key) }
        exit(0)
    }

    private typealias CapFn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    /// Captures the window composited over this app's windows beneath it, so glass shows what it refracts.
    private static func captureOver(_ window: NSWindow, _ path: String) {
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage"), let screen = window.screen ?? NSScreen.screens.first else { return }
        let f = unsafeBitCast(sym, to: CapFn.self)
        let fr = window.frame
        let rect = CGRect(x: fr.minX, y: NSScreen.screens[0].frame.maxY - fr.maxY, width: fr.width, height: fr.height)
        _ = screen
        guard let img = f(rect, 4 | 8, UInt32(window.windowNumber), 1)?.takeRetainedValue(),
              let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    private static func capture(_ window: NSWindow, _ path: String) {
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") else { return }
        let f = unsafeBitCast(sym, to: CapFn.self)
        guard let img = f(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue(),
              let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
#endif
