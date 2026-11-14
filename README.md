<p align="center"><img src="Images/AppIcon.png" width="160" alt="SpaceJumper's icon: a desktop monitor whose screen shows a jump to lightspeed, in front of a night sky with stars"></p>

# SpaceJumper

[![notarized download](https://img.shields.io/github/actions/workflow/status/alberti42/SpaceJumper/verify-release.yml?label=notarized%20download&logo=apple)](https://github.com/alberti42/SpaceJumper/actions/workflows/verify-release.yml)
[![build](https://img.shields.io/github/actions/workflow/status/alberti42/SpaceJumper/build.yml?branch=main&label=build)](https://github.com/alberti42/SpaceJumper/actions/workflows/build.yml)
[![license](https://img.shields.io/github/license/alberti42/SpaceJumper)](LICENSE)

**A menu-bar app for macOS that sets how long the animations take when you switch Spaces and when the hidden menu bar and Dock appear, down to no animation at all. It also launches apps with keyboard shortcuts.**

Ever wished you could jump between your Mac's Spaces like a Star Wars starship
making the jump to lightspeed? SpaceJumper switches Spaces instantly, without macOS's slide. And
if you'd like to see the jump, you can set how long it takes.

**[Download SpaceJumper.zip](https://github.com/alberti42/SpaceJumper/releases/latest/download/SpaceJumper.zip)** (latest release, signed and notarized). See [Installation](#installation).

Free and open source (GPL-3.0). Requires macOS 15 Sequoia or later; runs natively on
Apple silicon and Intel Macs. Works with System Integrity Protection (SIP)
enabled, as it is on every Mac by default: you do not need to turn it off.

> [!NOTE]
> **Using an older macOS?** [Open an issue](https://github.com/alberti42/SpaceJumper/issues/new) with your macOS version and Mac model. SpaceJumper may be able to support it. The private interfaces for switching Spaces can differ between macOS versions, so you would get a preview build for your macOS; all it takes is to try it and tell what you see in the issue.

macOS has no setting to turn off the animation that plays when you switch
Spaces. "Reduce motion" replaces the slide with a cross-fade, which is still an
animation. SpaceJumper switches with no animation at all: the new Space
appears at once. If you prefer a slide, SpaceJumper draws its own, as long as
you set it.

<table>
  <tr>
    <td valign="top" width="50%"><img src="Images/Settings-General.png" width="100%" alt="SpaceJumper's Settings, General tab: the menu-bar frame and the name of full-screen Spaces, startup and updates"></td>
    <td valign="top" width="50%"><img src="Images/Settings-Spaces.png" width="100%" alt="SpaceJumper's Settings, Spaces tab: the transition with Duration, wrap-around and Reduce motion, the shortcuts with modifier keys and numbering, and trackpad swipes"></td>
  </tr>
</table>
<table>
  <tr>
    <td valign="top" width="50%"><img src="Images/Settings-Apps.png" width="100%" alt="SpaceJumper's Settings, Apps tab: the modifier keys and a list of apps with their letters: LibreWolf ⌃⌘L, Emacs ⌃⌘E, Messages ⌃⌘X, MailMate ⌃⌘M, BusyCal ⌃⌘C"></td>
    <td valign="top" width="50%"><img src="Images/Settings-macOS.png" width="100%" alt="SpaceJumper's Settings, macOS tab: Switch instantly with ⌘Tab with the two Mission Control options, the menu bar's hiding with Show the menu bar sooner and Wait before showing, and the Dock's hiding with its wait, push and slide sliders"></td>
  </tr>
</table>

---

## Table of Contents

- [Features](#features)
- [Status](#status)
- [Installation](#installation)
- [Permissions and privacy](#permissions-and-privacy)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Building from source](#building-from-source)
- [Related projects](#related-projects)
- [Credits](#credits)
- [License](#license)

---

## Features

- **Keyboard shortcuts**: the modifier keys you choose in Settings, followed by
  ← or → to move one Space, or by 1 … 9 to go to the Space with that number. The modifier
  keys are ⌃ (the default, as in macOS's own Mission Control shortcuts), ⌃⌥,
  ⌃⌘, ⌥⌘ or ⌃⌥⌘, the same for both groups. Either group can be switched off.
- **App shortcuts**: in Settings → Apps, give an app a letter; the modifier
  keys chosen there (⌃⌘ by default, set apart from the Space shortcuts') and
  that letter (⌃⌘M for MailMate, for example) switch to the Space
  with the app's frontmost window, full-screen or not, and bring the app
  forward. An app that is not open is opened.
- **Trackpad swipes** between Spaces switch instantly too (on by default; can be
  switched off in Settings). This needs Accessibility access; see
  [Permissions and privacy](#permissions-and-privacy).
- **⌘Tab** (off by default): when ⌘Tab or the Dock activates an app with no
  window on the current Space, SpaceJumper switches to the Space of its
  frontmost window, instantly or with your slide. Turn it on in Settings →
  macOS, and turn off macOS's own option below it, which would slide.
- **Menu-bar item** showing the number of the current Space. It can have a frame, to tell it apart from other numbers
  in the menu bar: an outline or a filled shape with the number cut out, as a
  rounded rectangle or a capsule. On a full-screen Space it can also show the
  name Mission Control shows: the app, or both apps in split view (off by
  default; Settings → General → Menu Bar).
- **Settings window** (Settings… in the menu, ⌘,), shown
  [above](#spacejumper). Besides the options in this list, it lists the
  macOS shortcuts that use the same keys, and
  shows the macOS settings that affect SpaceJumper: how swiping between Spaces
  is set in Trackpad settings, whether macOS switches Spaces when an app is
  activated, whether macOS rearranges Spaces by recent use, and whether the
  Dock hides. The last three have a switch; System Settings… opens the pane
  where macOS shows a setting.
- **Numbering**, for the menu bar and ⌃1 … ⌃9, chosen in Settings →
  Shortcuts. Every Space (the default): each Space by its position in Mission
  Control, full-screen apps included. Desktops only: only desktops, as Mission
  Control names them ("Desktop 1", "Desktop 2", …) and macOS's "Switch to
  Desktop N" shortcuts count them; the menu bar shows "F" on a full-screen
  Space. ⌃← and ⌃→ include full-screen Spaces and stop at the first and last
  Space, as macOS does without SpaceJumper.
- **Transition** (off by default): a slide of the duration you choose, 0 to
  500 ms in 10 ms steps, for the shortcuts, swipes and ⌘Tab. SpaceJumper draws
  it itself, so ⌃1 … ⌃9 slide straight to the Space. With Reduce motion on
  (System Settings → Accessibility → Motion), the Spaces cross-fade instead,
  as macOS does without SpaceJumper; to keep the slide while Reduce motion
  stays on for the rest of macOS, turn off "Cross-fade when Reduce motion is
  on" in Settings → Spaces.
- **Wrap around** (off by default): ⌃← ⌃→ and trackpad swipes go from the last
  Space to the first and back.
- **Hidden menu bar** (Settings → macOS → Menu Bar): choose macOS's
  "Automatically hide and show the menu bar", and, with "Show the menu bar
  sooner" (off by default), the hidden menu bar slides in when the pointer
  reaches the top edge instead of after macOS's wait (350 ms or longer). See
  [The hidden menu bar](#the-hidden-menu-bar).
- **Hidden Dock** (Settings → macOS → Dock): switch macOS's "Automatically
  hide and show the Dock" on or off, and set how long the hidden Dock waits
  on desktops, how long the pointer pushes in full-screen apps (0 for both
  makes it appear as soon as the pointer reaches the edge), and how long it
  slides. Restore Defaults removes these settings. See
  [The hidden Dock](#the-hidden-dock).
- **Several displays**: the shortcuts act on the display with the active menu bar.
- **Open at login**, through a login helper registered with macOS.
- **Updates** through [Sparkle](https://sparkle-project.org): SpaceJumper
  checks for a new version once a week, or when you choose Check for Updates in
  its menu.
- **Works with System Integrity Protection (SIP) enabled**, as it is on every
  Mac by default: you do not need to turn it off. SpaceJumper loads no code
  into other processes.

## Status

SpaceJumper relies on private macOS interfaces (see
[How it works](#how-it-works)), which Apple can change in any update.

Tested on macOS 27.0.1; also reported working on macOS 15 Sequoia.

Not yet tested:

- macOS 26. If you find a problem, please open an
  [issue](https://github.com/alberti42/SpaceJumper/issues).
- More than one display.

## Installation

1. Download [`SpaceJumper.zip`](https://github.com/alberti42/SpaceJumper/releases/latest/download/SpaceJumper.zip)
   from the [latest release](https://github.com/alberti42/SpaceJumper/releases/latest).
2. Unzip it and move `SpaceJumper.app` to the Applications folder.
3. Open it. The number of the current Space appears in the menu bar.
4. macOS asks whether SpaceJumper may use Accessibility. Allow it for instant
   trackpad swipes (System Settings → Privacy & Security → Accessibility); the
   keyboard shortcuts work without it. See
   [Permissions and privacy](#permissions-and-privacy).
5. If macOS's own shortcuts use the same keys, Settings → Spaces lists them
   under Conflicts, with a button that opens Keyboard Shortcuts, where you
   turn them off.
6. To start SpaceJumper when you log in, turn on Open at Login in its Settings.

The app is signed with a Developer ID and notarized by Apple. To check where a
downloaded ZIP was built:

```sh
gh attestation verify SpaceJumper.zip --repo alberti42/SpaceJumper
```

To report a security problem privately, see [SECURITY.md](SECURITY.md).

## Permissions and privacy

- The keyboard shortcuts need no permission: they are registered with
  `RegisterEventHotKey`, which does not require Accessibility access.
- Instant trackpad swipes need Accessibility access. SpaceJumper reads the
  trackpad's swipe events before the Dock does, drops them and switches
  instead; macOS allows that only to apps with Accessibility access. On first
  launch SpaceJumper asks for it; Settings shows whether it has it. Without
  it, or with "Switch instantly on trackpad swipes" off, swipes keep macOS's
  animation. SpaceJumper only looks at the trackpad's Dock swipe events and,
  when a swipe begins, at the Dock's accessibility elements to tell whether
  App Exposé is open. It does not read the keyboard.
- The switch on ⌘Tab needs no permission. SpaceJumper reads the window list
  for window numbers and owners only (not titles or contents, which would
  need Screen Recording access) and asks WindowServer which Space each window
  is on. The switches for macOS settings in Settings → macOS change the
  macOS preferences `AppleSpacesSwitchOnActivate` and `mru-spaces` and the
  Dock's keys (see [The hidden Dock](#the-hidden-dock)); SpaceJumper changes
  them only when you use one of them.
- SpaceJumper connects to the network only for updates: it downloads the
  update feed (`Releases/appcast.xml` in this repository) from GitHub, and, when
  you install an update, `SpaceJumper.zip` from GitHub Releases. Sparkle sends
  no system profile; the requests carry the names and versions of SpaceJumper
  and Sparkle in the User-Agent header. Turn off "Check for updates
  automatically" in Settings → General to check only when you choose Check for
  Updates.
- SpaceJumper collects no data.
- Its settings (modifier keys, shortcut groups, swipes, wrapping, ⌘Tab) are stored in
  `~/Library/Preferences/io.alberti42.SpaceJumper.plist`.

## Troubleshooting

When something does not work as expected, choose **Copy Diagnostics…** in
SpaceJumper's menu. SpaceJumper copies a report to your clipboard: versions,
permissions, your displays and Spaces, the settings of SpaceJumper and macOS,
the apps that intercept swipes or key presses, and SpaceJumper's recent
activity. Nothing is sent over the Internet: it is plain text you can read
and edit. The report may show the cause, for example a missing permission or
another app that takes the swipes away; if not, paste it into an
[issue](https://github.com/alberti42/SpaceJumper/issues) and say what you did.

Common cases:

- **Swipes switch with macOS's animation.** SpaceJumper lacks Accessibility
  access, or "Switch instantly on trackpad swipes" is off. Settings →
  Shortcuts shows both.
- **Swipes do nothing.** Check how many fingers macOS uses: Settings →
  Shortcuts shows "Swipe set in macOS" (Trackpad → More Gestures → Swipe
  between full-screen applications). Choosing Dragging style Three Finger Drag
  in Accessibility → Pointer Control → Trackpad Options moves this swipe to
  four fingers.
- **A swipe at the first or last desktop does nothing.** There is no Space
  in that direction. Turn on "Wrap around from the last Space to the first"
  to go to the other end.
- **A shortcut switches with the animation, or twice.** A macOS shortcut on the
  same keys is still on. Settings → Spaces lists it under Conflicts, with a
  button to Keyboard Shortcuts. Or choose other modifier keys.
- **An app shortcut does nothing.** Another app uses the same keys as a global
  shortcut. macOS lets two apps register the same keys without an error and
  gives the key press to only one of them, so SpaceJumper cannot show this
  under Conflicts. Choose another letter in Settings → Apps, or change the
  other app's shortcut.
- **⌘Tab to an app on another Space still slides.** The macOS option "When
  switching to an application, switch to a Space with open windows for the
  application" is on, or "Switch instantly with ⌘Tab" is off. Settings →
  macOS shows both.
- **⌘Tab to a hidden app on another Space slides.** This is macOS's own
  switch. When ⌘Tab shows a hidden app (⌘H) again on another Space, macOS
  switches there with its own slide, even with its option "When switching to
  an application, switch to a Space with open windows for the application"
  off. This is inconsistent in macOS: it ignores the option you turned off for
  hidden apps, and only Apple can fix it. macOS can start this switch before
  SpaceJumper learns that the app was activated; if SpaceJumper switched too,
  the two switches would compete. SpaceJumper therefore leaves hidden apps to
  macOS. The cost is small: a hidden app on another Space is rare, and for it
  you get macOS's usual slide; everything else works as before.
- **⌘Tab no longer changes the Space.** SpaceJumper's "Switch instantly with
  ⌘Tab" and macOS's own option "When switching to an application, switch to a
  Space with open windows for the application" are both off, so neither
  switches. Turn one of them on in Settings → macOS: SpaceJumper's for an
  instant switch, or macOS's (the switch below it) for macOS's slide.
- **Desktops show no name in the menu bar.** macOS gives desktops no names:
  Mission Control calls them "Desktop 1", "Desktop 2", …, and with Numbering
  set to Every Space that name can differ from the number in the menu bar
  (Desktop 2 is Space 3 when a full-screen app comes before it). SpaceJumper
  therefore shows the name of full-screen Spaces only. Naming desktops
  yourself, in Mission Control too, takes code loaded into the Dock, which
  requires System Integrity Protection (SIP) to be disabled. SpaceJumper is
  made to work with SIP enabled and loads no code into other processes. If
  you accept disabling SIP,
  [spaces-renamer](https://github.com/dado3212/spaces-renamer) names your
  Spaces.
- **Space numbers change by themselves.** macOS's "Automatically rearrange
  Spaces based on most recent use" is on. Turn it off in Settings → macOS, or in
  Desktop & Dock → Mission Control, to keep the order you set.
- **Mission Control flickers and shows dark frames when a top hot corner opens
  it.** This is macOS's own behaviour. In Mission Control, the bar of Spaces at
  the top expands into thumbnails of every Space when the pointer is near the
  top, and macOS draws all of them at once. A top corner leaves the pointer
  there, so the bar expands right after Mission Control opens. F3, a swipe or a
  bottom corner leave the pointer lower, and the bar keeps showing names only.
  Use a bottom corner (Desktop & Dock → Hot Corners). The Dock reads
  `spacesbar-delay` (0.1 s when not set), `spacesbar-distance` (64) and
  `spacesbar-angle`, which seem to set when the bar expands; changing them is
  untested.

For a detailed log to attach to an issue, run

```sh
/usr/bin/log stream --level debug --predicate 'subsystem == "io.alberti42.SpaceJumper"'
```

in Terminal, repeat the problem, and attach the output.

## How it works

### Keyboard shortcuts

The animation is drawn by the Dock: the macOS process that shows the Dock at
the edge of the screen also manages Spaces, Mission Control and the slide
between Spaces. When you switch Spaces, the Dock shows both Spaces, slides them
across the screen, and then tells WindowServer, the macOS process that puts
all windows on screen, to make the new Space current. WindowServer makes that
change at once.

SpaceJumper sends WindowServer the same three requests the Dock sends,
without the slide: show the new Space, make it current, hide the other Spaces.
It uses SkyLight's bridged window-management operations
(`SLSBridgedShowSpacesOperation`, `SLSBridgedManagedDisplaySetCurrentSpaceOperation`,
`SLSBridgedHideSpacesOperation`). SkyLight is the private framework through
which apps and the Dock talk to WindowServer.

The plain SkyLight functions are not enough. Called from an app other than the
Dock, `SLSManagedDisplaySetCurrentSpace` changes the Space, but
`SLSShowSpaces` and `SLSHideSpaces` are refused, so the windows of both Spaces
stay on screen. The bridged operations are accepted.

With a transition duration set, SpaceJumper draws the slide itself, as the
Dock does: it shows the new Space shifted one screen width to the side, moves
both Spaces across the screen about 120 times a second
(`SLSBridgedSpaceSetTransformOperation`), and then sends the same three
requests and puts both Spaces back in place.

With Reduce motion on, SpaceJumper asks WindowServer to freeze the screen
(`SLSNewTransition`, a fade), switches at once underneath, and lets
WindowServer dissolve the frozen picture into the new Space
(`SLSInvokeTransition`). The whole picture fades, so the windows keep their
order throughout.

### Trackpad swipes

A swipe between Spaces reaches the Dock as a series of "Dock swipe" events:
began, changed (with the distance moved), ended. SpaceJumper watches them
with an event tap placed before the Dock. It drops the began event, so the
Dock never starts its slide; at the first changed event that moved, it
switches one Space in that direction, as the keyboard shortcuts do. From macOS
27 on, the ended event is passed on with its motion set to zero, because the
Dock needs it to finish the gesture. Swipes inside Mission Control are
intercepted in the same way. Swipes inside App Exposé are left to the Dock,
which does not switch Spaces there; SpaceJumper recognises App Exposé from
the Dock's accessibility elements when a swipe begins.

### ⌘Tab

With the macOS option "When switching to an application, switch to a Space
with open windows for the application" on, an app that ⌘Tab activates brings
its windows forward, even on another Space. WindowServer tells the Dock that a
window appeared on a Space you are not on, and the Dock slides there. With the
option off, macOS honors your choice: the app becomes active, but no window
comes forward on another Space, and the Dock does not switch.

SpaceJumper takes over from there. macOS tells every app when another app
becomes active. SpaceJumper then lists that app's windows, front to back, asks
WindowServer which Space each one is on (`SLSCopySpacesForWindows`) and whether
it is shown (window attributes from SkyLight's window iterator), and switches
to the Space of the frontmost shown window. A minimized window is not shown,
so an app whose windows are all minimized leaves the Space as it is, as macOS
does without SpaceJumper.

SpaceJumper does not handle ⌘Tab to a hidden app (⌘H) on another Space, by
design: macOS switches there with its own slide.
[Troubleshooting](#troubleshooting) explains why.

### The hidden menu bar

macOS shows a hidden menu bar after the pointer has rested at the top edge;
the wait measured 347–1181 ms on macOS 27.0.1. No setting changes it. With
"Show the menu bar sooner" on, SpaceJumper samples the pointer 60 times a
second and, when it reaches the top edge (after "Wait before showing", 0 by
default), asks WindowServer to show the menu bar on that display
(`SLSSetMenuBarVisibilityOverrideOnDisplay`). The menu bar then slides in as
it does for macOS, for 0.15 s; only macOS can change that.

SpaceJumper gives the menu bar back to macOS in one of two ways:

- When macOS shows the menu bar itself, which it announces to every app,
  SpaceJumper lets go at once. Nothing changes on screen, and macOS hides
  the menu bar later, as usual.
- Otherwise, when the pointer has been below the menu bar for 0.2 s, the menu
  bar hides. An open menu keeps it shown, as macOS does.

The 0.2 s has no control in Settings. To try another value (in
milliseconds; SpaceJumper reads it within 5 s):

```sh
defaults write io.alberti42.SpaceJumper menuBarHideDelayMilliseconds -int 300
defaults delete io.alberti42.SpaceJumper menuBarHideDelayMilliseconds   # back to 200
```

A value close to 0 can make the menu bar hide and show again, when macOS's
own wait was still counting.

"Automatically hide and show the menu bar" is the setting in System Settings
→ Menu Bar. SpaceJumper changes it as System Settings does:
`com.apple.controlcenter AutoHideMenuBarOption` for the choice, the global
`_HIHideMenuBar` and `CGSSetMenuBarAutohideEnabled` for desktops, and the
global `AppleMenuBarVisibleInFullscreen` for full-screen apps.

### The hidden Dock

With "Automatically hide and show the Dock" on, the Dock waits before it
appears, and it waits differently on a desktop and in a full-screen app:

- On a desktop, it appears after the pointer has rested at the edge for
  `autohide-delay` seconds (0.15 s when the key is not set).
- In a full-screen app, `autohide-delay` has no effect. The pointer must keep
  pushing against the edge for `digduration-duration` seconds (0.25 s when
  the key is not set). A pause of more than 0.1 s, or a push that drifts
  sideways, starts the count again, and a pointer resting at the edge never
  shows the Dock.

The Dock then slides in, for a time multiplied by `autohide-time-modifier`
(1 when the key is not set; 0 shows the Dock without the slide).

These are keys of `com.apple.dock` that System Settings does not show.
SpaceJumper changes them in Settings → macOS → Dock:

| Setting in SpaceJumper | Keys it writes |
|---|---|
| Wait on desktops | `autohide-delay`, in seconds; macOS's 150 ms deletes it |
| Push in full-screen apps | `digduration-duration`, in seconds; macOS's 250 ms deletes it |
| Slide duration | `autohide-time-modifier`, the share shown (0 for Off); 100 % deletes it |
| Restore Defaults | deletes all three |

The Dock reads these keys only when it starts, so SpaceJumper restarts it
after a change, as `killall Dock` does. "Automatically hide and show the Dock"
itself is the setting in System Settings → Desktop & Dock; SpaceJumper changes
it through the same call as System Settings, and the Dock follows without a
restart.

To do the same in Terminal, or to undo it without SpaceJumper:

```sh
# No wait on desktops and no push in full-screen apps
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock digduration-duration -float 0
# No slide
defaults write com.apple.dock autohide-time-modifier -float 0
killall Dock

# Undo
defaults delete com.apple.dock autohide-delay
defaults delete com.apple.dock digduration-duration
defaults delete com.apple.dock autohide-time-modifier
killall Dock
```

## Building from source

Requires the Swift 6.2 toolchain or later (Xcode or the Command Line Tools).
No Xcode project is involved.

```sh
make app     # build/SpaceJumper.app, signed ad hoc
make run     # build and open it
make test    # run the tests
```

Open the app from the Finder or with `open build/SpaceJumper.app`. Started
from a shell as `Contents/MacOS/SpaceJumper`, macOS attributes its
Accessibility request to the shell. macOS also ties the Accessibility
permission to the app's signature: an app signed ad hoc gets a new signature
with every build, so the permission has to be granted again after each build.
A build signed with a Developer ID keeps it.

`ARCHS=universal make app` builds for Apple silicon and Intel; the default is
this Mac's architecture. To sign with a Developer ID, set `SIGN_IDENTITY`:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
```

To use your own signing identity, also change the bundle identifiers
`io.alberti42.SpaceJumper` and `io.alberti42.SpaceJumper.LoginHelper` in
`Resources/Info.plist`, `Resources/LoginHelper-Info.plist`,
`Sources/LoginHelper/main.swift` and `Sources/SpaceJumper/LoginItem.swift`.
To publish your own updates, set `SUFeedURL` (your appcast) and
`SUPublicEDKey` (your EdDSA public key) in `Resources/Info.plist`; otherwise
your build offers the updates published in this repository.

The executable also takes commands, which switch once and exit:

```sh
build/SpaceJumper.app/Contents/MacOS/SpaceJumper --list            # displays and Spaces
build/SpaceJumper.app/Contents/MacOS/SpaceJumper --move right
build/SpaceJumper.app/Contents/MacOS/SpaceJumper --desktop 2
```

## Related projects

- [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) skips
  the animation by sending the Dock a trackpad swipe with a very high velocity,
  so the Dock still makes the switch. SpaceJumper creates no events of its own:
  it switches through WindowServer itself (see [How it works](#how-it-works)),
  and it adds its own slide, the menu-bar number, ⌃1 … ⌃9 and wrap-around.
- [yabai](https://github.com/asmvik/yabai) is a tiling window manager that
  also moves windows between Spaces and switches Spaces, partly through code it
  loads into the Dock, which requires System Integrity Protection to be partly
  disabled. SpaceJumper manages no windows and loads no code into the Dock; it
  only switches Spaces.
- [SpaceHopper](https://github.com/Mor-Li/SpaceHopper) switches desktops through
  yabai, or in its "lite" version through macOS's own "Switch to Desktop N"
  shortcuts, which keep macOS's animation.

## Credits

- [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) by
  jurplel: its findings on the Dock's swipe events, namely the event fields and
  the handling of the ended event on macOS 27. SpaceJumper intercepts trackpad
  swipes with them.
- [yabai](https://github.com/asmvik/yabai) by asmvik: how to look up SkyLight's
  private perform function for the bridged operations
  ([#2788](https://github.com/asmvik/yabai/issues/2788)).

The app was created with AI assistance (Claude).

## License

[GNU General Public License v3.0](LICENSE)
