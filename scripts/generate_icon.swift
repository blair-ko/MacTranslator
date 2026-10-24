import AppKit
import CoreGraphics
import Foundation

func renderIcon(size: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext

    let s = CGFloat(size)
    // macOS 標準圓角矩形邊距 (約 10% padding)
    let inset = s * 0.09
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = rect.width * 0.225

    // 陰影
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -s * 0.02),
        blur: s * 0.045,
        color: NSColor(calibratedWhite: 0, alpha: 0.35).cgColor
    )
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(calibratedRed: 0.08, green: 0.38, blue: 0.92, alpha: 1.0).setFill()
    bgPath.fill()
    cg.restoreGState()

    // 漸層背景 (深海藍 -> 電光青藍)
    cg.saveGState()
    bgPath.addClip()
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.92, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.65, alpha: 1.0).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    // 頂部微光邊框
    NSColor(calibratedWhite: 1.0, alpha: 0.28).setStroke()
    bgPath.lineWidth = max(1.0, s * 0.015)
    bgPath.stroke()
    cg.restoreGState()

    // 繪製中央 SF Symbol 圖示 (character.bubble.fill)
    let pointSize = s * 0.46
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symSize = symbol.size
        let symRect = CGRect(
            x: (s - symSize.width) / 2,
            y: (s - symSize.height) / 2 - s * 0.01,
            width: symSize.width,
            height: symSize.height
        )

        // 建立純白帶微陰影的圖層
        cg.saveGState()
        cg.setShadow(
            offset: CGSize(width: 0, height: -s * 0.012),
            blur: s * 0.025,
            color: NSColor(calibratedWhite: 0, alpha: 0.28).cgColor
        )

        let tinted = NSImage(size: symSize)
        tinted.lockFocus()
        NSColor.white.set()
        let drawRect = NSRect(origin: .zero, size: symSize)
        symbol.draw(in: drawRect)
        drawRect.fill(using: .sourceAtop)
        tinted.unlockFocus()

        tinted.draw(in: symRect)
        cg.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try pngData.write(to: url)
    }
}

let args = CommandLine.arguments
let iconsetPath = args.count > 1 ? args[1] : "/tmp/AppIcon.iconset"
let iconsetURL = URL(fileURLWithPath: iconsetPath)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in specs {
    try renderIcon(size: px, to: iconsetURL.appendingPathComponent(filename))
}
