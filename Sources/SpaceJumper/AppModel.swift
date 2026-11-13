import AppKit
import Carbon.HIToolbox
import Combine
import SpaceJumperCore

/// State behind the menu and the Settings window: the current desktop, the
/// shortcut settings and the login item. Owns the switcher and the hotkeys.
@MainActor
final class AppModel: ObservableObject {
    private enum Key {
        static let modifierPrefix = "modifierPrefix"
        static let arrowKeys = "arrowKeysEnabled"
        static let desktopKeys = "desktopKeysEnabled"
        static let swipes = "swipesEnabled"
        static let wrapsAround = "wrapsAround"
        static let spaceNumbering = "spaceNumbering"
        static let appShortcuts = "appShortcuts"
        static let appModifierPrefix = "appModifierPrefix"
        static let followsReduceMotion = "followsReduceMotion"
        static let switchesOnActivation = "switchesOnActivation"
        static let animationDuration = "animationDurationMilliseconds"
        static let menuBarFrame = "menuBarFrame"
        static let menuBarFrameShape = "menuBarFrameShape"
        static let menuBarShowsSpaceName = "menuBarShowsSpaceName"
        static let menuBarRevealsSooner = "menuBarRevealsSooner"
        static let menuBarRevealWait = "menuBarRevealWaitMilliseconds"
        /// Not in Settings: `defaults write io.alberti42.SpaceJumper
        /// menuBarHideDelayMilliseconds -int N`. Read every 5 s.
        static let menuBarHideDelay = "menuBarHideDelayMilliseconds"
        /// Set once SpaceJumper has shown macOS's Accessibility dialog by itself.
        static let accessibilityRequested = "accessibilityRequested"
    }

    /// Menu-bar text: the Space's number, or "F" on a full-screen Space when
    /// only desktops are numbered.
    @Published private(set) var menuBarTitle = "–"
    /// Mission Control's name of the current full-screen Space; nil on a desktop.
    @Published private(set) var spaceName: String?
    @Published private(set) var statusLine = ""
    /// Bindings that a switched-on macOS shortcut also uses.
    @Published private(set) var clashes: [ShortcutClash] = []
    @Published private(set) var loadError: String?
    @Published private(set) var opensAtLogin = LoginItem.isEnabled
    /// Swipes are switched on but the app lacks Accessibility permission.
    @Published private(set) var swipesNeedAccess = false
    /// The macOS settings the Settings window reports.
    @Published private(set) var macOSSettings = MacOSSettings()

    @Published var modifierPrefix: ModifierPrefix {
        didSet { UserDefaults.standard.set(modifierPrefix.rawValue, forKey: Key.modifierPrefix); registerHotKeys() }
    }
    @Published var arrowKeysEnabled: Bool {
        didSet { UserDefaults.standard.set(arrowKeysEnabled, forKey: Key.arrowKeys); registerHotKeys() }
    }
    @Published var desktopKeysEnabled: Bool {
        didSet { UserDefaults.standard.set(desktopKeysEnabled, forKey: Key.desktopKeys); registerHotKeys() }
    }
    /// Intercept trackpad swipes between Spaces and switch without animation.
    @Published var swipesEnabled: Bool {
        didSet { UserDefaults.standard.set(swipesEnabled, forKey: Key.swipes); updateGestureTap() }
    }
    /// Moving past the last Space goes to the first, and back; for the arrow
    /// keys and swipes.
    @Published var wrapsAround: Bool {
        didSet { UserDefaults.standard.set(wrapsAround, forKey: Key.wrapsAround); switcher?.wrapsAround = wrapsAround }
    }

    /// How the menu-bar number and the shortcuts 1 … 9 count Spaces.
    @Published var spaceNumbering: SpaceNumbering {
        didSet {
            UserDefaults.standard.set(spaceNumbering.rawValue, forKey: Key.spaceNumbering)
            switcher?.numbering = spaceNumbering
            refresh()
        }
    }

    /// The modifier keys of the app shortcuts.
    @Published var appModifierPrefix: ModifierPrefix {
        didSet { UserDefaults.standard.set(appModifierPrefix.rawValue, forKey: Key.appModifierPrefix); registerHotKeys() }
    }
    /// Prefix-letter shortcuts that jump to an app, in the order they were added.
    @Published var appShortcuts: [AppShortcut] {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(appShortcuts), forKey: Key.appShortcuts)
            registerHotKeys()
        }
    }

    /// Switch to a Space with a window of an app when the app is activated
    /// (⌘Tab, the Dock). Acts only while macOS's own option is off; off by
    /// default.
    @Published var switchesOnActivation: Bool {
        didSet { UserDefaults.standard.set(switchesOnActivation, forKey: Key.switchesOnActivation) }
    }

    /// How long a switch slides, in milliseconds; 0 switches at once. For the
    /// shortcuts and swipes.
    @Published var animationMilliseconds: Int {
        didSet {
            UserDefaults.standard.set(animationMilliseconds, forKey: Key.animationDuration)
            switcher?.animationDuration = Double(animationMilliseconds) / 1000
        }
    }

    /// Cross-fade instead of sliding while macOS's Reduce motion is on.
    @Published var followsReduceMotion: Bool {
        didSet {
            UserDefaults.standard.set(followsReduceMotion, forKey: Key.followsReduceMotion)
            switcher?.transition = macOSSettings.transition(followingReduceMotion: followsReduceMotion)
        }
    }

    /// The frame around the desktop number in the menu bar.
    @Published var menuBarFrame: MenuBarFrame {
        didSet { UserDefaults.standard.set(menuBarFrame.rawValue, forKey: Key.menuBarFrame) }
    }
    @Published var menuBarFrameShape: MenuBarFrameShape {
        didSet { UserDefaults.standard.set(menuBarFrameShape.rawValue, forKey: Key.menuBarFrameShape) }
    }
    /// Shows Mission Control's name of a full-screen Space next to its number.
    @Published var menuBarShowsSpaceName: Bool {
        didSet { UserDefaults.standard.set(menuBarShowsSpaceName, forKey: Key.menuBarShowsSpaceName) }
    }

    /// Show the hidden menu bar as soon as the pointer touches the top edge
    /// (`MenuBarRevealer`); off by default.
    @Published var menuBarRevealsSooner: Bool {
        didSet { UserDefaults.standard.set(menuBarRevealsSooner, forKey: Key.menuBarRevealsSooner); updateMenuBarRevealer() }
    }
    /// How long the pointer stays at the top edge before the menu bar shows, 0 … 300 ms.
    @Published var menuBarRevealWaitMilliseconds: Int {
        didSet { UserDefaults.standard.set(menuBarRevealWaitMilliseconds, forKey: Key.menuBarRevealWait); updateMenuBarRevealer() }
    }

    private let switcher: SpaceSwitcher?
    private var menuBarRevealer: MenuBarRevealer?
    private let hotKeys = HotKeyCenter()
    private let gestureTap = GestureTap()
    private var accessTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    /// The app SpaceJumper switched to after its activation. It is activated
    /// again if WindowServer makes another app frontmost during that switch.
    private var followedApp: NSRunningApplication?
    /// Tells activations that come with a Space change from the user's.
    private var spaceChanges = SpaceChangeTracker(current: [])
    /// The app that was active before the latest activation.
    private var frontApp = NSWorkspace.shared.frontmostApplication
    /// The pending restart of the Dock after its preferences changed.
    private var dockRestart: DispatchWorkItem?
    /// A Dock slider is held; its changes wait for the release.
    private var isAdjustingDock = false
    private var dockChangedWhileAdjusting = false

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Key.modifierPrefix: ModifierPrefix.default.rawValue,
                                     Key.arrowKeys: true, Key.desktopKeys: true, Key.swipes: true,
                                     Key.wrapsAround: false, Key.switchesOnActivation: false,
                                     Key.animationDuration: 0, Key.followsReduceMotion: true,
                                     Key.menuBarShowsSpaceName: false, Key.menuBarRevealsSooner: false,
                                     Key.menuBarRevealWait: 0])
        modifierPrefix = ModifierPrefix(rawValue: defaults.string(forKey: Key.modifierPrefix) ?? "") ?? .default
        arrowKeysEnabled = defaults.bool(forKey: Key.arrowKeys)
        desktopKeysEnabled = defaults.bool(forKey: Key.desktopKeys)
        swipesEnabled = defaults.bool(forKey: Key.swipes)
        wrapsAround = defaults.bool(forKey: Key.wrapsAround)
        spaceNumbering = SpaceNumbering(rawValue: defaults.string(forKey: Key.spaceNumbering) ?? "") ?? .allSpaces
        appModifierPrefix = ModifierPrefix(rawValue: defaults.string(forKey: Key.appModifierPrefix) ?? "") ?? .appDefault
        appShortcuts = defaults.data(forKey: Key.appShortcuts)
            .flatMap { try? JSONDecoder().decode([AppShortcut].self, from: $0) } ?? []
        switchesOnActivation = defaults.bool(forKey: Key.switchesOnActivation)
        animationMilliseconds = defaults.integer(forKey: Key.animationDuration)
        followsReduceMotion = defaults.bool(forKey: Key.followsReduceMotion)
        menuBarFrame = MenuBarFrame(rawValue: defaults.string(forKey: Key.menuBarFrame) ?? "") ?? .none
        menuBarFrameShape = MenuBarFrameShape(rawValue: defaults.string(forKey: Key.menuBarFrameShape) ?? "") ?? .roundedRectangle
        menuBarShowsSpaceName = defaults.bool(forKey: Key.menuBarShowsSpaceName)
        menuBarRevealsSooner = defaults.bool(forKey: Key.menuBarRevealsSooner)
        menuBarRevealWaitMilliseconds = defaults.integer(forKey: Key.menuBarRevealWait)

        do {
            switcher = try SpaceSwitcher()
            switcher?.wrapsAround = wrapsAround
            switcher?.numbering = spaceNumbering
            switcher?.animationDuration = Double(animationMilliseconds) / 1000
        } catch {
            switcher = nil
            loadError = "\(error)"
        }

        registerHotKeys()
        refresh()
        gestureTap.onSwitch = { [weak self] direction in
            guard let self, let switcher = self.switcher else { return }
            log.info("swipe \(direction.rawValue, privacy: .public)")
            switcher.move(direction)
            self.refresh()
        }
        updateGestureTap()
        refreshMacOSSettings()
        if switcher != nil { menuBarRevealer = MenuBarRevealer() }
        updateMenuBarRevealer()

        // Also posted when another tool, or the Dock, changes the Space.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            log.info("activeSpaceDidChange")
            MainActor.assumeIsolated {
                guard let self else { return }
                self.spaceChanges.spaceDidChange(to: self.windowServerCurrentSpaces(), at: Date())
                // The followed app belongs to this Space change only; it must
                // not be activated again during a later one.
                if let followed = self.followedApp {
                    DispatchQueue.main.asyncAfter(deadline: .now() + SpaceChangeTracker.grace) {
                        MainActor.assumeIsolated {
                            if self.followedApp == followed { self.followedApp = nil }
                        }
                    }
                }
                self.refresh()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.applicationDidActivate(app) }
        })
        // A letter's key depends on the keyboard layout (see KeyboardLayout).
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.registerHotKeys() }
        })
        // Reduce motion can be switched on or off in System Settings at any time.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshMacOSSettings() }
        })
        // macOS shortcuts can be switched on or off in System Settings at any time.
        spaceChanges = SpaceChangeTracker(current: windowServerCurrentSpaces())
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                // In case an announcement of a Space change was missed.
                if let self { self.spaceChanges.resynchronize(self.windowServerCurrentSpaces()) }
                self?.refreshClashes()
                self?.refreshMacOSSettings()
                self?.updateMenuBarRevealer()
            }
        }
    }

    /// Whether SpaceJumper switches when an app is activated: the setting is
    /// on and macOS's own switch is off, so that only one of them switches.
    var switchesOnActivationEffectively: Bool {
        switchesOnActivation && !macOSSettings.switchesOnActivateEffectively
    }

    /// Switches to a Space with a window of the activated app, as macOS does
    /// with its option on. A hidden app is left to the Dock: when the app is
    /// unhidden on another Space, the Dock switches by itself, with its slide,
    /// even with the option off, and its trigger (WindowServer notification
    /// 1415) can come before the activation reaches SpaceJumper (macOS 27.0.1).
    private func applicationDidActivate(_ app: NSRunningApplication?) {
        let previous = frontApp
        frontApp = app
        guard let app, app.processIdentifier != getpid(), let switcher else { return }
        let name = app.localizedName ?? "pid \(app.processIdentifier)"
        // WindowServer brings an app of the new Space to the front when the
        // Space changes (see SpaceChangeTracker). Following it could switch
        // away from the Space just reached; after a switch on activation it
        // would also take the focus from the app the user chose.
        if spaceChanges.isChanging(current: windowServerCurrentSpaces(), at: Date()) {
            if let followed = followedApp, followed != app {
                log.info("activate \(name, privacy: .public) during the Space change; activating \(followed.localizedName ?? "?", privacy: .public) again")
                followedApp = nil
                followed.activate()
            } else {
                log.info("activate \(name, privacy: .public) during the Space change; not followed")
            }
            return
        }
        followedApp = nil
        // When the active app is hidden or quits, macOS activates another
        // app and does not change the Space. The activation arrives 10–16 ms
        // before the hide or quit is announced, but the previous app already
        // reports itself hidden, or its process is gone (macOS 27.0.1).
        if let previous, previous != app,
           previous.isHidden || previous.isTerminated || kill(previous.processIdentifier, 0) != 0 {
            log.info("activate \(name, privacy: .public) after \(previous.localizedName ?? "?", privacy: .public) was hidden or quit; not followed")
            return
        }
        refreshMacOSSettings()
        guard switchesOnActivationEffectively else { return }
        if app.isHidden {
            log.info("activate \(name, privacy: .public): hidden, left to the Dock")
            return
        }
        log.info("activate \(name, privacy: .public)")
        follow(app, switcher)
    }

    /// An app shortcut: switches to the Space of the app's frontmost window,
    /// then opens the app through Launch Services, whose window is then on the
    /// current Space, so the Dock does not switch as well. Opening a running
    /// app sends it the reopen event that a click on its Dock icon sends: the
    /// app is activated and opens a window if it has none. An app that is not
    /// open is launched; a hidden app is shown and left to the Dock, as with ⌘Tab.
    private func jump(toApp bundleIdentifier: String) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                log.error("app \(bundleIdentifier, privacy: .public) not found")
                NSSound.beep()
                return
            }
            log.info("open \(bundleIdentifier, privacy: .public)")
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        guard !app.isActive else { return }
        if !app.isHidden, let switcher { follow(app, switcher) }
        guard let url = app.bundleURL else {
            log.info("activate \(bundleIdentifier, privacy: .public): no bundle URL")
            app.activate()
            return
        }
        log.info("reopen \(bundleIdentifier, privacy: .public)")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Asks for an app and adds a shortcut for it with a free letter.
    func addAppShortcut() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        AppActivation.activate()
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier,
              !appShortcuts.contains(where: { $0.bundleIdentifier == identifier })
        else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        guard let letter = AppShortcut.suggestedLetter(for: name, taken: appShortcuts) else { return }
        appShortcuts.append(AppShortcut(letter: letter, bundleIdentifier: identifier, name: name))
    }

    func removeAppShortcut(_ shortcut: AppShortcut) {
        appShortcuts.removeAll { $0.bundleIdentifier == shortcut.bundleIdentifier }
    }

    func setLetter(_ letter: Character, of shortcut: AppShortcut) {
        appShortcuts = AppShortcut.assign(letter, to: shortcut.bundleIdentifier, in: appShortcuts)
    }

    private func follow(_ app: NSRunningApplication, _ switcher: SpaceSwitcher) {
        guard switcher.followActivation(ofProcess: app.processIdentifier) != nil else { return }
        followedApp = app
        refresh()
    }

    /// The current Space of every display as WindowServer reports it, without
    /// the switcher's record of a switch in progress.
    private func windowServerCurrentSpaces() -> Set<UInt64> {
        Set(switcher?.displays().map(\.current) ?? [])
    }

    /// The shortcuts in use, as the Settings window lists them.
    var enabledBindings: [HotKeyBinding] {
        HotKeyBinding.enabled(prefix: modifierPrefix, arrowKeys: arrowKeysEnabled, desktopKeys: desktopKeysEnabled)
            + HotKeyBinding.appKeys(appModifierPrefix, appShortcuts, keyCode: KeyboardLayout.keyCode(for:))
    }

    /// What the menu shows to point to the Settings window, if anything.
    var attentionMessage: String? {
        if swipesNeedAccess { return "Swipes need Accessibility access; see Settings." }
        if !clashes.isEmpty { return "Some shortcuts conflict; see Settings." }
        if macOSSettings.switchOnActivateNeeded(spaceJumperSwitches: switchesOnActivation) == false {
            return "⌘Tab needs a macOS option turned off; see Settings."
        }
        return nil
    }

    func requestAccessibilityPermission() {
        GestureTap.requestAccessibilityPermission()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            NSLog("SpaceJumper: could not change the login item: \(error.localizedDescription)")
        }
        opensAtLogin = LoginItem.isEnabled
        if LoginItem.status == .requiresApproval { LoginItem.openSystemSettings() }
    }

    /// Reads the trackpad and Mission Control preferences again; System
    /// Settings can change them at any time.
    func refreshMacOSSettings() {
        func value(_ key: String, _ domain: String) -> CFPropertyList? {
            CFPreferencesAppSynchronize(domain as CFString)
            return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
        }
        let trackpad = "com.apple.AppleMultitouchTrackpad"
        let settings = MacOSSettings(
            threeFingerHorizontalSwipe: value("TrackpadThreeFingerHorizSwipeGesture", trackpad) as? Int,
            fourFingerHorizontalSwipe: value("TrackpadFourFingerHorizSwipeGesture", trackpad) as? Int,
            rearrangesSpaces: value("mru-spaces", "com.apple.dock") as? Bool,
            switchesOnActivate: value("AppleSpacesSwitchOnActivate", kCFPreferencesAnyApplication as String) as? Bool,
            reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            dockAutohides: DockPreferences.value("autohide") as? Bool,
            dockAutohideDelay: DockPreferences.value(DockPreferences.autohideDelay) as? Double,
            dockDigDuration: DockPreferences.value(DockPreferences.digDuration) as? Double,
            dockAnimationModifier: DockPreferences.value(DockPreferences.animationModifier) as? Double,
            menuBarHiding: MenuBarPreferences.hiding())
        switcher?.transition = settings.transition(followingReduceMotion: followsReduceMotion)
        if settings != macOSSettings {
            let hidingChanged = settings.menuBarHiding != macOSSettings.menuBarHiding
            macOSSettings = settings
            if hidingChanged { updateMenuBarRevealer() }
        }
    }

    /// macOS's "Automatically hide and show the menu bar".
    func setMenuBarHiding(_ hiding: MenuBarHiding) {
        MenuBarPreferences.setHiding(hiding)
        refreshMacOSSettings()
    }

    /// The revealer runs while its setting is on and the menu bar hides somewhere.
    private func updateMenuBarRevealer() {
        menuBarRevealer?.update(enabled: menuBarRevealsSooner && macOSSettings.menuBarHiding != .never,
                                wait: Double(menuBarRevealWaitMilliseconds) / 1000,
                                hideDelay: Self.menuBarHideDelay)
    }

    /// The hidden setting `menuBarHideDelayMilliseconds`, or `MenuBarReveal`'s default.
    private static var menuBarHideDelay: TimeInterval {
        (UserDefaults.standard.object(forKey: Key.menuBarHideDelay) as? Int)
            .map { Double(max($0, 0)) / 1000 } ?? MenuBarReveal.defaultHideDelay
    }

    func openMenuBarSettings() {
        openSystemSettings("com.apple.ControlCenter-Settings.extension")
    }

    /// Sets macOS's "When switching to an application, switch to a Space with
    /// open windows for the application" and tells WindowServer, as System
    /// Settings does: the Dock passes the preference on only when it starts
    /// (macOS 27.0.1).
    func setMacOSSwitchesOnActivate(_ on: Bool) {
        CFPreferencesSetValue("AppleSpacesSwitchOnActivate" as CFString, on as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let applied = switcher != nil && SkyLightServer.setSwitchesOnAppActivation(on)
        log.info("AppleSpacesSwitchOnActivate set to \(on, privacy: .public), WindowServer told: \(applied, privacy: .public)")
        refreshMacOSSettings()
    }

    /// Sets macOS's "Automatically rearrange Spaces based on most recent use"
    /// and restarts the Dock, as `defaults write com.apple.dock mru-spaces`
    /// followed by `killall Dock` does. Whether the Dock would follow without
    /// the restart was not tested.
    func setMacOSRearrangesSpaces(_ on: Bool) {
        CFPreferencesSetAppValue("mru-spaces" as CFString, on as CFBoolean, "com.apple.dock" as CFString)
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        log.info("mru-spaces set to \(on, privacy: .public)")
        dockDidChange()
    }

    /// "Automatically hide and show the Dock"; the Dock follows without a restart.
    func setDockAutohides(_ on: Bool) {
        DockPreferences.setAutohides(on)
        refreshMacOSSettings()
    }

    /// How long the pointer rests at the edge of a desktop before the hidden
    /// Dock appears, rounded to 10 ms; macOS's default deletes the key.
    func setDockDesktopWait(milliseconds: Double) {
        setDockWait(DockPreferences.autohideDelay, milliseconds,
                    current: macOSSettings.dockDesktopWaitMilliseconds,
                    default: MacOSSettings.defaultDockAutohideDelay)
    }

    /// How long the pointer pushes against the edge in a full-screen app
    /// before the hidden Dock appears, rounded to 10 ms; macOS's default
    /// deletes the key.
    func setDockPush(milliseconds: Double) {
        setDockWait(DockPreferences.digDuration, milliseconds,
                    current: macOSSettings.dockPushMilliseconds,
                    default: MacOSSettings.defaultDockDigDuration)
    }

    private func setDockWait(_ key: String, _ milliseconds: Double, current: Int, default seconds: Double) {
        let rounded = Int((milliseconds / 10).rounded()) * 10
        guard rounded != current else { return }
        let value = Double(rounded) / 1000
        DockPreferences.set([key: value == seconds ? nil : value])
        dockDidChange()
    }

    /// The hidden Dock's slide as a share of macOS's, rounded to 5 %; 1 deletes
    /// the key.
    func setDockAnimationShare(_ share: Double) {
        let rounded = (share * 20).rounded() / 20
        guard rounded != macOSSettings.dockAnimationShare else { return }
        DockPreferences.set([DockPreferences.animationModifier: rounded >= 1 ? nil : rounded])
        dockDidChange()
    }

    /// Deletes every key SpaceJumper writes for the hidden Dock.
    func restoreDockDefaults() {
        DockPreferences.set([DockPreferences.autohideDelay: nil, DockPreferences.digDuration: nil,
                             DockPreferences.animationModifier: nil])
        dockDidChange()
    }

    /// Called when a Dock slider is grabbed and released. While one is held,
    /// the Dock is not restarted; on release it is, if a value changed.
    func dockSliderEditing(_ editing: Bool) {
        isAdjustingDock = editing
        if !editing && dockChangedWhileAdjusting {
            dockChangedWhileAdjusting = false
            scheduleDockRestart()
        }
    }

    /// The Dock reads the keys only when it starts. It is restarted after the
    /// slider is released, or 0.5 s after the last change from the keyboard,
    /// so that moving a slider restarts it once.
    private func dockDidChange() {
        refreshMacOSSettings()
        dockRestart?.cancel()
        if isAdjustingDock {
            dockChangedWhileAdjusting = true
        } else {
            scheduleDockRestart()
        }
    }

    private func scheduleDockRestart() {
        dockRestart?.cancel()
        let restart = DispatchWorkItem { DockPreferences.restartDock() }
        dockRestart = restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: restart)
    }

    func openTrackpadSettings() {
        openSystemSettings("com.apple.Trackpad-Settings.extension")
    }

    /// Accessibility → Motion, where Reduce motion is on macOS 27.0.1 (checked:
    /// `?Motion` opens it; `?Display` opens Display, which no longer has it).
    func openReduceMotionSettings() {
        openSystemSettings("com.apple.Accessibility-Settings.extension?Motion")
    }

    func openMissionControlSettings() {
        openSystemSettings("com.apple.Desktop-Settings.extension")
    }

    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The values of Copy Diagnostics… that the model knows; the Mac's details
    /// and the recent log are added by `DiagnosticsCopier`.
    func diagnostics() -> Diagnostics {
        var d = Diagnostics()
        d.accessibilityGranted = GestureTap.hasAccessibilityPermission
        d.skyLightError = loadError
        d.swipeTapRunning = gestureTap.isRunning
        d.displays = switcher?.displays() ?? []
        d.activeDisplay = switcher?.activeDisplay()?.identifier
        let duration = animationMilliseconds == 0 ? "off"
            : "\(animationMilliseconds) ms, \(macOSSettings.transition(followingReduceMotion: followsReduceMotion) == .crossFade ? "cross-fade (Reduce motion on)" : "slide")"
        d.settings = [
            .init("Modifier keys", modifierPrefix.symbols),
            .init("Move between Spaces", arrowKeysEnabled ? "on" : "off"),
            .init("Go to a Space by number", desktopKeysEnabled ? "on" : "off"),
            .init("Numbering", spaceNumbering.title),
            .init("Trackpad swipes", swipesEnabled ? "on" : "off"),
            .init("Wrap around", wrapsAround ? "on" : "off"),
            .init("App modifier keys", appModifierPrefix.symbols),
            .init("App shortcuts", appShortcuts.isEmpty ? "none"
                  : appShortcuts.map { "\($0.letter) \($0.name)" }.joined(separator: ", ")),
            .init("Transition duration", duration),
            .init("Follow Reduce motion", followsReduceMotion ? "on" : "off"),
            .init("Switch instantly with ⌘Tab", switchesOnActivation ? "on" : "off"),
            .init("Menu-bar frame", "\(menuBarFrame.title), \(menuBarFrameShape.title)"),
            .init("Menu-bar Space name", menuBarShowsSpaceName ? "on" : "off"),
            .init("Show the menu bar sooner", menuBarRevealsSooner ? "on, wait \(menuBarRevealWaitMilliseconds) ms" : "off"),
            .init("Open at login", opensAtLogin ? "on" : "off"),
        ]
        d.macOSSettings = [
            .init("Swipe between full-screen applications", macOSSettings.swipeSetting ?? "not set"),
            .init("Reduce motion", macOSSettings.reducesMotion ? "on" : "off"),
            .init("Switch to a Space with open windows (⌘Tab)", macOSSettings.switchesOnActivateEffectively ? "on" : "off"),
            .init("Automatically rearrange Spaces", macOSSettings.rearrangesSpacesEffectively ? "on" : "off"),
            .init("Automatically hide the Dock", macOSSettings.dockAutohidesEffectively ? "on" : "off"),
            .init("Dock autohide-delay", macOSSettings.dockAutohideDelay.map { "\($0) s" } ?? "not set"),
            .init("Dock digduration-duration", macOSSettings.dockDigDuration.map { "\($0) s" } ?? "not set"),
            .init("Dock autohide-time-modifier", macOSSettings.dockAnimationModifier.map { "\($0)" } ?? "not set"),
            .init("Automatically hide the menu bar", macOSSettings.menuBarHiding.title),
        ]
        d.shortcuts = enabledBindings.map(\.name)
        d.clashes = clashes.map(\.description)
        return d
    }

    func openKeyboardShortcutsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Starts or stops the gesture tap to match the setting and the
    /// permission. Without permission it shows macOS's Accessibility dialog
    /// once, then checks every 2 s until the user grants it.
    private func updateGestureTap() {
        guard swipesEnabled, switcher != nil else {
            gestureTap.stop()
            stopWaitingForAccess()
            swipesNeedAccess = false
            return
        }
        if GestureTap.hasAccessibilityPermission, gestureTap.start() {
            stopWaitingForAccess()
            swipesNeedAccess = false
            return
        }
        swipesNeedAccess = true
        if !UserDefaults.standard.bool(forKey: Key.accessibilityRequested) {
            UserDefaults.standard.set(true, forKey: Key.accessibilityRequested)
            GestureTap.requestAccessibilityPermission()
        }
        if accessTimer == nil {
            accessTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, GestureTap.hasAccessibilityPermission else { return }
                    self.updateGestureTap()
                }
            }
        }
    }

    private func stopWaitingForAccess() {
        accessTimer?.invalidate()
        accessTimer = nil
    }

    private func registerHotKeys() {
        hotKeys.unregisterAll()
        guard let switcher else { return }
        for binding in enabledBindings {
            // A refused registration is only logged: `RegisterEventHotKey` does
            // not refuse keys another app holds, the one clash users meet.
            let status = hotKeys.register(keyCode: binding.keyCode, modifiers: binding.modifiers, action: { [weak self] in
                log.info("hotkey \(binding.name, privacy: .public)")
                switch binding.action {
                case .move(let direction): switcher.move(direction)
                case .desktop(let number): switcher.goToSpace(numbered: number)
                case .app(let bundleIdentifier): self?.jump(toApp: bundleIdentifier)
                }
                self?.refresh()
            })
            if status != noErr {
                log.error("hotkey \(binding.name, privacy: .public) not registered (error \(status))")
            }
        }
        refreshClashes()
    }

    /// Reads the current Space. Right after a switch WindowServer can still
    /// report the old one, so the switcher's own record is used.
    private func refresh() {
        refreshClashes()
        let status: SpaceStatus
        if let switcher, let display = switcher.activeDisplay() {
            status = .make(current: switcher.currentSpace(of: display), spaces: display.spaces, numbering: spaceNumbering,
                           appName: { NSRunningApplication(processIdentifier: $0)?.localizedName })
        } else {
            status = .unavailable(loadError ?? "No Spaces found.")
        }
        menuBarTitle = status.title
        spaceName = status.name
        statusLine = status.line
    }

    private func refreshClashes() {
        let found = switcher?.clashes(with: enabledBindings) ?? []
        if found != clashes { clashes = found }
    }
}
