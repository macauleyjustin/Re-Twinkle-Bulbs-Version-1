import Cocoa

final class PreferencesSecondaryTabsCoordinator: NSObject {
    private unowned let owner: PreferencesWindowController

    // Music tab
    private let musicEnableCheck = NSButton(checkboxWithTitle: "Enable Background Holiday Music", target: nil, action: nil)
    private let musicOrderPopup = NSPopUpButton()
    private let musicOnlySSCheck = NSButton(checkboxWithTitle: "Play Music Only During Screen Saver", target: nil, action: nil)
    private let musicPauseCheck = NSButton(checkboxWithTitle: "Auto-Pause After (min):", target: nil, action: nil)
    private let musicPauseField = NSTextField()
    private let musicPopup = NSPopUpButton()
    private let nowPlayingLbl = NSTextField(labelWithString: "Status: Stopped")

    // Screen Saver tab
    private let ssEnableCheck = NSButton(checkboxWithTitle: "Enable Automatic Screen Saver After (min):", target: nil, action: nil)
    private let ssDelayField = NSTextField()
    private let ssModulePopup = NSPopUpButton()
    private let ssLightsCheck = NSButton(checkboxWithTitle: "Show Twinkle Bulbs Around Screen Saver", target: nil, action: nil)
    private let ssLogoCheck = NSButton(checkboxWithTitle: "Show Twinkle Bulbs 6.0 Watermark", target: nil, action: nil)
    private let ssEnableMsgCheck = NSButton(checkboxWithTitle: "Display Message:", target: nil, action: nil)
    private let ssMsgField = NSTextField()
    private let ssMsgColorWell = NSColorWell()
    private let ssMsgBoldCheck = NSButton(checkboxWithTitle: "Bold", target: nil, action: nil)
    private let ssScrollMsgCheck = NSButton(checkboxWithTitle: "Scroll Message", target: nil, action: nil)
    private let ssMouseClickCheck = NSButton(checkboxWithTitle: "Exit on Click", target: nil, action: nil)
    private let ssMouseMoveCheck = NSButton(checkboxWithTitle: "Exit on Move", target: nil, action: nil)
    private let ssKeyboardCheck = NSButton(checkboxWithTitle: "Exit on Keypress", target: nil, action: nil)
    private let ssHotCornersCheck = NSButton(checkboxWithTitle: "Hot Corner (Top-Right Screen Corner Launches Saver)", target: nil, action: nil)
    private var ssMiniPreview: ScreenSaverCanvasView?
    private var ssMiniTimer: Timer?

    // Wallpaper tab
    private let wallpaperPopup = NSPopUpButton()
    private let wpStylePopup = NSPopUpButton()
    private let wpAutoRotateCheck = NSButton(checkboxWithTitle: "Auto-Rotate Wallpapers Every (min):", target: nil, action: nil)
    private let wpFreqField = NSTextField()
    private let wpPreviewImage = NSImageView()

    // Calendar tab
    private let holidayPopup = NSPopUpButton()
    private let countdownStatusLbl = NSTextField(labelWithString: "")
    private let eventMsgsCheck = NSButton(checkboxWithTitle: "Show Startup Greeting Messages for Matching Dates", target: nil, action: nil)
    private let customNameField = NSTextField()
    private let customDateField = NSTextField()

    init(owner: PreferencesWindowController) {
        self.owner = owner
        super.init()
    }

    deinit {
        ssMiniTimer?.invalidate()
    }

    // MARK: - Music Tab (DIALOG/133)

    func makeMusicTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "music")
        item.label = "Music"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let box = NSBox(frame: NSRect(x: 16, y: 120, width: 678, height: 300))
        box.title = "Holiday Music Playback"

        musicEnableCheck.frame = NSRect(x: 16, y: 244, width: 320, height: 22)
        musicEnableCheck.target = self; musicEnableCheck.action = #selector(controlChanged)

        let lblTrack = NSTextField(labelWithString: "Selected Song:")
        lblTrack.frame = NSRect(x: 16, y: 204, width: 120, height: 18)
        musicPopup.frame = NSRect(x: 140, y: 200, width: 340, height: 26)

        let playBtn = NSButton(title: "Play Selected", target: self, action: #selector(playSelectedTrack))
        playBtn.frame = NSRect(x: 16, y: 156, width: 120, height: 28)
        let stopBtn = NSButton(title: "Stop", target: self, action: #selector(stopMusic))
        stopBtn.frame = NSRect(x: 144, y: 156, width: 84, height: 28)
        let nextBtn = NSButton(title: "Next Track", target: self, action: #selector(nextTrack))
        nextBtn.frame = NSRect(x: 236, y: 156, width: 100, height: 28)
        let impBtn = NSButton(title: "Import .MID / Audio...", target: self, action: #selector(importMusicFiles))
        impBtn.frame = NSRect(x: 348, y: 156, width: 160, height: 28)

        let ordLbl = NSTextField(labelWithString: "Play Order:")
        ordLbl.frame = NSRect(x: 16, y: 114, width: 110, height: 18)
        musicOrderPopup.addItems(withTitles: ["Sequential", "Random"])
        musicOrderPopup.frame = NSRect(x: 140, y: 110, width: 160, height: 24)
        musicOrderPopup.target = self; musicOrderPopup.action = #selector(controlChanged)

        musicOnlySSCheck.frame = NSRect(x: 16, y: 74, width: 320, height: 22)
        musicOnlySSCheck.target = self; musicOnlySSCheck.action = #selector(controlChanged)

        musicPauseCheck.frame = NSRect(x: 16, y: 40, width: 200, height: 22)
        musicPauseCheck.target = self; musicPauseCheck.action = #selector(controlChanged)
        musicPauseField.frame = NSRect(x: 220, y: 40, width: 52, height: 22)

        nowPlayingLbl.frame = NSRect(x: 16, y: 12, width: 500, height: 18)
        nowPlayingLbl.textColor = .secondaryLabelColor

        for v: NSView in [musicEnableCheck, lblTrack, musicPopup, playBtn, stopBtn, nextBtn, impBtn, ordLbl, musicOrderPopup, musicOnlySSCheck, musicPauseCheck, musicPauseField, nowPlayingLbl] {
            box.contentView?.addSubview(v)
        }
        view.addSubview(box)
        item.view = view
        return item
    }

    // MARK: - Screen Saver Tab (DIALOG/134)

    func makeScreenSaverTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "screensaver")
        item.label = "Screen Saver"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let leftBox = NSBox(frame: NSRect(x: 16, y: 16, width: 406, height: 410))
        leftBox.title = "Built-in Twinkle Bulbs Screen Saver"

        let modLbl = NSTextField(labelWithString: "Module:")
        modLbl.frame = NSRect(x: 14, y: 356, width: 70, height: 18)
        ssModulePopup.addItems(withTitles: ScreenSaverModuleID.allCases.map(\.displayName))
        ssModulePopup.frame = NSRect(x: 86, y: 352, width: 170, height: 24)
        ssModulePopup.target = self; ssModulePopup.action = #selector(ssControlChanged)

        let cfgBtn = NSButton(title: "Configure...", target: self, action: #selector(configureSSModule))
        cfgBtn.frame = NSRect(x: 266, y: 352, width: 120, height: 26)

        ssEnableCheck.frame = NSRect(x: 14, y: 318, width: 290, height: 22)
        ssEnableCheck.target = self; ssEnableCheck.action = #selector(ssControlChanged)
        ssDelayField.frame = NSRect(x: 310, y: 318, width: 48, height: 22)

        ssLightsCheck.frame = NSRect(x: 14, y: 286, width: 290, height: 22)
        ssLightsCheck.target = self; ssLightsCheck.action = #selector(ssControlChanged)
        ssLogoCheck.frame = NSRect(x: 14, y: 256, width: 290, height: 22)
        ssLogoCheck.target = self; ssLogoCheck.action = #selector(ssControlChanged)
        ssHotCornersCheck.frame = NSRect(x: 14, y: 226, width: 372, height: 22)
        ssHotCornersCheck.target = self; ssHotCornersCheck.action = #selector(ssControlChanged)

        ssEnableMsgCheck.frame = NSRect(x: 14, y: 186, width: 140, height: 22)
        ssEnableMsgCheck.target = self; ssEnableMsgCheck.action = #selector(ssControlChanged)
        ssMsgField.frame = NSRect(x: 160, y: 184, width: 226, height: 22)
        ssMsgColorWell.frame = NSRect(x: 14, y: 146, width: 54, height: 26)
        ssMsgColorWell.target = self; ssMsgColorWell.action = #selector(ssControlChanged)
        ssMsgBoldCheck.frame = NSRect(x: 80, y: 148, width: 70, height: 22)
        ssMsgBoldCheck.target = self; ssMsgBoldCheck.action = #selector(ssControlChanged)
        ssScrollMsgCheck.frame = NSRect(x: 160, y: 148, width: 150, height: 22)
        ssScrollMsgCheck.target = self; ssScrollMsgCheck.action = #selector(ssControlChanged)

        ssMouseClickCheck.frame = NSRect(x: 14, y: 100, width: 110, height: 22)
        ssMouseMoveCheck.frame = NSRect(x: 132, y: 100, width: 118, height: 22)
        ssKeyboardCheck.frame = NSRect(x: 258, y: 100, width: 132, height: 22)
        for c in [ssMouseClickCheck, ssMouseMoveCheck, ssKeyboardCheck] {
            c.target = self; c.action = #selector(ssControlChanged)
        }

        let testBtn = NSButton(title: "Test Screen Saver Full Screen", target: self, action: #selector(testScreenSaver))
        testBtn.frame = NSRect(x: 14, y: 20, width: 220, height: 30)

        for v: NSView in [modLbl, ssModulePopup, cfgBtn, ssEnableCheck, ssDelayField, ssLightsCheck, ssLogoCheck, ssHotCornersCheck, ssEnableMsgCheck, ssMsgField, ssMsgColorWell, ssMsgBoldCheck, ssScrollMsgCheck, ssMouseClickCheck, ssMouseMoveCheck, ssKeyboardCheck, testBtn] {
            leftBox.contentView?.addSubview(v)
        }
        view.addSubview(leftBox)

        let prevBox = NSBox(frame: NSRect(x: 432, y: 120, width: 264, height: 306))
        prevBox.title = "Screen Saver Live Preview"
        let mini = ScreenSaverCanvasView(frame: NSRect(x: 8, y: 14, width: 244, height: 264), settings: owner.draft, preview: true)
        ssMiniPreview = mini
        prevBox.contentView?.addSubview(mini)
        view.addSubview(prevBox)

        ssMiniTimer = Timer.scheduledTimer(withTimeInterval: 0.050, repeats: true) { [weak self] _ in
            guard let self, self.owner.window?.isVisible == true else { return }
            self.ssMiniPreview?.stepFrame()
        }

        item.view = view
        return item
    }

    // MARK: - Wallpaper Tab (DIALOG/135)

    func makeWallpaperTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "wallpaper")
        item.label = "Wallpaper"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let box = NSBox(frame: NSRect(x: 16, y: 16, width: 340, height: 410))
        box.title = "Holiday Desktop Wallpapers"

        let lbl = NSTextField(labelWithString: "Select Wallpaper:")
        lbl.frame = NSRect(x: 14, y: 356, width: 150, height: 18)
        wallpaperPopup.frame = NSRect(x: 14, y: 326, width: 308, height: 26)
        wallpaperPopup.target = self; wallpaperPopup.action = #selector(wallpaperSelectionChanged)

        let sLbl = NSTextField(labelWithString: "Placement Style:")
        sLbl.frame = NSRect(x: 14, y: 286, width: 140, height: 18)
        wpStylePopup.addItems(withTitles: WallpaperStyle.allCases.map(\.displayName))
        wpStylePopup.frame = NSRect(x: 14, y: 256, width: 180, height: 26)
        wpStylePopup.target = self; wpStylePopup.action = #selector(controlChanged)

        wpAutoRotateCheck.frame = NSRect(x: 14, y: 210, width: 230, height: 22)
        wpAutoRotateCheck.target = self; wpAutoRotateCheck.action = #selector(controlChanged)
        wpFreqField.frame = NSRect(x: 250, y: 210, width: 52, height: 22)

        let applyWpBtn = NSButton(title: "Set Desktop Wallpaper Now", target: self, action: #selector(applyWallpaperNow))
        applyWpBtn.frame = NSRect(x: 14, y: 146, width: 220, height: 30)

        let importWpBtn = NSButton(title: "Import Wallpaper Images...", target: self, action: #selector(importWallpapers))
        importWpBtn.frame = NSRect(x: 14, y: 102, width: 220, height: 28)

        for v: NSView in [lbl, wallpaperPopup, sLbl, wpStylePopup, wpAutoRotateCheck, wpFreqField, applyWpBtn, importWpBtn] {
            box.contentView?.addSubview(v)
        }
        view.addSubview(box)

        let pBox = NSBox(frame: NSRect(x: 368, y: 80, width: 326, height: 346))
        pBox.title = "Wallpaper Preview"
        wpPreviewImage.frame = NSRect(x: 10, y: 12, width: 302, height: 302)
        wpPreviewImage.imageScaling = .scaleProportionallyUpOrDown
        pBox.contentView?.addSubview(wpPreviewImage)
        view.addSubview(pBox)

        item.view = view
        return item
    }

    // MARK: - Calendar Tab (DIALOG/132)

    func makeCalendarTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "calendar")
        item.label = "Calendar"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let box = NSBox(frame: NSRect(x: 16, y: 100, width: 678, height: 320))
        box.title = "Holiday Countdown & Event Calendar"

        let lbl = NSTextField(labelWithString: "Menu Bar Holiday Countdown:")
        lbl.frame = NSRect(x: 16, y: 266, width: 200, height: 18)
        holidayPopup.addItems(withTitles: HolidayCountdownType.allCases.map(\.displayName))
        holidayPopup.frame = NSRect(x: 220, y: 262, width: 210, height: 26)
        holidayPopup.target = self; holidayPopup.action = #selector(calendarChanged)

        countdownStatusLbl.font = .boldSystemFont(ofSize: 15)
        countdownStatusLbl.frame = NSRect(x: 16, y: 218, width: 600, height: 24)

        let custLbl = NSTextField(labelWithString: "Custom Holiday Name & MM/DD:")
        custLbl.frame = NSRect(x: 16, y: 170, width: 210, height: 18)
        customNameField.frame = NSRect(x: 230, y: 168, width: 180, height: 22)
        customDateField.frame = NSRect(x: 420, y: 168, width: 70, height: 22)

        eventMsgsCheck.frame = NSRect(x: 16, y: 124, width: 420, height: 22)
        eventMsgsCheck.target = self; eventMsgsCheck.action = #selector(calendarChanged)

        let openCalBtn = NSButton(title: "Open Holiday & Events Calendar Editor...", target: self, action: #selector(openCalendarModal))
        openCalBtn.frame = NSRect(x: 16, y: 40, width: 290, height: 30)

        for v: NSView in [lbl, holidayPopup, countdownStatusLbl, custLbl, customNameField, customDateField, eventMsgsCheck, openCalBtn] {
            box.contentView?.addSubview(v)
        }
        view.addSubview(box)
        item.view = view
        return item
    }

    // MARK: - Help & Tools Tab (DIALOG/142 & 3513)

    func makeHelpAndToolsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "help")
        item.label = "Help & Import"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 710, height: 440))

        let scroll = NSScrollView(frame: NSRect(x: 16, y: 56, width: 678, height: 368))
        scroll.hasVerticalScroller = true
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false
        tv.font = .systemFont(ofSize: 12.5)
        tv.string = """
        TWINKLE BULBS 6.0 FOR MACOS — QUICK GUIDE

        • Flashing Modes (9): None, Random, All Together, Chase, Alternating, Some Bulbs Flash (~30%), Single, Pairs, and Ping-Pong.
        • Timing (Exact v6.0 Constants):
          - Fixed patterns step at 1200ms (Slow), 800ms, 500ms (Medium), 350ms, 200ms, or 80ms (Very Fast).
          - Random bulb durations range from 2000–2700ms (Slow) down to 50–120ms (Very Fast).
        • Color Modes (21): Random (no immediate neighbor repeat), 7 Solids, Multi-Color, All Colors (+ White), and classic 2/3/4-color holiday sequences.
        • Display Layer Modes:
          - On the Desktop: Sits cleanly on the desktop icon layer beneath your open apps.
          - Always On Top: Floats over workspace windows while passing mouse clicks straight through.
          - Menu Bar / Taskbar: Places the strand directly along your top Menu Bar strip.
        • Importing Original Windows Assets (.blb / .icl / .ico / .mid / .jpg):
          Click "Import .BLB/.ICO..." on the Bulbs tab (or drop files into ~/Library/Application Support/TwinkleBulbs/) to render your own classic Barefoot Productions bulb sets, MIDI music, or wallpapers natively in pure Swift!
        • Startup Modifiers: Hold Shift at launch to mute sound; hold Option at launch to reset factory defaults.
        """
        scroll.documentView = tv
        view.addSubview(scroll)

        let openSupportBtn = NSButton(title: "Open Application Support Folder", target: self, action: #selector(openAppSupportFolder))
        openSupportBtn.frame = NSRect(x: 16, y: 14, width: 230, height: 28)
        view.addSubview(openSupportBtn)

        item.view = view
        return item
    }

    // MARK: - Sync & Actions

    func loadFromSettings(_ s: AppSettings) {
        musicEnableCheck.state = s.musicEnabled ? .on : .off
        musicOrderPopup.selectItem(at: max(0, min(1, s.musicPlayMode)))
        musicOnlySSCheck.state = s.ssMusic ? .on : .off
        musicPauseCheck.state = s.enablePause ? .on : .off
        musicPauseField.integerValue = s.pauseMinutes
        refreshMusicDropdown()

        if let idx = ScreenSaverModuleID.allCases.firstIndex(of: s.ssModule) {
            ssModulePopup.selectItem(at: idx)
        }
        ssEnableCheck.state = s.ssEnable ? .on : .off
        ssDelayField.integerValue = s.ssDelayMinutes
        ssLightsCheck.state = s.ssLights ? .on : .off
        ssLogoCheck.state = s.ssLogo ? .on : .off
        ssEnableMsgCheck.state = s.ssEnableMsg ? .on : .off
        ssMsgField.stringValue = s.ssMsg
        ssMsgColorWell.color = NSColor(hex: s.ssMsgColorHex, fallback: .red)
        ssMsgBoldCheck.state = s.ssMsgBold ? .on : .off
        ssScrollMsgCheck.state = s.ssScrollMsg ? .on : .off
        ssMouseClickCheck.state = s.ssMouseClick ? .on : .off
        ssMouseMoveCheck.state = s.ssMouseMove ? .on : .off
        ssKeyboardCheck.state = s.ssKeyboard ? .on : .off
        ssHotCornersCheck.state = s.useHotCorners ? .on : .off
        ssMiniPreview?.settings = s
        ssMiniPreview?.reinitializeScene()

        refreshWallpaperDropdown(selectedID: s.activeWallpaperID)
        wpStylePopup.selectItem(at: s.wallpaperType.rawValue)
        wpAutoRotateCheck.state = s.wallpaperChangeFlag ? .on : .off
        wpFreqField.integerValue = s.wallpaperChangeFreqMinutes

        holidayPopup.selectItem(at: s.countdownHoliday.rawValue)
        eventMsgsCheck.state = s.eventMsgs ? .on : .off
        customNameField.stringValue = s.customHolidayName
        customDateField.stringValue = String(format: "%02d/%02d", s.customHolidayMonth, s.customHolidayDay)
        updateCountdownPreview()
    }

    func commitFieldsIntoDraft() {
        owner.draft.bulbChangeFreqMinutes = max(1, owner.draft.bulbChangeFreqMinutes)
        owner.draft.musicEnabled = musicEnableCheck.state == .on
        owner.draft.musicPlayMode = max(0, musicOrderPopup.indexOfSelectedItem)
        owner.draft.ssMusic = musicOnlySSCheck.state == .on
        owner.draft.enablePause = musicPauseCheck.state == .on
        owner.draft.pauseMinutes = max(1, musicPauseField.integerValue)

        let mods = ScreenSaverModuleID.allCases
        owner.draft.ssModule = mods[max(0, min(mods.count - 1, ssModulePopup.indexOfSelectedItem))]
        owner.draft.ssEnable = ssEnableCheck.state == .on
        owner.draft.ssDelayMinutes = max(1, ssDelayField.integerValue)
        owner.draft.ssLights = ssLightsCheck.state == .on
        owner.draft.ssLogo = ssLogoCheck.state == .on
        owner.draft.ssEnableMsg = ssEnableMsgCheck.state == .on
        owner.draft.ssMsg = ssMsgField.stringValue
        owner.draft.ssMsgColorHex = ssMsgColorWell.color.hexString
        owner.draft.ssMsgBold = ssMsgBoldCheck.state == .on
        owner.draft.ssScrollMsg = ssScrollMsgCheck.state == .on
        owner.draft.ssMouseClick = ssMouseClickCheck.state == .on
        owner.draft.ssMouseMove = ssMouseMoveCheck.state == .on
        owner.draft.ssKeyboard = ssKeyboardCheck.state == .on
        owner.draft.useHotCorners = ssHotCornersCheck.state == .on

        if let id = wallpaperPopup.selectedItem?.representedObject as? String {
            owner.draft.activeWallpaperID = id
        }
        owner.draft.wallpaperType = WallpaperStyle(rawValue: wpStylePopup.indexOfSelectedItem) ?? .tile
        owner.draft.wallpaperChangeFlag = wpAutoRotateCheck.state == .on
        owner.draft.wallpaperChangeFreqMinutes = max(1, wpFreqField.integerValue)

        owner.draft.countdownHoliday = HolidayCountdownType(rawValue: holidayPopup.indexOfSelectedItem) ?? .christmas
        owner.draft.eventMsgs = eventMsgsCheck.state == .on
        owner.draft.customHolidayName = customNameField.stringValue
        let parts = customDateField.stringValue.split(separator: "/")
        if parts.count == 2 {
            owner.draft.customHolidayMonth = max(1, min(12, Int(parts[0]) ?? 12))
            owner.draft.customHolidayDay = max(1, min(31, Int(parts[1]) ?? 25))
        }
    }

    private func refreshMusicDropdown() {
        musicPopup.removeAllItems()
        for t in AudioEngineService.shared.tracks {
            musicPopup.addItem(withTitle: t.title)
        }
        let idx = min(AudioEngineService.shared.currentTrackIndex, max(0, AudioEngineService.shared.tracks.count - 1))
        if AudioEngineService.shared.tracks.count > 0 {
            musicPopup.selectItem(at: idx)
        }
        nowPlayingLbl.stringValue = "Status: \(AudioEngineService.shared.isPlaying ? "Playing \(AudioEngineService.shared.currentTrackTitle)" : "Stopped")"
    }

    private func refreshWallpaperDropdown(selectedID: String) {
        let items = WallpaperService.shared.items
        wallpaperPopup.removeAllItems()
        for item in items {
            wallpaperPopup.addItem(withTitle: item.title)
            wallpaperPopup.lastItem?.representedObject = item.id
        }
        if let idx = items.firstIndex(where: { $0.id == selectedID }) {
            wallpaperPopup.selectItem(at: idx)
        }
        updateWallpaperPreview()
    }

    private func updateWallpaperPreview() {
        let idx = wallpaperPopup.indexOfSelectedItem
        let items = WallpaperService.shared.items
        guard idx >= 0, idx < items.count else { return }
        wpPreviewImage.image = NSImage(contentsOf: items[idx].url)
    }

    private func updateCountdownPreview() {
        commitFieldsIntoDraft()
        countdownStatusLbl.stringValue = CalendarService.shared.countdownSummary(settings: owner.draft)?.headline ?? "Countdown disabled"
    }

    @objc private func controlChanged() { commitFieldsIntoDraft() }

    @objc private func ssControlChanged() {
        commitFieldsIntoDraft()
        ssMiniPreview?.settings = owner.draft
        ssMiniPreview?.reinitializeScene()
    }

    @objc private func playSelectedTrack() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.play(trackIndex: musicPopup.indexOfSelectedItem, settings: owner.draft)
        nowPlayingLbl.stringValue = "Status: Playing \(AudioEngineService.shared.currentTrackTitle)"
    }

    @objc private func stopMusic() {
        AudioEngineService.shared.stop()
        nowPlayingLbl.stringValue = "Status: Stopped"
    }

    @objc private func nextTrack() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.playNext(settings: owner.draft)
        nowPlayingLbl.stringValue = "Status: Playing \(AudioEngineService.shared.currentTrackTitle)"
    }

    @objc private func importMusicFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for u in panel.urls {
                let d = AudioEngineService.importedMusicDirectory.appendingPathComponent(u.lastPathComponent)
                try? FileManager.default.removeItem(at: d)
                try? FileManager.default.copyItem(at: u, to: d)
            }
            AudioEngineService.shared.rebuildTrackList()
            refreshMusicDropdown()
        }
    }

    @objc private func configureSSModule() {
        commitFieldsIntoDraft()
        let alert = NSAlert()
        let mod = owner.draft.ssModule
        alert.messageText = "Configure \(mod.displayName) Screen Saver"
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))
        stack.orientation = .vertical
        stack.alignment = .leading

        switch mod {
        case .blank:
            alert.informativeText = "Blank Screen renders pure black with optional perimeter twinkle bulbs and greeting message."
        case .clock:
            let bounceChk = NSButton(checkboxWithTitle: "Bounce Clock Position Around Screen", target: nil, action: nil)
            bounceChk.state = owner.draft.clockConfig.bouncePosition ? .on : .off
            let h24Chk = NSButton(checkboxWithTitle: "Use 24-Hour Clock Format", target: nil, action: nil)
            h24Chk.state = owner.draft.clockConfig.use24Hour ? .on : .off
            let secChk = NSButton(checkboxWithTitle: "Show Seconds", target: nil, action: nil)
            secChk.state = owner.draft.clockConfig.showSeconds ? .on : .off
            let dateChk = NSButton(checkboxWithTitle: "Show Date Below Time", target: nil, action: nil)
            dateChk.state = owner.draft.clockConfig.showDate ? .on : .off
            [bounceChk, h24Chk, secChk, dateChk].forEach { stack.addArrangedSubview($0) }
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.clockConfig.bouncePosition = bounceChk.state == .on
                owner.draft.clockConfig.use24Hour = h24Chk.state == .on
                owner.draft.clockConfig.showSeconds = secChk.state == .on
                owner.draft.clockConfig.showDate = dateChk.state == .on
                ssControlChanged()
            }
            return
        case .fireworks:
            let skyChk = NSButton(checkboxWithTitle: "Show Night Skyline Silhouette", target: nil, action: nil)
            skyChk.state = owner.draft.fireworksConfig.showSkyline ? .on : .off
            let sndChk = NSButton(checkboxWithTitle: "Play Burst Sound Effects", target: nil, action: nil)
            sndChk.state = owner.draft.fireworksConfig.soundEnabled ? .on : .off
            [skyChk, sndChk].forEach { stack.addArrangedSubview($0) }
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.fireworksConfig.showSkyline = skyChk.state == .on
                owner.draft.fireworksConfig.soundEnabled = sndChk.state == .on
                ssControlChanged()
            }
            return
        case .snowfall:
            let blizChk = NSButton(checkboxWithTitle: "Blizzard Intensity Mode", target: nil, action: nil)
            blizChk.state = owner.draft.snowfallConfig.blizzardMode ? .on : .off
            let windChk = NSButton(checkboxWithTitle: "Gusting Wind Sway", target: nil, action: nil)
            windChk.state = owner.draft.snowfallConfig.windEnabled ? .on : .off
            let accChk = NSButton(checkboxWithTitle: "Accumulate Snow Drifts Along Bottom", target: nil, action: nil)
            accChk.state = owner.draft.snowfallConfig.accumulateSnow ? .on : .off
            let sceneChk = NSButton(checkboxWithTitle: "Show Holiday Tree, Snowman & Santa", target: nil, action: nil)
            sceneChk.state = owner.draft.snowfallConfig.showTreeAndSnowman ? .on : .off
            [blizChk, windChk, accChk, sceneChk].forEach { stack.addArrangedSubview($0) }
            alert.accessoryView = stack
            alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                owner.draft.snowfallConfig.blizzardMode = blizChk.state == .on
                owner.draft.snowfallConfig.windEnabled = windChk.state == .on
                owner.draft.snowfallConfig.accumulateSnow = accChk.state == .on
                owner.draft.snowfallConfig.showTreeAndSnowman = sceneChk.state == .on
                owner.draft.snowfallConfig.showSanta = sceneChk.state == .on
                ssControlChanged()
            }
            return
        }
        alert.runModal()
    }

    @objc private func testScreenSaver() {
        owner.applyPressed()
        owner.onStartScreenSaverNow?()
    }

    @objc private func wallpaperSelectionChanged() {
        commitFieldsIntoDraft()
        updateWallpaperPreview()
    }

    @objc private func applyWallpaperNow() {
        commitFieldsIntoDraft()
        _ = WallpaperService.shared.applyWallpaper(id: owner.draft.activeWallpaperID, style: owner.draft.wallpaperType)
        AudioEngineService.shared.playEffect(.celebrate, enabled: owner.draft.soundFX)
    }

    @objc private func importWallpapers() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for u in panel.urls {
                let d = WallpaperService.importedWallpaperDir.appendingPathComponent(u.lastPathComponent)
                try? FileManager.default.removeItem(at: d)
                try? FileManager.default.copyItem(at: u, to: d)
            }
            WallpaperService.shared.reloadList()
            refreshWallpaperDropdown(selectedID: owner.draft.activeWallpaperID)
        }
    }

    @objc private func calendarChanged() { updateCountdownPreview() }
    @objc private func openCalendarModal() { owner.onOpenCalendarViewer?() }

    @objc private func openAppSupportFolder() {
        let dir = BulbArtworkRegistry.importedBulbsDirectory.deletingLastPathComponent()
        NSWorkspace.shared.open(dir)
    }
}
