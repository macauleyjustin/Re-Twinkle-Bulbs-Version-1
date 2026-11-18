import Cocoa

// MARK: - Main Multi-Tab Preferences Window (Twinkle Bulbs 6.0 Configuration)

public final class PreferencesWindowController: NSWindowController {
    var draft: AppSettings = SettingsStore.shared.settings

    private let tabView = NSTabView()
    private let monitorPreview = MonitorPreviewView()

    // Bulbs Tab Controls
    private let bulbSetPopup = NSPopUpButton()
    private let sampleImageView = NSImageView()
    private let flashModePopup = NSPopUpButton()
    private let ratePopup = NSPopUpButton()
    private let colorPopup = NSPopUpButton()
    private let locationPopup = NSPopUpButton()
    private let drawModePopup = NSPopUpButton()
    private let bulbSizePopup = NSPopUpButton()
    private let monitorPopup = NSPopUpButton()
    private let bareWireCheck = NSButton(checkboxWithTitle: "Draw Bare Wire Between Bulbs", target: nil, action: nil)
    private let noCornersCheck = NSButton(checkboxWithTitle: "Leave Screen Corners Blank", target: nil, action: nil)
    private let notSoManyCheck = NSButton(checkboxWithTitle: "Fewer Bulbs (Every 2nd Socket)", target: nil, action: nil)
    private let brokenCheck = NSButton(checkboxWithTitle: "Broken Bulbs (16%)", target: nil, action: nil)
    private let burnedOutCheck = NSButton(checkboxWithTitle: "Burned Out Bulbs (30%)", target: nil, action: nil)
    private let missingCheck = NSButton(checkboxWithTitle: "Missing Bulbs (20%)", target: nil, action: nil)
    private let mixBulbsCheck = NSButton(checkboxWithTitle: "Mix Multiple Bulb Sets", target: nil, action: nil)
    private let reverseCheck = NSButton(checkboxWithTitle: "Reverse Direction", target: nil, action: nil)
    private let inwardCheck = NSButton(checkboxWithTitle: "Point Bulbs Inward", target: nil, action: nil)
    private let useAllMonitorsCheck = NSButton(checkboxWithTitle: "Show Across All Monitors", target: nil, action: nil)
    private let bulbChangerCheck = NSButton(checkboxWithTitle: "Auto-Rotate Bulb Set Every (min):", target: nil, action: nil)
    private let bulbChangerFreqField = NSTextField()

    // General Tab Controls
    private let leftClickPopup = NSPopUpButton()
    private let rightClickPopup = NSPopUpButton()
    private let middleClickPopup = NSPopUpButton()
    private let trayIconPopup = NSPopUpButton()
    private let splashCheck = NSButton(checkboxWithTitle: "Show Splash Screen on Startup", target: nil, action: nil)
    private let toolTipsCheck = NSButton(checkboxWithTitle: "Show ToolTips", target: nil, action: nil)
    private let soundFXCheck = NSButton(checkboxWithTitle: "Play UI Sound Effects", target: nil, action: nil)
    private let flashIconCheck = NSButton(checkboxWithTitle: "Flash Menu Bar Icon with Bulbs", target: nil, action: nil)
    private let quickAccessCheck = NSButton(checkboxWithTitle: "Show Quick Access Floating Bar", target: nil, action: nil)
    private let confirmExitCheck = NSButton(checkboxWithTitle: "Confirm Before Exiting", target: nil, action: nil)
    private let runSSOnlyCheck = NSButton(checkboxWithTitle: "Run Screen Saver Mode Only (No Desktop Bulbs)", target: nil, action: nil)
    private let startupCalendarCheck = NSButton(checkboxWithTitle: "Show Event Calendar on Startup", target: nil, action: nil)
    private let startupOptionsCheck = NSButton(checkboxWithTitle: "Open Settings on Startup", target: nil, action: nil)
    private let sysHighlightCheck = NSButton(checkboxWithTitle: "Use Classic System Navy (#000080) Highlight for On-Only Bulb Dimming", target: nil, action: nil)
    private let highlightWell = NSColorWell()

    // Secondary tab coordinator
    private lazy var secondaryTabs = PreferencesSecondaryTabsCoordinator(owner: self)

    var onApplySettings: ((AppSettings) -> Void)?
    var onStartScreenSaverNow: (() -> Void)?
    var onOpenCalendarViewer: (() -> Void)?

    public convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Twinkle Bulbs 6.0 — Settings"
        win.center()
        win.isReleasedWhenClosed = false
        self.init(window: win)
        buildWindowUI()
        loadFromSettings(SettingsStore.shared.settings)
    }

    func showAndReload() {
        loadFromSettings(SettingsStore.shared.settings)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindowUI() {
        guard let root = window?.contentView else { return }

        tabView.frame = NSRect(x: 16, y: 56, width: 728, height: 490)
        tabView.tabViewType = .topTabsBezelBorder

        tabView.addTabViewItem(makeBulbsTab())
        tabView.addTabViewItem(makeGeneralTab())
        tabView.addTabViewItem(secondaryTabs.makeMusicTab())
        tabView.addTabViewItem(secondaryTabs.makeScreenSaverTab())
        tabView.addTabViewItem(secondaryTabs.makeWallpaperTab())
        tabView.addTabViewItem(secondaryTabs.makeCalendarTab())
        tabView.addTabViewItem(secondaryTabs.makeHelpAndToolsTab())
        root.addSubview(tabView)

        // Bottom OK / Cancel / Apply / Reset bar
        let resetBtn = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaultsPressed))
        resetBtn.frame = NSRect(x: 16, y: 14, width: 120, height: 30)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancelBtn.frame = NSRect(x: 472, y: 14, width: 84, height: 30)
        cancelBtn.keyEquivalent = "\u{1b}"

        let applyBtn = NSButton(title: "Apply", target: self, action: #selector(applyPressed))
        applyBtn.frame = NSRect(x: 564, y: 14, width: 84, height: 30)

        let okBtn = NSButton(title: "OK", target: self, action: #selector(okPressed))
        okBtn.frame = NSRect(x: 656, y: 14, width: 88, height: 30)
        okBtn.keyEquivalent = "\r"

        root.addSubview(resetBtn)
        root.addSubview(cancelBtn)
        root.addSubview(applyBtn)
        root.addSubview(okBtn)
    }

    // MARK: - Bulbs Tab (DIALOG/131 + Monitor Preview)

    private func makeBulbsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "bulbs")
        item.label = "Bulbs"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        // Left column: Monitor Preview + Sample + Info + Import
        let previewBox = NSBox(frame: NSRect(x: 12, y: 185, width: 255, height: 242))
        previewBox.title = "Monitor Preview"
        monitorPreview.frame = NSRect(x: 6, y: 8, width: 240, height: 210)
        previewBox.contentView?.addSubview(monitorPreview)
        view.addSubview(previewBox)

        let sampleBox = NSBox(frame: NSRect(x: 12, y: 60, width: 255, height: 118))
        sampleBox.title = "Selected Bulb Set"
        sampleImageView.frame = NSRect(x: 14, y: 50, width: 42, height: 42)
        sampleImageView.imageScaling = .scaleProportionallyUpOrDown
        bulbSetPopup.frame = NSRect(x: 64, y: 56, width: 175, height: 26)
        bulbSetPopup.target = self
        bulbSetPopup.action = #selector(bulbsControlChanged)

        let propsBtn = NSButton(title: "Properties...", target: self, action: #selector(showBulbProperties))
        propsBtn.frame = NSRect(x: 14, y: 12, width: 108, height: 26)
        let importBtn = NSButton(title: "Import .BLB/.ICO...", target: self, action: #selector(importBulbAssets))
        importBtn.frame = NSRect(x: 128, y: 12, width: 114, height: 26)

        sampleBox.contentView?.addSubview(sampleImageView)
        sampleBox.contentView?.addSubview(bulbSetPopup)
        sampleBox.contentView?.addSubview(propsBtn)
        sampleBox.contentView?.addSubview(importBtn)
        view.addSubview(sampleBox)

        let lightsOnBtn = NSButton(title: "Toggle Lights On / Off", target: self, action: #selector(toggleLightsQuick))
        lightsOnBtn.frame = NSRect(x: 12, y: 16, width: 255, height: 32)
        view.addSubview(lightsOnBtn)

        // Middle column: Pattern, Speed, Color, Location, DrawMode, Size
        let styleBox = NSBox(frame: NSRect(x: 278, y: 185, width: 222, height: 242))
        styleBox.title = "Appearance & Timing"
        func addRow(_ label: String, _ control: NSView, y: CGFloat) {
            let lbl = NSTextField(labelWithString: label)
            lbl.font = .systemFont(ofSize: 11)
            lbl.frame = NSRect(x: 10, y: y + 18, width: 196, height: 15)
            control.frame = NSRect(x: 10, y: y - 4, width: 198, height: 24)
            styleBox.contentView?.addSubview(lbl)
            styleBox.contentView?.addSubview(control)
        }

        flashModePopup.addItems(withTitles: FlashMode.allCases.map(\.displayName))
        flashModePopup.target = self; flashModePopup.action = #selector(bulbsControlChanged)
        addRow("Flashing Mode:", flashModePopup, y: 182)

        ratePopup.addItems(withTitles: FlashRate.allCases.map(\.displayName))
        ratePopup.target = self; ratePopup.action = #selector(bulbsControlChanged)
        addRow("Flash Rate:", ratePopup, y: 142)

        colorPopup.addItems(withTitles: ColorMode.allCases.map(\.displayName))
        colorPopup.target = self; colorPopup.action = #selector(bulbsControlChanged)
        addRow("Color Sequence:", colorPopup, y: 102)

        locationPopup.addItems(withTitles: BulbLocation.allCases.map(\.displayName))
        locationPopup.target = self; locationPopup.action = #selector(bulbsControlChanged)
        addRow("Screen Location:", locationPopup, y: 62)

        drawModePopup.addItems(withTitles: DrawMode.allCases.map(\.displayName))
        drawModePopup.target = self; drawModePopup.action = #selector(bulbsControlChanged)
        addRow("Draw Layer:", drawModePopup, y: 22)

        view.addSubview(styleBox)

        let sizeBox = NSBox(frame: NSRect(x: 278, y: 16, width: 222, height: 162))
        sizeBox.title = "Size & Multi-Monitor"
        bulbSizePopup.addItems(withTitles: BulbSizeOption.allCases.map(\.displayName))
        bulbSizePopup.target = self; bulbSizePopup.action = #selector(bulbsControlChanged)
        bulbSizePopup.frame = NSRect(x: 10, y: 108, width: 198, height: 24)

        useAllMonitorsCheck.frame = NSRect(x: 10, y: 78, width: 198, height: 20)
        useAllMonitorsCheck.target = self; useAllMonitorsCheck.action = #selector(bulbsControlChanged)
        monitorPopup.frame = NSRect(x: 10, y: 46, width: 198, height: 24)
        monitorPopup.target = self; monitorPopup.action = #selector(bulbsControlChanged)

        bulbChangerCheck.frame = NSRect(x: 10, y: 14, width: 150, height: 20)
        bulbChangerCheck.font = .systemFont(ofSize: 11)
        bulbChangerCheck.target = self; bulbChangerCheck.action = #selector(bulbsControlChanged)
        bulbChangerFreqField.frame = NSRect(x: 164, y: 12, width: 44, height: 22)

        sizeBox.contentView?.addSubview(bulbSizePopup)
        sizeBox.contentView?.addSubview(useAllMonitorsCheck)
        sizeBox.contentView?.addSubview(monitorPopup)
        sizeBox.contentView?.addSubview(bulbChangerCheck)
        sizeBox.contentView?.addSubview(bulbChangerFreqField)
        view.addSubview(sizeBox)

        // Right column: Effects & Layout Checkboxes
        let optBox = NSBox(frame: NSRect(x: 508, y: 16, width: 192, height: 411))
        optBox.title = "Strand & Bulb Options"
        let checks = [
            bareWireCheck, noCornersCheck, notSoManyCheck, inwardCheck, reverseCheck,
            mixBulbsCheck, brokenCheck, burnedOutCheck, missingCheck
        ]
        for (idx, chk) in checks.enumerated() {
            chk.frame = NSRect(x: 10, y: 356 - CGFloat(idx) * 34, width: 174, height: 22)
            chk.target = self
            chk.action = #selector(bulbsControlChanged)
            optBox.contentView?.addSubview(chk)
        }
        let advBtn = NSButton(title: "Advanced Highlight...", target: self, action: #selector(bulbsControlChanged))
        advBtn.isHidden = true // Highlight controls sit directly in General tab cleanly
        optBox.contentView?.addSubview(advBtn)
        view.addSubview(optBox)

        item.view = view
        return item
    }

    // MARK: - General Tab (DIALOG/139)

    private func makeGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "general")
        item.label = "General"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let trayBox = NSBox(frame: NSRect(x: 16, y: 230, width: 330, height: 194))
        trayBox.title = "Menu Bar Icon Actions"
        let actionNames = TrayClickAction.allCases.map(\.displayName)
        for p in [leftClickPopup, rightClickPopup, middleClickPopup] {
            p.addItems(withTitles: actionNames)
            p.target = self; p.action = #selector(generalControlChanged)
        }
        trayIconPopup.addItems(withTitles: ["Yellow Glow Bulb", "Red Ornament Bulb", "Green Pine Bulb", "Ice Blue Bulb"])
        trayIconPopup.target = self; trayIconPopup.action = #selector(generalControlChanged)

        let rows: [(String, NSView, CGFloat)] = [
            ("Menu Bar Icon Style:", trayIconPopup, 140),
            ("Left Click:", leftClickPopup, 102),
            ("Right Click:", rightClickPopup, 64),
            ("Middle Click:", middleClickPopup, 26)
        ]
        for (lblTxt, ctrl, y) in rows {
            let lbl = NSTextField(labelWithString: lblTxt)
            lbl.frame = NSRect(x: 12, y: y + 4, width: 132, height: 18)
            ctrl.frame = NSRect(x: 148, y: y, width: 168, height: 24)
            trayBox.contentView?.addSubview(lbl)
            trayBox.contentView?.addSubview(ctrl)
        }
        view.addSubview(trayBox)

        let behBox = NSBox(frame: NSRect(x: 356, y: 120, width: 338, height: 304))
        behBox.title = "Startup, Audio & Behavior"
        let checks = [
            splashCheck, soundFXCheck, flashIconCheck, quickAccessCheck,
            confirmExitCheck, toolTipsCheck, startupCalendarCheck,
            startupOptionsCheck, runSSOnlyCheck
        ]
        for (idx, chk) in checks.enumerated() {
            chk.frame = NSRect(x: 12, y: 248 - CGFloat(idx) * 29, width: 314, height: 22)
            chk.target = self; chk.action = #selector(generalControlChanged)
            behBox.contentView?.addSubview(chk)
        }
        view.addSubview(behBox)

        let hlBox = NSBox(frame: NSRect(x: 16, y: 120, width: 330, height: 100))
        hlBox.title = "Icon Bulb Dimming Highlight Color"
        sysHighlightCheck.frame = NSRect(x: 12, y: 46, width: 306, height: 34)
        sysHighlightCheck.target = self; sysHighlightCheck.action = #selector(generalControlChanged)
        let hlLabel = NSTextField(labelWithString: "Custom Dim Blend Color:")
        hlLabel.frame = NSRect(x: 12, y: 16, width: 170, height: 20)
        highlightWell.frame = NSRect(x: 190, y: 12, width: 64, height: 26)
        highlightWell.target = self; highlightWell.action = #selector(generalControlChanged)
        hlBox.contentView?.addSubview(sysHighlightCheck)
        hlBox.contentView?.addSubview(hlLabel)
        hlBox.contentView?.addSubview(highlightWell)
        view.addSubview(hlBox)

        item.view = view
        return item
    }

    // MARK: - Sync State -> Controls -> Model

    func loadFromSettings(_ s: AppSettings) {
        self.draft = s
        refreshBulbSetDropdown()
        refreshMonitorDropdown()

        flashModePopup.selectItem(at: s.flashMode.rawValue)
        ratePopup.selectItem(at: s.rate.rawValue)
        colorPopup.selectItem(at: s.colorMode.rawValue)
        locationPopup.selectItem(at: s.location.rawValue)
        drawModePopup.selectItem(at: s.drawMode.rawValue)
        bulbSizePopup.selectItem(at: s.bulbSize.rawValue)

        bareWireCheck.state = s.bareWire ? .on : .off
        noCornersCheck.state = s.noCorners ? .on : .off
        notSoManyCheck.state = s.notSoMany ? .on : .off
        brokenCheck.state = s.broken ? .on : .off
        burnedOutCheck.state = s.burnedOut ? .on : .off
        missingCheck.state = s.missing ? .on : .off
        mixBulbsCheck.state = s.mixBulbs ? .on : .off
        reverseCheck.state = s.reverse ? .on : .off
        inwardCheck.state = s.inward ? .on : .off
        useAllMonitorsCheck.state = s.useAllMonitors ? .on : .off
        bulbChangerCheck.state = s.bulbChanger ? .on : .off
        bulbChangerFreqField.integerValue = s.bulbChangeFreqMinutes

        trayIconPopup.selectItem(at: max(0, min(3, s.trayIconIndex)))
        leftClickPopup.selectItem(at: s.trayLeftClick.rawValue)
        rightClickPopup.selectItem(at: s.trayRightClick.rawValue)
        middleClickPopup.selectItem(at: s.trayMiddleClick.rawValue)
        splashCheck.state = s.splashScreen ? .on : .off
        toolTipsCheck.state = s.toolTips ? .on : .off
        soundFXCheck.state = s.soundFX ? .on : .off
        flashIconCheck.state = s.flashIcon ? .on : .off
        quickAccessCheck.state = s.quickAccess ? .on : .off
        confirmExitCheck.state = s.confirmExit ? .on : .off
        runSSOnlyCheck.state = s.runSSOnly ? .on : .off
        startupCalendarCheck.state = s.startupCalendar ? .on : .off
        startupOptionsCheck.state = s.startupOptions ? .on : .off
        sysHighlightCheck.state = s.sysColorHighlight ? .on : .off
        highlightWell.color = NSColor(hex: s.highlightColorHex, fallback: NSColor(srgbRed: 0, green: 0, blue: 0.5, alpha: 1))
        highlightWell.isEnabled = !s.sysColorHighlight

        secondaryTabs.loadFromSettings(s)
        updatePreviews()
    }

    func refreshBulbSetDropdown() {
        let sets = BulbArtworkRegistry.shared.availableSets
        bulbSetPopup.removeAllItems()
        for set in sets {
            bulbSetPopup.addItem(withTitle: set.title)
            bulbSetPopup.lastItem?.representedObject = set.id
        }
        let targetID = BulbArtworkRegistry.shared.resolveSetID(draft.bulbSetName)
        if let idx = sets.firstIndex(where: { $0.id == targetID }) {
            bulbSetPopup.selectItem(at: idx)
        }
    }

    private func refreshMonitorDropdown() {
        let screens = NSScreen.screens
        monitorPopup.removeAllItems()
        for (i, scr) in screens.enumerated() {
            let sz = scr.frame.size
            monitorPopup.addItem(withTitle: "Display \(i + 1) (\(Int(sz.width))×\(Int(sz.height)))")
        }
        if !screens.isEmpty {
            monitorPopup.selectItem(at: min(max(0, draft.drawMonitorIndex), screens.count - 1))
        }
        monitorPopup.isEnabled = !draft.useAllMonitors
    }

    @objc private func bulbsControlChanged() {
        if let id = bulbSetPopup.selectedItem?.representedObject as? String {
            draft.bulbSetName = id
        }
        draft.flashMode = FlashMode(rawValue: flashModePopup.indexOfSelectedItem) ?? .chase
        draft.rate = FlashRate(rawValue: ratePopup.indexOfSelectedItem) ?? .medium
        draft.colorMode = ColorMode(rawValue: colorPopup.indexOfSelectedItem) ?? .redGreen
        draft.location = BulbLocation(rawValue: locationPopup.indexOfSelectedItem) ?? .top
        draft.drawMode = DrawMode(rawValue: drawModePopup.indexOfSelectedItem) ?? .desktop
        draft.bulbSize = BulbSizeOption(rawValue: bulbSizePopup.indexOfSelectedItem) ?? .normal
        draft.bareWire = bareWireCheck.state == .on
        draft.noCorners = noCornersCheck.state == .on
        draft.notSoMany = notSoManyCheck.state == .on
        draft.broken = brokenCheck.state == .on
        draft.burnedOut = burnedOutCheck.state == .on
        draft.missing = missingCheck.state == .on
        draft.mixBulbs = mixBulbsCheck.state == .on
        draft.reverse = reverseCheck.state == .on
        draft.inward = inwardCheck.state == .on
        draft.useAllMonitors = useAllMonitorsCheck.state == .on
        draft.drawMonitorIndex = max(0, monitorPopup.indexOfSelectedItem)
        draft.bulbChanger = bulbChangerCheck.state == .on
        draft.bulbChangeFreqMinutes = max(1, bulbChangerFreqField.integerValue)
        monitorPopup.isEnabled = !draft.useAllMonitors
        AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
        updatePreviews()
    }

    @objc private func generalControlChanged() {
        draft.trayIconIndex = max(0, trayIconPopup.indexOfSelectedItem)
        draft.trayLeftClick = TrayClickAction(rawValue: leftClickPopup.indexOfSelectedItem) ?? .configuration
        draft.trayRightClick = TrayClickAction(rawValue: rightClickPopup.indexOfSelectedItem) ?? .popupMenu
        draft.trayMiddleClick = TrayClickAction(rawValue: middleClickPopup.indexOfSelectedItem) ?? .popupMenu
        draft.splashScreen = splashCheck.state == .on
        draft.toolTips = toolTipsCheck.state == .on
        draft.soundFX = soundFXCheck.state == .on
        draft.flashIcon = flashIconCheck.state == .on
        draft.quickAccess = quickAccessCheck.state == .on
        draft.confirmExit = confirmExitCheck.state == .on
        draft.runSSOnly = runSSOnlyCheck.state == .on
        draft.startupCalendar = startupCalendarCheck.state == .on
        draft.startupOptions = startupOptionsCheck.state == .on
        draft.sysColorHighlight = sysHighlightCheck.state == .on
        draft.highlightColorHex = highlightWell.color.hexString
        highlightWell.isEnabled = !draft.sysColorHighlight
        AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
        updatePreviews()
    }

    func updatePreviews() {
        monitorPreview.configure(with: draft)
        if let cg = BulbArtworkRegistry.shared.sampleImage(for: draft.bulbSetName) {
            sampleImageView.image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    @objc private func toggleLightsQuick() {
        draft.lightsEnabled.toggle()
        AudioEngineService.shared.playEffect(.click, enabled: draft.soundFX)
        updatePreviews()
        applyPressed()
    }

    @objc private func showBulbProperties() {
        guard let meta = BulbArtworkRegistry.shared.metadata(for: BulbArtworkRegistry.shared.resolveSetID(draft.bulbSetName)) else { return }
        let alert = NSAlert()
        alert.messageText = meta.title
        alert.informativeText =
            "Author: \(meta.author)\nVersion: \(meta.version)\nCreation Date: \(meta.creationDate.isEmpty ? "N/A" : meta.creationDate)\n" +
            "Monochrome: \(meta.isMonochrome ? "Yes" : "No") | On-Only Blend Dim: \(meta.isOnOnly ? "Yes" : "No")\n\n\(meta.comment)"
        alert.runModal()
    }

    @objc private func importBulbAssets() {
        let panel = NSOpenPanel()
        panel.title = "Import Original .blb / .icl / .ico Bulb Sets"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            let destDir = BulbArtworkRegistry.importedBulbsDirectory
            var importedCount = 0
            for url in panel.urls {
                let dest = destDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                    importedCount += 1
                }
            }
            if importedCount > 0 {
                BulbArtworkRegistry.shared.reloadAllSets(size: draft.bulbSize.pixels, highlightHex: draft.sysColorHighlight ? "#000080" : draft.highlightColorHex)
                refreshBulbSetDropdown()
                updatePreviews()
            }
        }
    }

    @objc func applyPressed() {
        secondaryTabs.commitFieldsIntoDraft()
        SettingsStore.shared.settings = draft
        onApplySettings?(draft)
        AudioEngineService.shared.playEffect(.click, enabled: draft.soundFX)
    }

    @objc private func okPressed() {
        applyPressed()
        window?.orderOut(nil)
    }

    @objc private func cancelPressed() {
        window?.orderOut(nil)
    }

    @objc private func resetDefaultsPressed() {
        let def = AppSettings.defaultSettings()
        loadFromSettings(def)
        SettingsStore.shared.settings = def
        onApplySettings?(def)
    }
}
