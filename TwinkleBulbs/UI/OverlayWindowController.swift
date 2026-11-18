import Cocoa
import CoreGraphics

// MARK: - Bulb Canvas View (Flipped Top-Down Coordinate Space)

public final class BulbCanvasView: NSView {
    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { false }

    var engine: BulbEngine?
    var currentSettings: AppSettings = .defaultSettings()

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let engine = engine,
              currentSettings.lightsEnabled else { return }
        Self.drawSlots(engine.slots, settings: currentSettings, in: ctx, clipRect: dirtyRect)
    }

    static func drawSlots(_ slots: [BulbSlot], settings: AppSettings, in ctx: CGContext, clipRect: CGRect? = nil) {
        let registry = BulbArtworkRegistry.shared
        ctx.saveGState()
        ctx.interpolationQuality = .none
        for slot in slots {
            if let clip = clipRect, !slot.frame.intersects(clip) { continue }
            guard let img = registry.image(for: slot, settings: settings) else { continue }
            // Since canvas is top-down flipped (origin top-left), CoreGraphics ctx.draw(img) draws upside-down unless locally flipped per tile
            ctx.saveGState()
            ctx.translateBy(x: slot.frame.minX, y: slot.frame.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: slot.frame.width, height: slot.frame.height))
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    /// Offscreen pixel-exact snapshot helper used by Monitor Preview & Automated Reference Tests
    public static func renderSnapshot(width: Int, height: Int, engine: BulbEngine, settings: AppSettings, backgroundColor: NSColor? = nil) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Top-down flipped root coordinate transform matching macOS flipped NSView
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        if let bg = backgroundColor {
            ctx.setFillColor(bg.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        drawSlots(engine.slots, settings: settings, in: ctx)
        return ctx.makeImage()
    }
}

// MARK: - Transparent Click-Through Overlay Controller

final class OverlayWindowController {
    private struct DisplayOverlay {
        let screen: NSScreen
        let window: NSWindow
        let canvas: BulbCanvasView
        let engine: BulbEngine
    }

    private var overlays: [DisplayOverlay] = []
    private var animationTimer: Timer?
    private var changerTimer: Timer?
    private var settings: AppSettings = .defaultSettings()

    var onTraySyncTick: ((Bool) -> Void)?
    var isPausedForScreenSaver: Bool = false {
        didSet { updateWindowVisibility() }
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenConfigChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        animationTimer?.invalidate()
        changerTimer?.invalidate()
    }

    @objc private func handleScreenConfigChange() {
        rebuildOverlays(with: settings)
    }

    func applySettings(_ newSettings: AppSettings) {
        let old = settings
        self.settings = newSettings

        let needsRebuild = overlays.isEmpty
            || old.location != newSettings.location
            || old.bulbSize != newSettings.bulbSize
            || old.drawMode != newSettings.drawMode
            || old.useAllMonitors != newSettings.useAllMonitors
            || old.drawMonitorIndex != newSettings.drawMonitorIndex
            || old.colorMode != newSettings.colorMode
            || old.flashMode != newSettings.flashMode
            || old.noCorners != newSettings.noCorners
            || old.notSoMany != newSettings.notSoMany
            || old.bareWire != newSettings.bareWire
            || old.broken != newSettings.broken
            || old.burnedOut != newSettings.burnedOut
            || old.missing != newSettings.missing
            || old.reverse != newSettings.reverse
            || old.inward != newSettings.inward
            || old.bulbSetName != newSettings.bulbSetName
            || old.mixBulbs != newSettings.mixBulbs
            || old.sysColorHighlight != newSettings.sysColorHighlight
            || old.highlightColorHex != newSettings.highlightColorHex
            || old.rate != newSettings.rate
            || old.lightsEnabled != newSettings.lightsEnabled

        if needsRebuild {
            rebuildOverlays(with: newSettings)
        } else {
            for item in overlays {
                item.canvas.currentSettings = newSettings
                item.canvas.needsDisplay = true
            }
            updateWindowVisibility()
        }

        ensureTimers()
    }

    func rebuildOverlays(with newSettings: AppSettings) {
        tearDownWindows()
        self.settings = newSettings
        guard !newSettings.runSSOnly, newSettings.lightsEnabled else {
            onTraySyncTick?(true)
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let targetScreens: [NSScreen]
        if newSettings.useAllMonitors {
            targetScreens = screens
        } else {
            let idx = min(max(0, newSettings.drawMonitorIndex), screens.count - 1)
            targetScreens = [screens[idx]]
        }

        let nowMs = currentMonotonicMs()
        for scr in targetScreens {
            let winFrame = targetRect(for: scr, settings: newSettings)
            let win = NSWindow(
                contentRect: winFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: scr
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.ignoresMouseEvents = true
            win.isReleasedWhenClosed = false
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            win.level = windowLevel(for: newSettings.drawMode)

            let engine = BulbEngine(settings: newSettings)
            let localBounds = CGRect(origin: .zero, size: winFrame.size)
            engine.configure(bounds: localBounds, settings: newSettings, nowMs: nowMs)

            let canvas = BulbCanvasView(frame: localBounds)
            canvas.engine = engine
            canvas.currentSettings = newSettings
            win.contentView = canvas

            if !isPausedForScreenSaver {
                win.orderFrontRegardless()
            }
            overlays.append(DisplayOverlay(screen: scr, window: win, canvas: canvas, engine: engine))
        }

        ensureTimers()
    }

    private func targetRect(for screen: NSScreen, settings: AppSettings) -> CGRect {
        let vf = screen.visibleFrame
        let full = screen.frame
        switch settings.drawMode {
        case .desktop:
            // Respect menu bar height so bulbs aren't hidden underneath macOS menu bar
            return CGRect(x: vf.minX, y: full.minY, width: vf.width, height: vf.maxY - full.minY)
        case .alwaysOnTop:
            return CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: vf.height)
        case .menuBarTaskbar:
            // Hang directly from the top screen band (Menu Bar level) or full edges when Around Screen / Bottom Only
            if settings.location == .top {
                let stripH = CGFloat(settings.bulbSize.pixels)
                return CGRect(x: full.minX, y: full.maxY - stripH, width: full.width, height: stripH)
            }
            return full
        }
    }

    private func windowLevel(for mode: DrawMode) -> NSWindow.Level {
        switch mode {
        case .desktop:
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .alwaysOnTop:
            return .floating
        case .menuBarTaskbar:
            return .statusBar
        }
    }

    private func updateWindowVisibility() {
        for item in overlays {
            if settings.lightsEnabled && !settings.runSSOnly && !isPausedForScreenSaver {
                item.window.orderFrontRegardless()
            } else {
                item.window.orderOut(nil)
            }
        }
    }

    private func tearDownWindows() {
        for item in overlays {
            item.window.orderOut(nil)
            item.window.close()
        }
        overlays.removeAll()
    }

    private func ensureTimers() {
        animationTimer?.invalidate()
        animationTimer = nil

        if settings.lightsEnabled && !settings.runSSOnly {
            // Exact 50 ms master animation poll matching SetTimer(..., 5, 50)
            let timer = Timer(timeInterval: 0.050, repeats: true) { [weak self] _ in
                self?.stepAnimation()
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        }

        changerTimer?.invalidate()
        changerTimer = nil
        if settings.bulbChanger && settings.bulbChangeFreqMinutes > 0 {
            let secs = TimeInterval(settings.bulbChangeFreqMinutes * 60)
            let ct = Timer(timeInterval: secs, repeats: true) { [weak self] _ in
                self?.advanceBulbSetChanger()
            }
            RunLoop.main.add(ct, forMode: .common)
            changerTimer = ct
        }
    }

    private func stepAnimation() {
        guard !isPausedForScreenSaver, settings.lightsEnabled else { return }
        let nowMs = currentMonotonicMs()
        for item in overlays {
            if item.engine.tick(nowMs: nowMs) {
                item.canvas.needsDisplay = true
            }
        }
        if let first = overlays.first {
            onTraySyncTick?(first.engine.traySyncLitState)
        }
    }

    private func advanceBulbSetChanger() {
        let sets = BulbArtworkRegistry.shared.availableSets
        guard sets.count > 1 else { return }
        var s = SettingsStore.shared.settings
        if s.bulbChangeOrder == 1 {
            let others = sets.filter { $0.id != s.bulbSetName }
            s.bulbSetName = (others.randomElement() ?? sets[0]).id
        } else {
            let idx = sets.firstIndex(where: { $0.id == s.bulbSetName }) ?? 0
            s.bulbSetName = sets[(idx + 1) % sets.count].id
        }
        SettingsStore.shared.settings = s
    }

    private func currentMonotonicMs() -> UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
    }
}
