#!/usr/bin/env swift
// generate_icon.swift
// Generates ChefNova app icon PNGs at all required sizes using CoreGraphics.
// Run: swift generate_icon.swift

import CoreGraphics
import ImageIO
import Foundation
#if canImport(AppKit)
import AppKit
#endif

let outputDir = "ChefNova/Assets.xcassets/AppIcon.appiconset"

// All sizes needed for a universal iOS app icon set (single 1024pt image is enough for modern Xcode)
let sizes: [(name: String, size: Int)] = [
    ("Icon-1024", 1024),
    ("Icon-180",  180),   // iPhone @3x
    ("Icon-167",  167),   // iPad Pro @2x
    ("Icon-152",  152),   // iPad @2x
    ("Icon-120",  120),   // iPhone @2x/@3x
    ("Icon-87",    87),   // iPhone @3x small
    ("Icon-80",    80),   // iPhone/iPad @2x
    ("Icon-76",    76),   // iPad @1x
    ("Icon-60",    60),   // iPhone @1x
    ("Icon-58",    58),   // iPhone @2x small
    ("Icon-40",    40),   // iPhone/iPad @2x
    ("Icon-29",    29),   // iPhone @1x small
    ("Icon-20",    20),   // iPad @1x notification
]

func drawIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size, height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // ── Background gradient (deep orange → amber) ──────────────────────────
    let gradColors = [
        CGColor(red: 0.85, green: 0.28, blue: 0.05, alpha: 1),  // burnt sienna
        CGColor(red: 1.00, green: 0.55, blue: 0.10, alpha: 1),  // warm amber
    ] as CFArray

    let locs: [CGFloat] = [0, 1]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: locs)!

    // Rounded rect clip (iOS icon corner radius ≈ 22.5% of size)
    let radius = s * 0.225
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGMutablePath()
    path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
    ctx.addPath(path)
    ctx.clip()

    // Draw gradient top-left → bottom-right
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: s, y: 0),
        options: []
    )

    // ── Soft inner glow circle ─────────────────────────────────────────────
    let glowRadius = s * 0.38
    let center = CGPoint(x: s * 0.5, y: s * 0.5)
    let glowColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let radialGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: locs)!
    ctx.drawRadialGradient(
        radialGradient,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: glowRadius,
        options: []
    )

    // ── Fork & knife symbol (drawn as simple geometric shapes) ────────────
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.setLineWidth(s * 0.045)
    ctx.setLineCap(.round)

    let unit = s * 0.06   // base unit for proportional drawing

    // -- Fork (left of center) --
    let forkX = s * 0.36
    let topY  = s * 0.22
    let botY  = s * 0.80
    let tineSpacing = unit * 0.55
    let tineHeight  = unit * 2.2

    // Three tines
    for i in -1...1 {
        let tx = forkX + CGFloat(i) * tineSpacing
        ctx.move(to: CGPoint(x: tx, y: topY))
        ctx.addLine(to: CGPoint(x: tx, y: topY + tineHeight))
    }
    ctx.strokePath()

    // Tine connector bar
    ctx.move(to: CGPoint(x: forkX - tineSpacing, y: topY + tineHeight))
    ctx.addLine(to: CGPoint(x: forkX + tineSpacing, y: topY + tineHeight))
    ctx.strokePath()

    // Fork handle
    ctx.move(to: CGPoint(x: forkX, y: topY + tineHeight))
    ctx.addLine(to: CGPoint(x: forkX, y: botY))
    ctx.strokePath()

    // -- Knife (right of center) --
    let knifeX = s * 0.64

    // Blade (slightly angled top)
    let bladePath = CGMutablePath()
    bladePath.move(to: CGPoint(x: knifeX - unit * 0.3, y: topY))
    bladePath.addLine(to: CGPoint(x: knifeX + unit * 0.3, y: topY + unit * 0.5))
    bladePath.addLine(to: CGPoint(x: knifeX + unit * 0.3, y: topY + unit * 2.5))
    bladePath.addLine(to: CGPoint(x: knifeX - unit * 0.3, y: topY + unit * 2.5))
    bladePath.closeSubpath()
    ctx.addPath(bladePath)
    ctx.fillPath()

    // Knife handle
    ctx.move(to: CGPoint(x: knifeX, y: topY + unit * 2.5))
    ctx.addLine(to: CGPoint(x: knifeX, y: botY))
    ctx.strokePath()

    return ctx.makeImage()
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("❌ Could not create destination for \(path)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("✅ \(path)")
    } else {
        print("❌ Failed to write \(path)")
    }
}

// Generate all sizes
for entry in sizes {
    if let img = drawIcon(size: entry.size) {
        savePNG(img, to: "\(outputDir)/\(entry.name).png")
    }
}

print("\nDone — \(sizes.count) icons generated.")
