# Changelog

All notable changes to SpaceJumper are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- App shortcuts: an app with no open window (Ghostty) was activated but showed no window. SpaceJumper now opens the app through Launch Services, which sends it the same reopen event as a click on its Dock icon, so the app opens a window if it has none.

## [0.7.1] - 2026-10-31

### Fixed

- "Switch instantly with ⌘Tab": clicking an app's dialog on the current Space (Zotero's Import window) switched to the Space of the app's main window. SpaceJumper counted only normal windows (layer 0); it now also counts floating windows and dialogs (layers up to 8).

## [0.7.0] - 2026-10-29

### Added

- Settings → macOS → Menu Bar: macOS's "Automatically hide and show the menu bar" (Always, On Desktop Only, In Full Screen Only, Never), and "Show the menu bar sooner" (off by default): the hidden menu bar slides in when the pointer reaches the top edge, after "Wait before showing" (0–300 ms; macOS waits 350 ms or longer), and hides 0.2 s after the pointer leaves it. An open menu keeps it shown.
- Settings → macOS → Dock: switch macOS's "Automatically hide and show the Dock" on or off, sliders for how long the hidden Dock waits with the pointer at the edge of a desktop (macOS: 150 ms), how long the pointer has to push against the edge in a full-screen app (macOS: 250 ms; resting at the edge never shows the Dock there), and how long the Dock slides in and out (Off to macOS's default), and Restore Defaults. With both waits at Off, the Dock appears as soon as the pointer reaches the edge. The Dock restarts after a change to these settings. The README lists the keys of `com.apple.dock` they write.

### Changed

- Settings: a new macOS tab holds the Mission Control group ("Switch instantly with ⌘Tab" and the two macOS options), the Menu Bar group and the Dock group; General keeps the menu-bar number's settings (Menu Bar), Startup and Updates.
- Settings: the macOS options "When switching to an application, switch to a Space with open windows for the application" and "Automatically rearrange Spaces based on most recent use" have a switch instead of Turn On / Turn Off; changing the rearranging restarts the Dock. The buttons that open System Settings are called System Settings… instead of Change….

### Fixed

- Changing macOS's "When switching to an application, switch to a Space with open windows for the application" from SpaceJumper (the Turn On / Turn Off button up to 0.6.0) stored the new value, but macOS kept switching as before until the Dock restarted. SpaceJumper now also passes the value to WindowServer, as System Settings does.

## [0.6.0] - 2026-10-28

### Added

- Settings → General → Menu Bar → "Show the name of full-screen Spaces" (off by default): next to the number, the menu bar shows the name Mission Control shows for a full-screen Space, the app or both apps in split view. The first line of the menu names the app on a full-screen Space, whatever the setting.

### Changed

- Settings → Spaces: "Wrap around from the last Space to the first" is now in the Transition group, after Duration, with its explanation next to it.

### Removed

- The warning that another app had taken one of SpaceJumper's shortcuts (Settings → Spaces → Conflicts, the menu, Copy Diagnostics). macOS reports no error when two apps use the same keys, so the warning could not appear; Troubleshooting in the README explains what to do when an app shortcut does nothing.

### Fixed

- Settings, About, Copy Diagnostics, Check for Updates and Add App could open dimmed, as windows of an inactive app, until clicked: macOS declined SpaceJumper's activation while another app was active. SpaceJumper now takes over the activation from the frontmost app.

## [0.5.0] - 2026-10-28

### Added

- An app icon: a desktop monitor whose screen shows a jump to hyperspace, in front of a night sky with stars. It follows macOS's light, dark, clear and tinted icon styles.
- Settings → Spaces → Transition → "Cross-fade when Reduce motion is on" (on by default): turn it off to keep a short slide while Reduce motion stays on for the rest of macOS.
- App shortcuts (Settings → Apps): give an app a letter, and the modifier keys chosen there (⌃⌘ by default) with that letter switch to the Space with the app's frontmost window, full-screen or not, and bring the app forward. An app that is not open is opened. The letter follows the keyboard layout (on a German keyboard ⌃⌘Z is the key labelled Z).

### Changed

- The menu-bar number and ⌃1 … ⌃9 count every Space by its position in Mission Control, full-screen apps included, so a full-screen app shows its number instead of "F". Settings → Spaces → Numbering → Desktops only keeps the previous numbering: only desktops, as macOS's "Switch to Desktop N" shortcuts count them.
- Settings: the Shortcuts tab is now called Spaces, as the app shortcuts have their own tab, and the Transition group (Duration, Reduce motion) moved there from General.

## [0.4.0] - 2026-10-28

### Added

- With Reduce motion on (System Settings → Accessibility → Motion) and a transition duration set, the Spaces cross-fade instead of sliding, as macOS does without SpaceJumper. Settings → General shows Reduce motion below the duration, with a Change… button.
- Copy Diagnostics… in the menu: copies a plain-text report to the clipboard, for bug reports: versions, permissions, displays and Spaces, the settings of SpaceJumper and macOS, the shortcuts and their conflicts, the apps that intercept trackpad swipes or key presses, and SpaceJumper's recent activity. Nothing is sent over the Internet.
- About SpaceJumper in the menu: macOS's About panel with the version, a short description, a link to the repository and the copyright line.

### Changed

- Settings → General: the slider "Slide animation" is now "Duration", in a group headed "Transition".

## [0.3.1] - 2026-10-28

### Changed

- ⌘Tab to a hidden app on another Space is left to macOS, which switches with its own slide. When the app is shown again, the Dock starts its switch by itself, even with the macOS option off, and sometimes before SpaceJumper learns of the activation; when SpaceJumper switched too, the two could mix.
- With a slide length set, the new Space becomes current when the slide starts instead of when it ends; the menu bar changes at the start of the slide.
- After a ⌘Tab switch, SpaceJumper makes the app active again only if macOS gives the focus to another app during the Space change (until 0.1 s after macOS announces it). A second ⌘Tab right after the first is no longer undone.

### Fixed

- With "Switch instantly with ⌘Tab" on, a switch by shortcut or swipe could bounce back to the previous Space. On every Space change macOS makes an app of the new Space active, sometimes one with no window there, such as Finder; SpaceJumper took that for an activation by the user and switched to that app's Space. Activations during a Space change are no longer followed.
- With "Switch instantly with ⌘Tab" on, hiding or quitting the active app switched to the Space of the app macOS activated next. macOS stays on the current Space; so does SpaceJumper now.

## [0.3.0] - 2026-10-27

### Added

- Switch instantly with ⌘Tab (Settings → General → Mission Control, off by default): when ⌘Tab or the Dock activates an app with no window on the current Space, SpaceJumper switches to the Space of its frontmost window. It acts only while the macOS option "When switching to an application, switch to a Space with open windows for the application" is off. Settings shows that option next to the switch, with Turn Off (or Turn On, when both are off) and Change… buttons, and the menu points to Settings while the option still has to be turned off. A minimized window does not count, as in macOS. See "Switching with ⌘Tab" in the README.
- Command-line mode: `--app PID` switches to the Space of that process's windows.

## [0.2.0] - 2026-10-25

### Changed

- InstantSpaces is now called SpaceJumper, with the bundle identifier `io.alberti42.SpaceJumper`. On first launch SpaceJumper copies the InstantSpaces settings; macOS asks again for Accessibility access, and Open at Login has to be switched on again. InstantSpaces cannot update itself to SpaceJumper: install SpaceJumper by hand and delete InstantSpaces.

### Added

- Slide animation, off by default: switches slide for a duration you choose, 0 to 500 ms in 10 ms steps (Settings → General). It applies to the shortcuts and swipes; ⌃1 … ⌃9 slide straight to the desktop, and wrap-around keeps the direction of the move.
- The Settings window shows the macOS settings that affect SpaceJumper: how swiping between Spaces is set in Trackpad settings (three fingers, four fingers or off), and whether macOS rearranges Spaces based on most recent use. Change… buttons open the matching panes of System Settings.
- A frame around the desktop number in the menu bar, to tell it apart from other numbers there (Settings → General → Menu Bar): none, an outline, or a filled shape with the number cut out; as a rounded rectangle or a capsule, which is a circle around one digit.

### Fixed

- The Settings window comes to the front when opened from the menu; it could stay behind the active app.

## [0.1.1] - 2026-10-25

### Changed

- Trackpad swipes inside Mission Control switch at once too. On macOS 27 this was already the case, because SpaceJumper did not recognise Mission Control there.

### Fixed

- Trackpad swipes inside App Exposé no longer switch Spaces, as in macOS.

## [0.1.0] - 2026-10-25

### Added

- Switch Spaces without the slide animation: ⌃← and ⌃→ move one Space, ⌃1 … ⌃9 go to a desktop. All shortcuts share the same modifier keys, which can be ⌃ (the default, as in macOS's Mission Control shortcuts), ⌃⌥, ⌃⌘, ⌥⌘ or ⌃⌥⌘.
- A Settings window (⌘,) for the modifier keys, the two shortcut groups (each can be switched off), Open at Login and updates. It lists the macOS shortcuts and other apps' shortcuts that use the same keys.
- Trackpad swipes between Spaces switch instantly as well ("Switch instantly on trackpad swipes" in Settings, on by default). This needs Accessibility access, which SpaceJumper asks for on first launch; with the setting off, swipes keep macOS's animation and no access is needed.
- "Wrap around from the last Space to the first" in Settings (off by default): moving past the last Space with the arrow keys or a swipe goes to the first, and back.
- The menu bar shows the number of the current desktop.
- The menu points to Settings when a shortcut conflicts with one of macOS or another app.
- Open at Login, through a login helper registered with macOS.
- Software updates through [Sparkle](https://sparkle-project.org). SpaceJumper checks for a new version once a week; Check for Updates in the menu checks at once, and "Check for updates automatically" in Settings → General turns the weekly check on or off.

[Unreleased]: https://github.com/alberti42/SpaceJumper/compare/v0.7.1...HEAD
[0.7.1]: https://github.com/alberti42/SpaceJumper/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/alberti42/SpaceJumper/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/alberti42/SpaceJumper/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/alberti42/SpaceJumper/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/alberti42/SpaceJumper/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/alberti42/SpaceJumper/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/alberti42/SpaceJumper/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/alberti42/SpaceJumper/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/alberti42/SpaceJumper/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/alberti42/SpaceJumper/releases/tag/v0.1.0
