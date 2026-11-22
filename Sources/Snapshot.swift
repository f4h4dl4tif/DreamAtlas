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
