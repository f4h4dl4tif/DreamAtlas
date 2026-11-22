import AppKit
import LocalAuthentication
import SwiftUI

/// Optional Touch ID / Mac password lock. The journal is hidden (not just blurred) while locked.
@MainActor
final class LockManager: ObservableObject {
    static let shared = LockManager()

    @AppStorage("lockEnabled") var enabled = false { didSet { objectWillChange.send(); if !enabled { isLocked = false } } }
    /// Minutes in the background before locking again. 0 = every time the app is left.
    @AppStorage("lockAfterMinutes") var lockAfterMinutes = 5
    @Published private(set) var isLocked = false
    @Published var message: String?

    private var resignedAt: Date?
    var disabledForSnapshot = false

    init() {
        isLocked = enabled
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LockManager.shared.resignedAt = Date() }
        }
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LockManager.shared.becameActive() }
        }
        nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LockManager.shared.lockNow() }
        }
    }

    var canUseTouchID: Bool {
        var err: NSError?
        let ctx = LAContext()
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    func lockNow() {
        guard enabled, !disabledForSnapshot else { return }
        JournalStore.shared.saveNow()
        isLocked = true
    }

    private func becameActive() {
        guard enabled, !isLocked, let t = resignedAt else { return }
        if Date().timeIntervalSince(t) >= Double(lockAfterMinutes * 60) { lockNow() }
    }

    func unlock() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use Password"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // No way to authenticate on this Mac (shouldn't happen on a Mac with a login password).
            isLocked = false
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "unlock your dream journal") { ok, error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if ok { self.isLocked = false; self.message = nil }
                    else if let e = error as? LAError, e.code != .userCancel, e.code != .appCancel { self.message = e.localizedDescription }
                }
            }
        }
    }

    /// Asks for authentication before turning the lock on, so nobody locks themselves out by accident.
    func setEnabled(_ on: Bool) {
        guard on else { enabled = false; return }
        let ctx = LAContext()
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "turn on the DreamAtlas lock") { ok, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { if ok { self.enabled = true } } }
        }
    }
}

struct LockScreen: View {
    @ObservedObject var lock = LockManager.shared

    var body: some View {
        ZStack {
            NightSky().ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.9))
                Text("DreamAtlas is locked").font(.title.weight(.semibold)).foregroundStyle(.white)
                Text("Your journal stays hidden until you unlock it.").foregroundStyle(.white.opacity(0.7))
                Button {
                    lock.unlock()
                } label: {
                    Label(lock.canUseTouchID ? "Unlock with Touch ID" : "Unlock", systemImage: lock.canUseTouchID ? "touchid" : "lock.open")
                        .padding(.horizontal, 10).padding(.vertical, 4)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                if let m = lock.message { Text(m).font(.callout).foregroundStyle(.white.opacity(0.8)) }
            }
        }
        .onAppear { lock.unlock() }
    }
}
