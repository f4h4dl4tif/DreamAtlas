import AppKit
import SwiftUI

/// Optional Liquid Glass theme (macOS 26+). Off by default; with it off every surface keeps its original look.
enum GlassTheme {
    static let key = "glassTheme"

    static var isSupported: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Read outside SwiftUI (AppKit panels).
    static var isOn: Bool { isSupported && UserDefaults.standard.bool(forKey: key) }
}

/// A card's background: the original solid fill and hairline, or a Liquid Glass panel when the glass theme is on.
struct CardSurface: ViewModifier {
    var radius: CGFloat
    var strokeOpacity: Double = 0.07
    @AppStorage(GlassTheme.key) private var glass = false

    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content
                .background(RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary.opacity(strokeOpacity)))
        }
    }
}

/// Soft dusk/night backdrop behind scrolling dashboards so the glass cards have something to refract.
struct GlassBackdrop: ViewModifier {
    @AppStorage(GlassTheme.key) private var glass = false

    func body(content: Content) -> some View {
        if glass, GlassTheme.isSupported {
            content.background { DreamBackdrop().ignoresSafeArea() }
        } else {
            content
        }
    }
}

struct DreamBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            LinearGradient(colors: dark
                           ? [Color(red: 0.07, green: 0.06, blue: 0.17), Color(red: 0.13, green: 0.10, blue: 0.28), Color(red: 0.20, green: 0.13, blue: 0.30)]
                           : [Color(red: 0.90, green: 0.89, blue: 0.98), Color(red: 0.94, green: 0.90, blue: 0.97), Color(red: 0.99, green: 0.92, blue: 0.90)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                Circle().fill(Color.indigo.opacity(dark ? 0.35 : 0.22)).frame(width: w * 0.55).blur(radius: 90)
                    .position(x: w * 0.18, y: h * 0.22)
                Circle().fill(Color.pink.opacity(dark ? 0.18 : 0.18)).frame(width: w * 0.45).blur(radius: 100)
                    .position(x: w * 0.85, y: h * 0.70)
                Circle().fill(Color.teal.opacity(dark ? 0.14 : 0.12)).frame(width: w * 0.35).blur(radius: 90)
                    .position(x: w * 0.65, y: h * 0.12)
            }
            if dark {
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: 11)
                    for _ in 0..<70 {
                        let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                        let r = 0.4 + rng.next() * 1.1
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: r, height: r)), with: .color(.white.opacity(0.15 + rng.next() * 0.35)))
                    }
                }
            }
        }
    }
}

extension View {
    func cardSurface(radius: CGFloat, strokeOpacity: Double = 0.07) -> some View {
        modifier(CardSurface(radius: radius, strokeOpacity: strokeOpacity))
    }

    func glassBackdrop() -> some View { modifier(GlassBackdrop()) }

    /// Prominent action button: Liquid Glass when the theme is on, otherwise the original bordered-prominent style.
    func prominentButton() -> some View { modifier(ProminentButton()) }

    /// Secondary button sitting on the night sky: clear glass when the theme is on.
    func glassButtonIfOn() -> some View { modifier(GlassButtonIfOn()) }
}

struct ProminentButton: ViewModifier {
    @AppStorage(GlassTheme.key) private var glass = false
    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.borderedProminent) }
    }
}

struct GlassButtonIfOn: ViewModifier {
    @AppStorage(GlassTheme.key) private var glass = false
    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) { content.buttonStyle(.glass) } else { content.buttonStyle(.borderedProminent) }
    }
}

struct AppearanceSettings: View {
    @AppStorage(GlassTheme.key) private var glass = false

    var body: some View {
        Form {
            Section {
                Toggle("Liquid Glass theme", isOn: $glass).disabled(!GlassTheme.isSupported)
            } header: {
                Text("Theme")
            } footer: {
                Text(GlassTheme.isSupported
                     ? "Uses Liquid Glass for cards, panels and quick capture over a soft night-sky backdrop."
                     : "Requires macOS 26 or later.")
            }
        }
        .formStyle(.grouped)
    }
}
