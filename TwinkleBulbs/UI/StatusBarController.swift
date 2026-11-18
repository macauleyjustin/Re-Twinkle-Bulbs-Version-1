import Cocoa

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var lastSyncLit: Bool?

    var onOpenSettings: (() -> Void)?
    var onToggleLights: (() -> Void)?
    var onToggleMusic: (() -> Void)?
    var onTogglePauseMusic: (() -> Void)?
    var onPreviousMusic: (() -> Void)?
    var onNextMusic: (() -> Void)?
    var onStartScreenSaver: (() -> Void)?
    var onOpenCalendar: (() -> Void)?
    var onOpenAdventCalendar: (() -> Void)?
    var onOpenTips: (() -> Void)?
    var onOpenAbout: (() -> Void)?
    var onToggleQuickAccess: (() -> Void)?
    var onExitRequested: (() -> Void)?

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        updateIcon(lit: true, settings: SettingsStore.shared.settings)
        rebuildMenu(settings: SettingsStore.shared.settings)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
        button.toolTip = "Twinkle Bulbs 6.0"
    }

    func updateIcon(lit: Bool, settings: AppSettings) {
        if lastSyncLit == lit, statusItem.button?.image != nil { return }
        lastSyncLit = lit
        statusItem.button?.image = renderMenuBarIcon(lit: lit, variant: settings.trayIconIndex, lightsEnabled: settings.lightsEnabled)
    }

    func rebuildMenu(settings: AppSettings) {
        menu.removeAllItems()

        let titleItem = NSMenuItem(title: "Twinkle Bulbs 6.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        if let countdown = CalendarService.shared.countdownSummary(settings: settings) {
            let cItem = NSMenuItem(title: countdown.headline, action: #selector(menuViewCalendar), keyEquivalent: "")
            cItem.target = self
            menu.addItem(cItem)
        }
        menu.addItem(.separator())

        let toggleLights = NSMenuItem(
            title: settings.lightsEnabled ? "Turn Lights Off" : "Turn Lights On",
            action: #selector(menuToggleLights),
            keyEquivalent: "l"
        )
        toggleLights.target = self
        menu.addItem(toggleLights)

        let musicPlaying = AudioEngineService.shared.isPlaying
        let toggleMusic = NSMenuItem(
            title: musicPlaying ? "Stop Music (\(AudioEngineService.shared.currentTrackTitle))" : "Play Holiday Music",
            action: #selector(menuToggleMusic),
            keyEquivalent: "m"
        )
        toggleMusic.target = self
        menu.addItem(toggleMusic)

        if AudioEngineService.shared.isPlaying || AudioEngineService.shared.isPaused {
            let pauseItem = NSMenuItem(
                title: AudioEngineService.shared.isPaused ? "Resume Music" : "Pause Music",
                action: #selector(menuTogglePauseMusic),
                keyEquivalent: ""
            )
            pauseItem.target = self
            menu.addItem(pauseItem)
        }

        let prevSong = NSMenuItem(title: "Previous Music Track", action: #selector(menuPrevMusic), keyEquivalent: "")
        prevSong.target = self
        menu.addItem(prevSong)

        let nextSong = NSMenuItem(title: "Next Music Track", action: #selector(menuNextMusic), keyEquivalent: "n")
        nextSong.target = self
        menu.addItem(nextSong)

        let startSS = NSMenuItem(title: "Start Screen Saver Now", action: #selector(menuStartSS), keyEquivalent: "s")
        startSS.target = self
        menu.addItem(startSS)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let qaItem = NSMenuItem(title: settings.quickAccess ? "Hide Quick Access Bar" : "Show Quick Access Bar", action: #selector(menuToggleQuickAccess), keyEquivalent: "q")
        qaItem.target = self
        menu.addItem(qaItem)

        let tipItem = NSMenuItem(title: "Tip of the Day...", action: #selector(menuOpenTips), keyEquivalent: "")
        tipItem.target = self
        menu.addItem(tipItem)

        let calItem = NSMenuItem(title: "Holiday Calendar...", action: #selector(menuViewCalendar), keyEquivalent: "")
        calItem.target = self
        menu.addItem(calItem)

        let advItem = NSMenuItem(title: "Advent Calendar...", action: #selector(menuViewAdventCalendar), keyEquivalent: "")
        advItem.target = self
        menu.addItem(advItem)

        let aboutItem = NSMenuItem(title: "About Twinkle Bulbs...", action: #selector(menuOpenAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let exitItem = NSMenuItem(title: "Exit Twinkle Bulbs", action: #selector(menuExit), keyEquivalent: "")
        exitItem.target = self
        menu.addItem(exitItem)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let s = SettingsStore.shared.settings
        guard let event = NSApp.currentEvent else {
            performAction(s.trayLeftClick)
            return
        }
        let action: TrayClickAction
        switch event.type {
        case .rightMouseUp:
            action = s.trayRightClick
        case .otherMouseUp:
            action = s.trayMiddleClick
        default:
            action = event.modifierFlags.contains(.control) ? s.trayRightClick : s.trayLeftClick
        }
        performAction(action)
    }

    private func performAction(_ action: TrayClickAction) {
        let s = SettingsStore.shared.settings
        switch action {
        case .popupMenu:
            rebuildMenu(settings: s)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        case .configuration:
            onOpenSettings?()
        case .toggleMusic:
            onToggleMusic?()
        case .exitProgram:
            onExitRequested?()
        case .playNextMusic:
            onNextMusic?()
        case .startScreenSaver:
            onStartScreenSaver?()
        case .viewCalendar:
            onOpenCalendar?()
        }
    }

    @objc private func menuToggleLights() { onToggleLights?() }
    @objc private func menuToggleMusic() { onToggleMusic?() }
    @objc private func menuTogglePauseMusic() { onTogglePauseMusic?() }
    @objc private func menuPrevMusic() { onPreviousMusic?() }
    @objc private func menuNextMusic() { onNextMusic?() }
    @objc private func menuStartSS() { onStartScreenSaver?() }
    @objc private func menuOpenSettings() { onOpenSettings?() }
    @objc private func menuToggleQuickAccess() { onToggleQuickAccess?() }
    @objc private func menuOpenTips() { onOpenTips?() }
    @objc private func menuViewCalendar() { onOpenCalendar?() }
    @objc private func menuViewAdventCalendar() { onOpenAdventCalendar?() }
    @objc private func menuOpenAbout() { onOpenAbout?() }
    @objc private func menuExit() { onExitRequested?() }

    private func renderMenuBarIcon(lit: Bool, variant: Int, lightsEnabled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: true) { _ in
            NSColor(srgbRed: 0, green: 0.45, blue: 0, alpha: 1).setFill()
            NSRect(x: 6, y: 1, width: 6, height: 4).fill()

            let path = NSBezierPath()
            path.move(to: NSPoint(x: 6, y: 5))
            path.line(to: NSPoint(x: 12, y: 5))
            path.curve(to: NSPoint(x: 9, y: 16.5), controlPoint1: NSPoint(x: 15.5, y: 9), controlPoint2: NSPoint(x: 12, y: 15))
            path.curve(to: NSPoint(x: 6, y: 5), controlPoint1: NSPoint(x: 6, y: 15), controlPoint2: NSPoint(x: 2.5, y: 9))
            path.close()

            let active = lightsEnabled && lit
            let baseColors: [NSColor] = [
                NSColor(srgbRed: 1, green: 0.85, blue: 0.15, alpha: 1),
                NSColor(srgbRed: 0.95, green: 0.2, blue: 0.2, alpha: 1),
                NSColor(srgbRed: 0.2, green: 0.85, blue: 0.25, alpha: 1),
                NSColor(srgbRed: 0.25, green: 0.65, blue: 1, alpha: 1)
            ]
            let c = baseColors[abs(variant) % baseColors.count]
            (active ? c : c.blended(withFraction: 0.65, of: .black) ?? .darkGray).setFill()
            path.fill()
            NSColor.black.setStroke()
            path.lineWidth = 1.0
            path.stroke()

            if active {
                NSColor.white.withAlphaComponent(0.9).setFill()
                NSBezierPath(ovalIn: NSRect(x: 7, y: 7, width: 2.2, height: 3.5)).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }
}
