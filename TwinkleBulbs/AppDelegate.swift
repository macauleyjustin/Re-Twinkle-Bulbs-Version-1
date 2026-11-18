import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore.shared
    private let overlayController = OverlayWindowController()
    private let screenSaverController = ScreenSaverWindowController()
    private var statusBarController: StatusBarController?

    private lazy var prefsController = PreferencesWindowController()
    private lazy var quickAccessController = QuickAccessPanelController()
    private lazy var tipsController = TipOfTheDayWindowController()
    private lazy var aboutController = AboutWindowController()
    private lazy var calendarController = CalendarViewerController()
    private lazy var adventController = AdventCalendarWindowController()
    private var wallpaperRotationTimer: Timer?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Check startup modifier keys cleanly matching v6.0 specification
        let mods = NSEvent.modifierFlags
        if mods.contains(.option) {
            settingsStore.resetToDefaults()
        }
        var current = settingsStore.settings
        if mods.contains(.shift) {
            current.musicEnabled = false
            current.soundFX = false
        }

        // Set application menu for keyboard shortcuts (Cmd+Q / Cmd+W)
        configureApplicationMenu()

        // Initialize status bar tray icon & actions
        let status = StatusBarController()
        status.onOpenSettings = { [weak self] in self?.openSettings() }
        status.onToggleLights = { [weak self] in self?.toggleLights() }
        status.onToggleMusic = { [weak self] in self?.toggleMusic() }
        status.onTogglePauseMusic = { [weak self] in self?.togglePauseMusic() }
        status.onPreviousMusic = { [weak self] in self?.previousMusic() }
        status.onNextMusic = { [weak self] in self?.nextMusic() }
        status.onStartScreenSaver = { [weak self] in self?.startScreenSaver() }
        status.onOpenCalendar = { [weak self] in self?.openCalendar() }
        status.onOpenAdventCalendar = { [weak self] in self?.openAdventCalendar() }
        status.onOpenTips = { [weak self] in self?.openTips() }
        status.onOpenAbout = { [weak self] in self?.openAbout() }
        status.onToggleQuickAccess = { [weak self] in self?.toggleQuickAccess() }
        status.onExitRequested = { [weak self] in self?.requestExit() }
        self.statusBarController = status

        // Bind controllers
        overlayController.onTraySyncTick = { [weak self] isLit in
            guard let self else { return }
            self.statusBarController?.updateIcon(lit: isLit, settings: self.settingsStore.settings)
        }
        AudioEngineService.shared.onMIDINoteEvent = { [weak self] evt in
            self?.overlayController.handleMIDIEvent(evt)
        }

        screenSaverController.onActiveStateChanged = { [weak self] active in
            guard let self else { return }
            self.overlayController.isPausedForScreenSaver = active
            AudioEngineService.shared.syncWithSettings(self.settingsStore.settings, isScreenSaverActive: active)
        }

        prefsController.onApplySettings = { [weak self] updated in
            self?.applyAllSettings(updated)
        }
        prefsController.onStartScreenSaverNow = { [weak self] in
            self?.startScreenSaver()
        }
        prefsController.onOpenCalendarViewer = { [weak self] in
            self?.openCalendar()
        }
        prefsController.onOpenAdventCalendar = { [weak self] in
            self?.openAdventCalendar()
        }

        quickAccessController.onOpenSettings = { [weak self] in self?.openSettings() }
        quickAccessController.onStartSaver = { [weak self] in self?.startScreenSaver() }
        quickAccessController.onSettingsChanged = { [weak self] s in self?.applyAllSettings(s) }

        // Apply active configuration
        applyAllSettings(current)

        if current.splashScreen && !current.runSSOnly {
            SplashWindowController.showBriefly()
        }
        if current.showTipsOnStartup && !current.runSSOnly {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openTips()
            }
        }
        if current.startupOptions {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openSettings()
            }
        }
        if current.startupCalendar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openCalendar()
            }
        }
        if current.eventMsgs {
            let todayEvents = CalendarService.shared.matchingEvents(settings: current)
            if let first = todayEvents.first {
                AudioEngineService.shared.playEffect(.celebrate, enabled: current.soundFX)
                let alert = NSAlert()
                alert.messageText = first.title
                alert.informativeText = first.message
                alert.runModal()
            }
        }

        if ProcessInfo.processInfo.arguments.contains("--open-settings") {
            openSettings()
        }
        if ProcessInfo.processInfo.arguments.contains("--smoke-screensaver") {
            let modules = ScreenSaverModuleID.allCases
            func runNextModule(_ idx: Int) {
                guard idx < modules.count else { return }
                var s = self.settingsStore.settings
                s.ssModule = modules[idx]
                s.ssLights = true
                s.ssEnableMsg = true
                self.screenSaverController.startScreenSaver(settings: s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self else { return }
                    self.screenSaverController.stopScreenSaver()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        runNextModule(idx + 1)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                runNextModule(0)
            }
        }
    }

    func applyAllSettings(_ s: AppSettings) {
        BulbArtworkRegistry.shared.reloadAllSets(
            size: s.bulbSize.pixels,
            highlightHex: s.sysColorHighlight ? "#000080" : s.highlightColorHex
        )
        overlayController.applySettings(s)
        screenSaverController.configureMonitoring(settings: s)
        AudioEngineService.shared.syncWithSettings(s, isScreenSaverActive: screenSaverController.isActive)
        statusBarController?.updateIcon(lit: true, settings: s)
        statusBarController?.rebuildMenu(settings: s)

        if s.quickAccess {
            quickAccessController.refresh()
            quickAccessController.showWindow(nil)
        } else {
            quickAccessController.window?.orderOut(nil)
        }

        scheduleWallpaperRotationIfNeeded(s)
    }

    private func scheduleWallpaperRotationIfNeeded(_ s: AppSettings) {
        wallpaperRotationTimer?.invalidate()
        wallpaperRotationTimer = nil
        guard s.wallpaperChangeFlag, s.wallpaperChangeFreqMinutes > 0 else { return }
        wallpaperRotationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(s.wallpaperChangeFreqMinutes * 60), repeats: true) { [weak self] _ in
            guard let self else { return }
            let list = WallpaperService.shared.items
            guard !list.isEmpty else { return }
            var next = self.settingsStore.settings
            if next.wallpaperChangeOrder == 1 {
                next.activeWallpaperID = (list.randomElement() ?? list[0]).id
            } else {
                let idx = list.firstIndex(where: { $0.id == next.activeWallpaperID }) ?? 0
                next.activeWallpaperID = list[(idx + 1) % list.count].id
            }
            self.settingsStore.settings = next
            _ = WallpaperService.shared.applyWallpaper(id: next.activeWallpaperID, style: next.wallpaperType)
        }
    }

    // MARK: - User Actions

    private func openSettings() {
        prefsController.showAndReload()
    }

    private func toggleLights() {
        var s = settingsStore.settings
        s.lightsEnabled.toggle()
        settingsStore.settings = s
        AudioEngineService.shared.playEffect(.click, enabled: s.soundFX)
        applyAllSettings(s)
    }

    private func toggleMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.togglePlayStop(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func togglePauseMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.togglePause(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func previousMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.playPrevious(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func nextMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.playNext(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func startScreenSaver() {
        screenSaverController.startScreenSaver(settings: settingsStore.settings)
    }

    private func openCalendar() {
        calendarController.refresh()
        calendarController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAdventCalendar() {
        adventController.refresh()
        adventController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openTips() {
        tipsController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAbout() {
        aboutController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleQuickAccess() {
        var s = settingsStore.settings
        s.quickAccess.toggle()
        settingsStore.settings = s
        applyAllSettings(s)
    }

    private func requestExit() {
        let s = settingsStore.settings
        if s.confirmExit {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Twinkle Bulbs 6.0"
            alert.informativeText = "Exit Twinkle Bulbs?"
            alert.addButton(withTitle: "Exit")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }
        NSApp.terminate(nil)
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let sub = NSMenu()
        sub.addItem(withTitle: "About Twinkle Bulbs", action: #selector(menuAbout), keyEquivalent: "")
        sub.addItem(.separator())
        sub.addItem(withTitle: "Settings...", action: #selector(menuSettings), keyEquivalent: ",")
        sub.addItem(.separator())
        sub.addItem(withTitle: "Quit Twinkle Bulbs", action: #selector(menuQuit), keyEquivalent: "q")
        appItem.submenu = sub
        NSApp.mainMenu = mainMenu
    }

    @objc private func menuAbout() { openAbout() }
    @objc private func menuSettings() { openSettings() }
    @objc private func menuQuit() { requestExit() }
}
