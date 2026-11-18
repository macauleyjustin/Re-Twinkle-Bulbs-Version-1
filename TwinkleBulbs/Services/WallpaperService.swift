import Foundation
import AppKit
import CoreGraphics

struct WallpaperItem: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL
    let isTileRecommended: Bool
}

/// Clean-room wallpaper generator, previewer, and macOS desktop wallpaper setter.
final class WallpaperService: ObservableObject {
    static let shared = WallpaperService()

    @Published private(set) var items: [WallpaperItem] = []

    static var wallpaperStorageDir: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/Wallpapers", isDirectory: true)
    }

    static var importedWallpaperDir: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/ImportedWallpapers", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: Self.wallpaperStorageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: Self.importedWallpaperDir, withIntermediateDirectories: true)
        generateBuiltInWallpapersIfNeeded()
        reloadList()
    }

    func reloadList() {
        var result: [WallpaperItem] = []
        let presets: [(id: String, title: String, tile: Bool)] = [
            ("dark_snowflakes", "Dark Snowflakes (Tile)", true),
            ("holiday_bulbs_dark", "Holiday Bulbs Night", false),
            ("candy_canes", "Candy Canes Stripes (Tile)", true),
            ("holly_berries", "Holly & Berries", true),
            ("starlight_pine", "Starlight Pine", false)
        ]
        for p in presets {
            let url = Self.wallpaperStorageDir.appendingPathComponent("\(p.id).png")
            if FileManager.default.fileExists(atPath: url.path) {
                result.append(WallpaperItem(id: p.id, title: p.title, url: url, isTileRecommended: p.tile))
            }
        }
        if let imported = try? FileManager.default.contentsOfDirectory(at: Self.importedWallpaperDir, includingPropertiesForKeys: nil) {
            let exts = Set(["jpg", "jpeg", "png", "heic", "tiff", "bmp"])
            for f in imported.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                if exts.contains(f.pathExtension.lowercased()) {
                    result.append(WallpaperItem(
                        id: "imported:\(f.lastPathComponent)",
                        title: f.deletingPathExtension().lastPathComponent,
                        url: f,
                        isTileRecommended: f.lastPathComponent.lowercased().contains("tile")
                    ))
                }
            }
        }
        items = result
    }

    @discardableResult
    func applyWallpaper(id: String, style: WallpaperStyle, screen: NSScreen? = nil) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        let targetScreens = screen.map { [$0] } ?? NSScreen.screens
        var options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        switch style {
        case .tile:
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
            options[.allowClipping] = true
        case .center:
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
            options[.allowClipping] = false
        case .stretch:
            options[.imageScaling] = NSImageScaling.scaleAxesIndependently.rawValue
            options[.allowClipping] = true
        case .fit:
            options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
            options[.allowClipping] = false
        }
        options[.fillColor] = NSColor(srgbRed: 0.04, green: 0.07, blue: 0.14, alpha: 1.0)

        var ok = true
        for scr in targetScreens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(item.url, for: scr, options: options)
            } catch {
                ok = false
            }
        }
        return ok
    }

    // MARK: - Clean-Room Built-In Holiday Wallpapers

    private func generateBuiltInWallpapersIfNeeded() {
        let creators: [(String, (Int, Int) -> CGImage?)] = [
            ("dark_snowflakes", { Self.renderSnowflakesTile(w: $0, h: $1) }),
            ("holiday_bulbs_dark", { Self.renderHolidayBulbsScene(w: $0, h: $1) }),
            ("candy_canes", { Self.renderCandyCaneTile(w: $0, h: $1) }),
            ("holly_berries", { Self.renderHollyTile(w: $0, h: $1) }),
            ("starlight_pine", { Self.renderStarlightPine(w: $0, h: $1) })
        ]
        for (id, builder) in creators {
            let url = Self.wallpaperStorageDir.appendingPathComponent("\(id).png")
            if FileManager.default.fileExists(atPath: url.path) { continue }
            let size = (id.contains("snowflakes") || id.contains("candy") || id.contains("holly")) ? (256, 256) : (1280, 800)
            if let img = builder(size.0, size.1) {
                let rep = NSBitmapImageRep(cgImage: img)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
            }
        }
    }

    private static func makeCtx(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private static func renderSnowflakesTile(w: Int, h: Int) -> CGImage? {
        guard let ctx = makeCtx(w, h) else { return nil }
        ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.09, blue: 0.20, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setStrokeColor(NSColor(white: 0.92, alpha: 0.72).cgColor)
        let coords = [(42, 40, 14.0), (140, 72, 18.0), (210, 32, 10.0), (88, 165, 20.0), (190, 195, 13.0), (28, 220, 11.0)]
        for (cx, cy, r) in coords {
            drawCrystal(ctx, center: CGPoint(x: cx, y: cy), radius: r)
        }
        return ctx.makeImage()
    }

    private static func drawCrystal(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        ctx.setLineWidth(1.5)
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3.0
            let ex = center.x + cos(a) * radius
            let ey = center.y + sin(a) * radius
            ctx.move(to: center)
            ctx.addLine(to: CGPoint(x: ex, y: ey))
            ctx.strokePath()
        }
    }

    private static func renderHolidayBulbsScene(w: Int, h: Int) -> CGImage? {
        guard let ctx = makeCtx(w, h) else { return nil }
        let cols = [NSColor(srgbRed: 0.03, green: 0.05, blue: 0.12, alpha: 1).cgColor,
                    NSColor(srgbRed: 0.06, green: 0.14, blue: 0.10, alpha: 1).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h), options: [])
        }
        let palette: [NSColor] = [.systemRed, .systemGreen, .systemYellow, .systemBlue, .systemPurple, .cyan]
        for idx in 0..<42 {
            let x = CGFloat((idx * 173 + 60) % w)
            let y = CGFloat((idx * 127 + 90) % h)
            let r = CGFloat(14 + (idx % 3) * 8)
            let col = palette[idx % palette.count]
            let gc = [col.withAlphaComponent(0.35).cgColor, col.withAlphaComponent(0).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gc, locations: [0, 1]) {
                ctx.drawRadialGradient(grad, startCenter: CGPoint(x: x, y: y), startRadius: 1, endCenter: CGPoint(x: x, y: y), endRadius: r * 2.5, options: [])
            }
            ctx.setFillColor(col.withAlphaComponent(0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - r * 0.4, y: y - r * 0.6, width: r * 0.8, height: r * 1.2))
        }
        return ctx.makeImage()
    }

    private static func renderCandyCaneTile(w: Int, h: Int) -> CGImage? {
        guard let ctx = makeCtx(w, h) else { return nil }
        ctx.setFillColor(NSColor(srgbRed: 0.94, green: 0.93, blue: 0.90, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(NSColor(srgbRed: 0.78, green: 0.10, blue: 0.14, alpha: 1).cgColor)
        for off in stride(from: -h, to: w + h, by: 48) {
            ctx.saveGState()
            ctx.translateBy(x: CGFloat(off), y: 0)
            ctx.rotate(by: .pi / 4)
            ctx.fill(CGRect(x: 0, y: -300, width: 14, height: 900))
            ctx.restoreGState()
        }
        return ctx.makeImage()
    }

    private static func renderHollyTile(w: Int, h: Int) -> CGImage? {
        guard let ctx = makeCtx(w, h) else { return nil }
        ctx.setFillColor(NSColor(srgbRed: 0.05, green: 0.22, blue: 0.11, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        for p in [CGPoint(x: 64, y: 64), CGPoint(x: 192, y: 192), CGPoint(x: 64, y: 192), CGPoint(x: 192, y: 64)] {
            ctx.setFillColor(NSColor(srgbRed: 0.10, green: 0.46, blue: 0.20, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 28, y: p.y - 12, width: 28, height: 18))
            ctx.fillEllipse(in: CGRect(x: p.x, y: p.y - 12, width: 28, height: 18))
            ctx.setFillColor(NSColor(srgbRed: 0.88, green: 0.12, blue: 0.16, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 7, y: p.y - 2, width: 8, height: 8))
            ctx.fillEllipse(in: CGRect(x: p.x + 1, y: p.y - 2, width: 8, height: 8))
            ctx.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 9, width: 8, height: 8))
        }
        return ctx.makeImage()
    }

    private static func renderStarlightPine(w: Int, h: Int) -> CGImage? {
        guard let ctx = makeCtx(w, h) else { return nil }
        let cols = [NSColor(srgbRed: 0.04, green: 0.07, blue: 0.15, alpha: 1).cgColor,
                    NSColor(srgbRed: 0.09, green: 0.19, blue: 0.28, alpha: 1).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }
        ctx.setFillColor(NSColor(white: 0.96, alpha: 0.8).cgColor)
        for i in 0..<90 {
            let x = (i * 313 + 47) % w
            let y = (i * 197 + 31) % h
            let s = 2 + (i % 3)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
        }
        return ctx.makeImage()
    }
}
