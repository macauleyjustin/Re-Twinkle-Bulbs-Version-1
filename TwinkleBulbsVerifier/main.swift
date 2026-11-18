import Foundation
import Cocoa
import CoreGraphics
import TwinkleBulbsCore

// MARK: - Clean Verification Harness

private var passedCount = 0
private var failedCount = 0

func check(_ condition: Bool, _ label: String, file: String = #file, line: Int = #line) {
    if condition {
        passedCount += 1
        print("  [PASS] \(label)")
    } else {
        failedCount += 1
        print("  [FAIL] \(label) (\(file):\(line))")
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String, file: String = #file, line: Int = #line) {
    if actual == expected {
        passedCount += 1
        print("  [PASS] \(label)")
    } else {
        failedCount += 1
        print("  [FAIL] \(label): actual=\(actual) expected=\(expected) (\(file):\(line))")
    }
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try data.write(to: url)
        return true
    } catch {
        return false
    }
}

func loadPNGImage(at url: URL) -> CGImage? {
    guard let dp = CGDataProvider(url: url as CFURL) else { return nil }
    return CGImage(pngDataProviderSource: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

func sampleImageRGBA(_ img: CGImage) -> [UInt8] {
    let w = img.width, h = img.height
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    if let ctx = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return rgba
}

func opaquePixelStats(_ img: CGImage) -> (count: Int, minX: Int, maxX: Int, minY: Int, maxY: Int, avgLuma: Double) {
    let rgba = sampleImageRGBA(img)
    let w = img.width, h = img.height
    var count = 0
    var minX = w, maxX = -1, minY = h, maxY = -1
    var lumaSum = 0.0
    for y in 0..<h {
        for x in 0..<w {
            let p = (y * w + x) * 4
            let a = Int(rgba[p + 3])
            if a > 16 {
                count += 1
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                lumaSum += (0.299 * Double(rgba[p]) + 0.587 * Double(rgba[p + 1]) + 0.114 * Double(rgba[p + 2])) * 255.0 / Double(a)
            }
        }
    }
    return (count, minX, maxX, minY, maxY, count > 0 ? lumaSum / Double(count) : 0.0)
}

print("=== Twinkle Bulbs v6.0 macOS Verification Suite ===")

// 1. Default Configuration
print("\n[1] Exact v6.0 Defaults (LoadSettings)")
let def = AppSettings.defaultSettings()
checkEqual(def.bulbSetName, "Outdoor", "Default bulb set")
checkEqual(def.flashMode, .chase, "Default FlashMode == Chase (3)")
checkEqual(def.rate, .medium, "Default Rate == Medium (2)")
checkEqual(def.colorMode, .redGreen, "Default Color == Red/Green (8)")
checkEqual(def.drawMode, .desktop, "Default DrawMode == Desktop (0)")
checkEqual(def.location, .top, "Default Location == Top (0)")
checkEqual(def.bulbSize.pixels, 32, "Default BulbSize == 32px")
check(def.bareWire && def.noCorners && def.notSoMany, "BareWire, NoCorners, NotSoMany default true")
check(!def.broken && !def.burnedOut && !def.missing, "Defect toggles default false")
checkEqual(def.ssDelayMinutes, 10, "Default screen saver idle delay == 10m")
checkEqual(def.ssMsg, "YOUR MESSAGE HERE", "Default screen saver message")

// 2. All 21 Color Modes
print("\n[2] All 21 Color Modes (tbulbs.mem 0x0048289a..0x0048366c)")
var rng: any RandomSource = SeededRandomSource(seed: 12345)
let rndSeq = BulbEngine.colorSequence(mode: .random, count: 50, rng: &rng)
check(zip(rndSeq, rndSeq.dropFirst()).allSatisfy { $0 != $1 }, "ColorMode 0 (Random): zero consecutive repeats across 50 bulbs")
checkEqual(BulbEngine.colorSequence(mode: .purple, count: 4, rng: &rng), [0,0,0,0], "ColorMode 1 Purple")
checkEqual(BulbEngine.colorSequence(mode: .blue, count: 4, rng: &rng), [1,1,1,1], "ColorMode 2 Blue")
checkEqual(BulbEngine.colorSequence(mode: .red, count: 4, rng: &rng), [2,2,2,2], "ColorMode 3 Red")
checkEqual(BulbEngine.colorSequence(mode: .green, count: 4, rng: &rng), [3,3,3,3], "ColorMode 4 Green")
checkEqual(BulbEngine.colorSequence(mode: .yellow, count: 4, rng: &rng), [4,4,4,4], "ColorMode 5 Yellow")
checkEqual(BulbEngine.colorSequence(mode: .lightBlue, count: 4, rng: &rng), [5,5,5,5], "ColorMode 6 Light Blue")
checkEqual(BulbEngine.colorSequence(mode: .white, count: 4, rng: &rng), [6,6,6,6], "ColorMode 7 White")
checkEqual(BulbEngine.colorSequence(mode: .redGreen, count: 6, rng: &rng), [3,2,3,2,3,2], "ColorMode 8 Red/Green [3,2]")
checkEqual(BulbEngine.colorSequence(mode: .multiColor, count: 7, rng: &rng), [1,2,3,4,5,0,1], "ColorMode 9 Multi-Color")
checkEqual(BulbEngine.colorSequence(mode: .blues, count: 4, rng: &rng), [5,1,5,1], "ColorMode 10 Blues")
checkEqual(BulbEngine.colorSequence(mode: .allColorsWhite, count: 8, rng: &rng), [0,1,2,3,4,5,6,0], "ColorMode 11 All Colors (+White)")
checkEqual(BulbEngine.colorSequence(mode: .redBlue, count: 4, rng: &rng), [2,1,2,1], "ColorMode 12 Red/Blue")
checkEqual(BulbEngine.colorSequence(mode: .purpleGreen, count: 4, rng: &rng), [0,3,0,3], "ColorMode 13 Purple/Green")
checkEqual(BulbEngine.colorSequence(mode: .redYellowGreen, count: 6, rng: &rng), [2,4,3,2,4,3], "ColorMode 14 Red/Yellow/Green")
checkEqual(BulbEngine.colorSequence(mode: .redGreenBlue, count: 6, rng: &rng), [2,3,1,2,3,1], "ColorMode 15 Red/Green/Blue")
checkEqual(BulbEngine.colorSequence(mode: .coolColors, count: 6, rng: &rng), [0,1,3,0,1,3], "ColorMode 16 Cool Colors")
checkEqual(BulbEngine.colorSequence(mode: .yellowWhite, count: 4, rng: &rng), [6,4,6,4], "ColorMode 17 Yellow/White")
checkEqual(BulbEngine.colorSequence(mode: .redYellow, count: 4, rng: &rng), [4,2,4,2], "ColorMode 18 Red/Yellow")
checkEqual(BulbEngine.colorSequence(mode: .redGreenYellowBlue, count: 5, rng: &rng), [2,3,4,1,2], "ColorMode 19 R/G/Y/B")
checkEqual(BulbEngine.colorSequence(mode: .redWhiteBlue, count: 6, rng: &rng), [2,6,1,2,6,1], "ColorMode 20 Red/White/Blue")

// 3. Timings, Strides & All 9 Flash Modes
print("\n[3] Exact Step Intervals, Chase Strides, and 9 Flashing Modes")
checkEqual(FlashRate.slow.fixedIntervalMs, 1200, "Slow interval 1200ms")
checkEqual(FlashRate.slowMedium.fixedIntervalMs, 800, "Slow/Med interval 800ms")
checkEqual(FlashRate.medium.fixedIntervalMs, 500, "Medium interval 500ms")
checkEqual(FlashRate.mediumFast.fixedIntervalMs, 350, "Med/Fast interval 350ms")
checkEqual(FlashRate.fast.fixedIntervalMs, 200, "Fast interval 200ms")
checkEqual(FlashRate.veryFast.fixedIntervalMs, 80, "Very Fast interval 80ms")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 16), 4, "Stride <=20 -> 4")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 25), 5, "Stride <=25 -> 5")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 32), 8, "Stride <=32 -> 8")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 36), 6, "Stride <=36 -> 6")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 40), 8, "Stride <=40 -> 8")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 50), 10, "Stride <=50 -> 10")
checkEqual(BulbEngine.legacyChaseStride(bulbCount: 64), 2, "Legacy stride >50 -> 2")

var cfg = AppSettings.defaultSettings()
cfg.location = .top
cfg.notSoMany = false
cfg.flashMode = .chase
let eng = BulbEngine(settings: cfg, rng: SeededRandomSource(seed: 1))
eng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: cfg, nowMs: 1000)
checkEqual(eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset), [0,4,8,12,16], "Chase initial frame")
check(!eng.tick(nowMs: 1499), "Chase holds before 500ms")
check(eng.tick(nowMs: 1500), "Chase advances at 500ms")
checkEqual(eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset), [1,5,9,13,17], "Chase frame 1")

cfg.flashMode = .pairs
cfg.notSoMany = true
eng.configure(bounds: CGRect(x: 0, y: 0, width: 640, height: 480), settings: cfg, nowMs: 0)
let pairLit = eng.slots.enumerated().filter { $0.element.isLit }.map(\.offset)
check(eng.slots[1].isBareWire && pairLit.contains(0) && pairLit.contains(2) && !pairLit.contains(1), "Pairs + NotSoMany skips bare wire")

cfg.flashMode = .pingPong
cfg.notSoMany = false
eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: cfg, nowMs: 0)
var ppTrace = [eng.slots.firstIndex(where: \.isLit) ?? -1]
for step in 1...6 {
    eng.tick(nowMs: UInt64(step) * 500)
    ppTrace.append(eng.slots.firstIndex(where: \.isLit) ?? -1)
}
checkEqual(ppTrace, [0,1,2,3,2,1,0], "Ping-Pong bounces cleanly")

cfg.flashMode = .alternating
eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: cfg, nowMs: 0)
checkEqual(eng.slots.map(\.isLit), [false, true, false, true], "Alternating starts odd ON")
eng.tick(nowMs: 500)
checkEqual(eng.slots.map(\.isLit), [true, false, true, false], "Alternating flips at 500ms")

cfg.flashMode = .single
cfg.reverse = true
eng.configure(bounds: CGRect(x: 0, y: 0, width: 128, height: 100), settings: cfg, nowMs: 0)
checkEqual(eng.slots.map(\.isLit), [false, false, false, true], "Reverse Single starts at end")
eng.tick(nowMs: 500)
checkEqual(eng.slots.map(\.isLit), [false, false, true, false], "Reverse Single steps backward")

// 4. Around Screen Placement, NoCorners, Screen Saver Inset & RotateIcon
print("\n[4] Layout Geometry, Screen Saver Inset, and RotateIcon Pixel Mapping")
cfg = AppSettings.defaultSettings()
cfg.location = .aroundScreen
cfg.noCorners = true
cfg.notSoMany = false
eng.configure(bounds: CGRect(x: 0, y: 0, width: 320, height: 224), settings: cfg, nowMs: 0)
checkEqual(eng.slots.filter { $0.edge == .top }.count, 8, "Around+NoCorners top count == 8")
checkEqual(eng.slots.filter { $0.edge == .left }.count, 5, "Around+NoCorners side count == 5")
checkEqual(eng.slots.first?.frame.minX, 32, "Around+NoCorners clears top-left corner")

var ssSettings = AppSettings.defaultSettings()
ssSettings.location = .aroundScreen
ssSettings.ssLights = true
ssSettings.ssEnableMsg = false
let ssView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), settings: ssSettings, preview: false)
checkEqual(ssView.contentRect(), CGRect(x: 32, y: 32, width: 736, height: 536), "ScreenSaver contentRect inset (0x0046de40)")

var px = [UInt32](repeating: 0, count: 16)
px[0 * 4 + 1] = 0xFF00_00FF
let cs = CGColorSpaceCreateDeviceRGB()
let markerSrc = CGContext(data: &px, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
func markerPos(_ img: CGImage) -> (Int, Int) {
    var b = [UInt32](repeating: 0, count: 16)
    CGContext(data: &b, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(img, in: CGRect(x: 0, y: 0, width: 4, height: 4))
    for y in 0..<4 { for x in 0..<4 where b[y * 4 + x] != 0 { return (x, y) } }
    return (-1, -1)
}
check(markerPos(BulbArtworkRegistry.rotatePixelExact(markerSrc, degrees: 90)) == (3, 1), "RotateIcon +90 (Right edge)")
check(markerPos(BulbArtworkRegistry.rotatePixelExact(markerSrc, degrees: -90)) == (0, 2), "RotateIcon -90 (Left edge)")
check(markerPos(BulbArtworkRegistry.rotatePixelExact(markerSrc, degrees: 180)) == (2, 3), "RotateIcon 180 (Bottom edge)")

// 5. Highlight Blend, Audio WAV, Calendar Countdown & BLB Parser Pixel Parity
print("\n[5] Highlight Dim Blend, Calendar Countdown, Audio WAV, & PE .blb Verification")
var redPx: UInt32 = 0xFF00_00FF
let redSrc = CGContext(data: &redPx, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
let redDim = BLBResourceLoader.blendHalfWithHighlight(image: redSrc, rgb: (0, 0, 128))
let dimRGBA = sampleImageRGBA(redDim)
check(dimRGBA[0] == 127 && dimRGBA[1] == 0 && dimRGBA[2] == 64 && dimRGBA[3] == 255, "50% highlight blend math exact (127, 0, 64)")

let dec20 = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 12, day: 20))!
let sum = CalendarService.shared.countdownSummary(settings: AppSettings.defaultSettings(), from: dec20)
checkEqual(sum?.daysRemaining, 5, "Christmas countdown from Dec 20 == 5 days")

let wav = AudioEngineService.wrapPCMAsWAV(pcm: Data(repeating: 0, count: 64), sampleRate: 22050, channels: 1, bitsPerSample: 16)
check(wav.starts(with: Array("RIFF".utf8)) && wav.count == 108, "WAV RIFF container valid")

// Compare BLBResourceLoader against local extracted reference PNG & render visual comparison strips
let scratchDir = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/brain/ae66d32f-503d-4a61-9573-3261ed65b72d/scratch", isDirectory: true)
try? FileManager.default.createDirectory(at: scratchDir, withIntermediateDirectories: true)

let refBLB = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_extracted/bulbs/outdoor.blb")
let refPNG = URL(fileURLWithPath: "/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac/research/v6_dump/bulbs/outdoor/ico_7021_32x32_8b_id5.png")
if let loadedBLB = BLBResourceLoader.load(url: refBLB, preferredSize: 32, highlightRGB: (0, 0, 128)),
   let refImg = loadPNGImage(at: refPNG),
   let blbRedOn = loadedBLB.onImages[2] {
    let a = sampleImageRGBA(blbRedOn)
    let b = sampleImageRGBA(refImg)
    check(a == b, "BLBResourceLoader decoded outdoor.blb Red ON matches extracted Win32 reference byte-for-byte (\(a.count) bytes)")

    // Compare clean-room built-in Outdoor bulb geometry vs original Outdoor bulb
    var crSettings = AppSettings.defaultSettings()
    crSettings.bulbSetName = "Outdoor"
    crSettings.colorMode = .multiColor
    crSettings.flashMode = .none
    crSettings.notSoMany = true
    let cleanEng = BulbEngine(settings: crSettings, rng: SeededRandomSource(seed: 1))
    cleanEng.configure(bounds: CGRect(x: 0, y: 0, width: 448, height: 32), settings: crSettings, nowMs: 0)
    if let cleanStrip = BulbCanvasView.renderSnapshot(width: 448, height: 32, engine: cleanEng, settings: crSettings, backgroundColor: .black) {
        _ = writePNG(cleanStrip, to: scratchDir.appendingPathComponent("verify_outdoor_strip_clean.png"))
    }
    if let redTile = BulbArtworkRegistry.shared.image(for: BulbSlot(index: 0, frame: CGRect(x: 0, y: 0, width: 32, height: 32), edge: .top, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: true, flashable: true, nextToggleMs: 0), settings: crSettings) {
        let origStats = opaquePixelStats(refImg)
        let cleanStats = opaquePixelStats(redTile)
        print("  [INFO] Outdoor Red ON: Orig bbox=(\(origStats.minX),\(origStats.minY))..(\(origStats.maxX),\(origStats.maxY)) luma=\(Int(origStats.avgLuma)) | Clean bbox=(\(cleanStats.minX),\(cleanStats.minY))..(\(cleanStats.maxX),\(cleanStats.maxY)) luma=\(Int(cleanStats.avgLuma))")
        check(abs(origStats.maxY - cleanStats.maxY) <= 1 && cleanStats.minX == 0 && cleanStats.maxX == 31, "Clean-room Outdoor bulb connects full 0..31 wire and matches 31px drop")
    }
}

// Render multi-edge Around Screen + All 21 Color Showcase + ScreenSaver verification snapshots
var showcase = AppSettings.defaultSettings()
showcase.bulbSetName = "Outdoor"
showcase.location = .aroundScreen
showcase.noCorners = true
showcase.notSoMany = true
showcase.inward = true
showcase.colorMode = .allColorsWhite
showcase.flashMode = .none
let aroundEng = BulbEngine(settings: showcase, rng: SeededRandomSource(seed: 7))
aroundEng.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 320), settings: showcase, nowMs: 0)
if let snap = BulbCanvasView.renderSnapshot(width: 512, height: 320, engine: aroundEng, settings: showcase, backgroundColor: NSColor(srgbRed: 0.05, green: 0.09, blue: 0.16, alpha: 1)) {
    let url = scratchDir.appendingPathComponent("verify_around_inward.png")
    check(writePNG(snap, to: url), "Wrote Around Screen inward-rotated visual verification snapshot")
}

// Render contact sheet of all 15 built-in bulb sets (ON, OFF, Broken across colors)
let styles = BulbArtworkRegistry.BuiltInStyle.allCases
let sheetW = 480
let rowH = 36
let sheetH = styles.count * rowH + 16
if let sCtx = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: sheetW * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
    sCtx.translateBy(x: 0, y: CGFloat(sheetH))
    sCtx.scaleBy(x: 1, y: -1)
    sCtx.setFillColor(NSColor(srgbRed: 0.07, green: 0.10, blue: 0.16, alpha: 1).cgColor)
    sCtx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))

    for (rIdx, style) in styles.enumerated() {
        var st = AppSettings.defaultSettings()
        st.bulbSetName = style.rawValue
        st.notSoMany = false
        let yBase = CGFloat(rIdx * rowH + 8)
        // Draw 7 lit colors + 2 off + 1 bareWire + 1 broken = 11 tiles across x=116..468
        for col in 0..<7 {
            let slot = BulbSlot(index: col, frame: CGRect(x: 116 + CGFloat(col * 32), y: yBase, width: 32, height: 32), edge: .top, colorIndex: col, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: true, flashable: true, nextToggleMs: 0)
            if let img = BulbArtworkRegistry.shared.image(for: slot, settings: st) {
                sCtx.saveGState()
                sCtx.translateBy(x: slot.frame.minX, y: slot.frame.maxY)
                sCtx.scaleBy(x: 1, y: -1)
                sCtx.draw(img, in: CGRect(x: 0, y: 0, width: 32, height: 32))
                sCtx.restoreGState()
            }
        }
        let offSlot = BulbSlot(index: 7, frame: CGRect(x: 116 + 7 * 32, y: yBase, width: 32, height: 32), edge: .top, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: false, isBurnedOut: false, isLit: false, flashable: true, nextToggleMs: 0)
        let wireSlot = BulbSlot(index: 8, frame: CGRect(x: 116 + 8 * 32, y: yBase, width: 32, height: 32), edge: .top, colorIndex: 0, isBareWire: true, isMissing: false, isBroken: false, isBurnedOut: false, isLit: false, flashable: false, nextToggleMs: 0)
        let brkSlot = BulbSlot(index: 9, frame: CGRect(x: 116 + 9 * 32, y: yBase, width: 32, height: 32), edge: .top, colorIndex: 2, isBareWire: false, isMissing: false, isBroken: true, isBurnedOut: false, isLit: false, flashable: false, nextToggleMs: 0)
        for extraSlot in [offSlot, wireSlot, brkSlot] {
            if let img = BulbArtworkRegistry.shared.image(for: extraSlot, settings: st) {
                sCtx.saveGState()
                sCtx.translateBy(x: extraSlot.frame.minX, y: extraSlot.frame.maxY)
                sCtx.scaleBy(x: 1, y: -1)
                sCtx.draw(img, in: CGRect(x: 0, y: 0, width: 32, height: 32))
                sCtx.restoreGState()
            }
        }
    }
    if let contactImg = sCtx.makeImage() {
        check(writePNG(contactImg, to: scratchDir.appendingPathComponent("verify_all_sets_on_off.png")), "Wrote contact sheet for all 15 built-in bulb sets")
    }
}

// Render Screen Savers (Snowfall + Fireworks) stepped frames with perimeter bulbs
func snapshotView(_ view: NSView, to url: URL) -> Bool {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let cg = rep.cgImage else { return false }
    return writePNG(cg, to: url)
}

var snowCfg = AppSettings.defaultSettings()
snowCfg.ssModule = .snowfall
snowCfg.ssLights = true
snowCfg.ssMsg = "HAPPY HOLIDAYS FROM TWINKLE BULBS!"
let snowView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), settings: snowCfg, preview: false)
for _ in 0..<45 { snowView.stepFrame() }
check(snapshotView(snowView, to: scratchDir.appendingPathComponent("verify_ss_snowfall.png")), "Rendered Snowfall screen saver verification frame")

var fwCfg = AppSettings.defaultSettings()
fwCfg.ssModule = .fireworks
fwCfg.ssLights = true
fwCfg.colorMode = .multiColor
fwCfg.location = .aroundScreen
let fwView = ScreenSaverCanvasView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), settings: fwCfg, preview: false)
for _ in 0..<60 { fwView.stepFrame() }
check(snapshotView(fwView, to: scratchDir.appendingPathComponent("verify_ss_fireworks.png")), "Rendered Fireworks screen saver verification frame")

// Snapshot Preferences UI & Quick Access Bar content views
_ = NSApplication.shared
let prefsWinCtrl = PreferencesWindowController()
if let content = prefsWinCtrl.window?.contentView {
    content.layoutSubtreeIfNeeded()
    check(snapshotView(content, to: scratchDir.appendingPathComponent("verify_prefs_ui.png")), "Rendered Preferences UI snapshot")
}
let qaCtrl = QuickAccessPanelController()
if let qaContent = qaCtrl.window?.contentView {
    qaContent.layoutSubtreeIfNeeded()
    check(snapshotView(qaContent, to: scratchDir.appendingPathComponent("verify_quick_access.png")), "Rendered Quick Access panel snapshot")
}

print("\nSUMMARY: \(passedCount) passed, \(failedCount) failed")
if failedCount > 0 { exit(1) }
