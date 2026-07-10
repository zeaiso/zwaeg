#!/usr/bin/env swift
// Draws the Zwäg app icon: the coral blob buddy on cream, plus the
// Midnight and Mono look variants. Run from the repo root:
//   swift scripts/generate_icon.swift

import AppKit

struct IconLook {
    let name: String
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let decor: NSColor
    let blobTop: NSColor
    let blobBottom: NSColor
    let features: NSColor
    let blush: NSColor
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let looks = [
    IconLook(name: "", backgroundTop: color(0xF7EFE9), backgroundBottom: color(0xF3E5D8),
             decor: color(0xFBDCC9, 0.55), blobTop: color(0xFF8A5C), blobBottom: color(0xFF4F2E),
             features: color(0x2A1B14), blush: color(0xFFB59B, 0.85)),
    IconLook(name: "Midnight", backgroundTop: color(0x24201D), backgroundBottom: color(0x181512),
             decor: color(0x3A302A, 0.7), blobTop: color(0xFF8A5C), blobBottom: color(0xFF4F2E),
             features: color(0x1C1310), blush: color(0xFFB59B, 0.85)),
    IconLook(name: "Mono", backgroundTop: color(0xF2F0EE), backgroundBottom: color(0xE7E4E1),
             decor: color(0xDCD8D4, 0.7), blobTop: color(0x8A8580), blobBottom: color(0x5E5955),
             features: color(0x211E1C), blush: color(0xB8B2AD, 0.85)),
]

func draw(look: IconLook, size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // Background with a soft vertical gradient and one decor circle.
    NSGradient(starting: look.backgroundTop, ending: look.backgroundBottom)?
        .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
    look.decor.setFill()
    NSBezierPath(ovalIn: NSRect(x: 560 * s, y: 560 * s, width: 640 * s, height: 640 * s)).fill()

    // Blob body, slightly squashed, with a vertical coral gradient.
    let blobRect = NSRect(x: 187 * s, y: 200 * s, width: 650 * s, height: 590 * s)
    let blob = NSBezierPath(ovalIn: blobRect)
    NSGradient(starting: look.blobTop, ending: look.blobBottom)?.draw(in: blob, angle: -90)

    // Soft highlight on the upper left of the blob.
    color(0xFFFFFF, 0.28).setFill()
    NSBezierPath(ovalIn: NSRect(x: 285 * s, y: 585 * s, width: 200 * s, height: 120 * s)).fill()

    // Eyes: tall rounded ovals.
    look.features.setFill()
    for x: CGFloat in [412, 556] {
        NSBezierPath(ovalIn: NSRect(x: x * s, y: 470 * s, width: 56 * s, height: 108 * s)).fill()
    }

    // Smile: arc with round caps.
    let smile = NSBezierPath()
    smile.appendArc(withCenter: NSPoint(x: 512 * s, y: 452 * s), radius: 74 * s,
                    startAngle: 205, endAngle: 335, clockwise: false)
    smile.lineWidth = 26 * s
    smile.lineCapStyle = .round
    look.features.setStroke()
    smile.stroke()

    // Blush dots outside the eyes.
    look.blush.setFill()
    for x: CGFloat in [312, 646] {
        NSBezierPath(ovalIn: NSRect(x: x * s, y: 430 * s, width: 66 * s, height: 52 * s)).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

write(draw(look: looks[0], size: 1024), to: "Zwaeg/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
for look in looks.dropFirst() {
    write(draw(look: look, size: 120), to: "Zwaeg/Resources/AltIcons/AppIcon\(look.name)@2x.png")
    write(draw(look: look, size: 180), to: "Zwaeg/Resources/AltIcons/AppIcon\(look.name)@3x.png")
}
