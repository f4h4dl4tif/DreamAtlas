import AppKit

// Renders DreamAtlas's app icon: a night-sky squircle with a crescent moon and a small constellation.
let out = CommandLine.arguments[1]

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.098
    let r = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bg = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
    let u = r.width / 100

    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowBlurRadius = s * 0.025
    sh.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
    sh.set()
    NSColor.black.setFill()
    bg.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(red: 0.07, green: 0.07, blue: 0.22, alpha: 1),
        NSColor(red: 0.24, green: 0.17, blue: 0.48, alpha: 1),
        NSColor(red: 0.55, green: 0.33, blue: 0.62, alpha: 1),
    ])!.draw(in: bg, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    bg.addClip()

    // Soft glow behind the moon
    let glowCenter = NSPoint(x: r.minX + 60 * u, y: r.minY + 60 * u)
    NSGradient(colors: [NSColor(red: 1, green: 0.92, blue: 0.75, alpha: 0.35), NSColor(red: 1, green: 0.9, blue: 0.75, alpha: 0)])!
        .draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: 40 * u, options: [])

    // Stars
    var seed: UInt64 = 42
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
    for _ in 0..<40 {
        let p = NSPoint(x: r.minX + rnd() * r.width, y: r.minY + rnd() * r.height)
        let rad = (0.3 + rnd() * 0.7) * u
        NSColor.white.withAlphaComponent(0.25 + rnd() * 0.5).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - rad, y: p.y - rad, width: 2 * rad, height: 2 * rad)).fill()
    }

    // Constellation (the "atlas"): connected bright stars across the lower left
    let pts = [(18.0, 34.0), (30.0, 44.0), (44.0, 36.0), (52.0, 22.0), (66.0, 28.0)].map { NSPoint(x: r.minX + $0.0 * u, y: r.minY + $0.1 * u) }
    let line = NSBezierPath()
    line.move(to: pts[0]); for p in pts.dropFirst() { line.line(to: p) }
    line.lineWidth = 0.9 * u
    line.setLineDash([2.2 * u, 1.6 * u], count: 2, phase: 0)
    NSColor.white.withAlphaComponent(0.55).setStroke()
    line.stroke()
    for p in pts {
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 2 * u, y: p.y - 2 * u, width: 4 * u, height: 4 * u)).fill()
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 4 * u, y: p.y - 4 * u, width: 8 * u, height: 8 * u)).fill()
    }

    // Crescent moon: a disc with an offset disc cut out
    let moon = NSBezierPath(ovalIn: NSRect(x: glowCenter.x - 22 * u, y: glowCenter.y - 22 * u, width: 44 * u, height: 44 * u))
    let cut = NSBezierPath(ovalIn: NSRect(x: glowCenter.x - 10 * u, y: glowCenter.y - 14 * u, width: 42 * u, height: 42 * u))
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(rect: r)
    clip.append(cut.reversed)
    clip.addClip()
    NSGradient(colors: [NSColor(red: 1, green: 0.96, blue: 0.84, alpha: 1), NSColor(red: 0.98, green: 0.82, blue: 0.62, alpha: 1)])!
        .draw(in: moon, angle: -60)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
