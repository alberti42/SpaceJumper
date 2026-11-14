import SpaceJumperCore
import SwiftUI

/// The Settings window, opened from the menu with Settings… (⌘,).
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralPane(model: model) }
            Tab("Spaces", systemImage: "rectangle.split.3x1") { SpacesPane(model: model) }
            Tab("Apps", systemImage: "square.grid.2x2") { AppsPane(model: model) }
            Tab("macOS", systemImage: "macwindow") { MacOSPane(model: model) }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refreshMacOSSettings() }
    }
}

// MARK: Spaces

private struct SpacesPane: View {
    @ObservedObject var model: AppModel

    private var prefix: String { model.modifierPrefix.symbols }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        // No `step`: it draws a tick per step. The value is rounded
                        // to 10 ms instead.
                        Slider(value: Binding(
                            get: { Double(model.animationMilliseconds) },
                            set: { model.animationMilliseconds = Int(($0 / 10).rounded()) * 10 }),
                               in: 0...500)
                            .frame(width: 160)
                        Text(model.animationMilliseconds == 0 ? "Off" : "\(model.animationMilliseconds) ms")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                } label: {
                    Text("Duration")
                    Text("How long a switch takes, for the shortcuts, swipes and ⌘Tab. Off switches at once.")
                }
                Toggle(isOn: $model.wrapsAround) {
                    Text("Wrap around from the last Space to the first")
                    Text("For \(prefix)← \(prefix)→ and trackpad swipes. macOS stops at the first and last Space.")
                }
                Toggle(isOn: $model.followsReduceMotion) {
                    Text("Cross-fade when Reduce motion is on")
                    Text("Turn it off to keep the slide while Reduce motion stays on for the rest of macOS.")
                }
                LabeledContent {
                    HStack {
                        Text(model.macOSSettings.reducesMotion ? "On" : "Off")
                        Button("System Settings…") { model.openReduceMotionSettings() }
                    }
                } label: {
                    Label {
                        Text("Reduce motion")
                        Text(model.macOSSettings.reduceMotionExplanation(followingReduceMotion: model.followsReduceMotion))
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            } header: {
                Text("Transition")
            }

            Section {
                Picker("Modifier keys", selection: $model.modifierPrefix) {
                    ForEach(ModifierPrefix.allCases, id: \.self) { prefix in
                        Text(prefix.symbols).tag(prefix)
                    }
                }
                Toggle(isOn: $model.arrowKeysEnabled) {
                    Text("Move between Spaces")
                    Text("\(prefix)←  \(prefix)→")
                }
                Toggle(isOn: $model.desktopKeysEnabled) {
                    Text("Go to a Space by number")
                    Text("\(prefix)1 … \(prefix)9")
                }
                Picker(selection: $model.spaceNumbering) {
                    ForEach(SpaceNumbering.allCases, id: \.self) { numbering in
                        Text(numbering.title).tag(numbering)
                    }
                } label: {
                    Text("Numbering")
                    Text(model.spaceNumbering == .allSpaces
                         ? "Every Space by its position in Mission Control, full-screen apps included. The menu bar shows the same number."
                         : "Only desktops, as macOS's \"Switch to Desktop N\" shortcuts count them. The menu bar shows F on a full-screen Space.")
                }
            } header: {
                Text("Shortcuts")
            }

            Section {
                Toggle(isOn: $model.swipesEnabled) {
                    Text("Switch instantly on trackpad swipes")
                    Text("Swiping left or right between Spaces")
                }
                LabeledContent {
                    HStack {
                        if let setting = model.macOSSettings.swipeSetting {
                            Text(setting)
                        }
                        Button("System Settings…") { model.openTrackpadSettings() }
                    }
                } label: {
                    Text("Swipe set in macOS")
                    Text("SpaceJumper reacts to the swipe macOS uses between Spaces: Trackpad → More Gestures → Swipe between full-screen applications.")
                }
                if model.swipesNeedAccess {
                    Label("SpaceJumper needs Accessibility access to intercept swipes.", systemImage: "exclamationmark.triangle")
                    HStack {
                        Button("Open Accessibility Settings…") { model.openAccessibilitySettings() }
                        Button("Ask Again") { model.requestAccessibilityPermission() }
                    }
                }
            } header: {
                Text("Trackpad")
            } footer: {
                Text("Turn it off to keep macOS's swipe with its animation; SpaceJumper then needs no Accessibility access.")
                    .foregroundStyle(.secondary)
                    .formFooter()
            }

            if !model.clashes.isEmpty {
                Section {
                    ForEach(model.clashes, id: \.description) { clash in
                        Label(clash.description, systemImage: "exclamationmark.triangle")
                    }
                    LabeledContent {
                        Button("Open Keyboard Shortcuts…") { model.openKeyboardShortcutsSettings() }
                    } label: {
                        Text("Turn the macOS shortcut off")
                        Text("When macOS uses the same keys, both macOS and SpaceJumper react. Turn the macOS shortcut off in System Settings → Keyboard → Keyboard Shortcuts, or choose other modifier keys.")
                    }
                } header: {
                    Text("Conflicts")
                }
            }
        }
        .formStyle(.grouped)
        // The window grows to fit the pane instead of scrolling it.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Apps

private struct AppsPane: View {
    @ObservedObject var model: AppModel

    private var prefix: String { model.appModifierPrefix.symbols }

    var body: some View {
        Form {
            Section {
                Picker("Modifier keys", selection: $model.appModifierPrefix) {
                    ForEach(ModifierPrefix.allCases, id: \.self) { prefix in
                        Text(prefix.symbols).tag(prefix)
                    }
                }
            }
            Section {
                ForEach(model.appShortcuts) { shortcut in
                    LabeledContent {
                        HStack {
                            // The menu items are the bare letters, so that typing a
                            // letter selects it; with the prefix in every title,
                            // type-to-select matched nothing.
                            Text(prefix)
                            Picker("Letter", selection: Binding(
                                get: { shortcut.letter },
                                set: { model.setLetter($0, of: shortcut) })) {
                                ForEach(AppShortcut.letters, id: \.self) { letter in
                                    Text(String(letter)).tag(letter)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                            Button {
                                model.removeAppShortcut(shortcut)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove the shortcut for \(shortcut.name)")
                        }
                    } label: {
                        Label {
                            Text(shortcut.name)
                        } icon: {
                            Image(nsImage: AppIcon.of(shortcut.bundleIdentifier))
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Add App…") { model.addAppShortcut() }
                        .disabled(model.appShortcuts.count == AppShortcut.letters.count)
                }
            } header: {
                Text("Jump to an app")
            } footer: {
                Text("\(prefix) and the letter switch to the Space with the app's frontmost window, full-screen or not, and bring the app forward. An app that is not open is opened.")
                    .foregroundStyle(.secondary)
                    .formFooter()
            }
            if model.appModifierPrefix == .control && !model.appShortcuts.isEmpty {
                Label("With ⌃ alone, these shortcuts take keys that text fields use, such as ⌃A and ⌃E (start and end of line). Choose other modifier keys above.",
                      systemImage: "exclamationmark.triangle")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The icon of an installed app, 16 points; a generic app icon when it is not found.
private enum AppIcon {
    static func of(_ bundleIdentifier: String) -> NSImage {
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

// MARK: macOS settings

/// A macOS setting that SpaceJumper changes: a switch, and a button to the
/// System Settings pane where macOS shows it. The icon is a warning while the
/// setting works against one of SpaceJumper's.
private struct MacOSSettingRow<Control: View>: View {
    let title: String
    let explanation: String
    var warns = false
    let open: () -> Void
    @ViewBuilder let control: Control

    var body: some View {
        LabeledContent {
            HStack {
                control
                Button("System Settings…", action: open)
            }
        } label: {
            Label {
                Text(title)
                Text(explanation)
            } icon: {
                Image(systemName: warns ? "exclamationmark.triangle" : "info.circle")
            }
        }
    }
}

extension MacOSSettingRow where Control == AnyView {
    /// A row with a switch.
    init(title: String, explanation: String, warns: Bool = false, isOn: Binding<Bool>, open: @escaping () -> Void) {
        self.init(title: title, explanation: explanation, warns: warns, open: open) {
            AnyView(Toggle(title, isOn: isOn).toggleStyle(.switch).labelsHidden())
        }
    }
}

// MARK: Menu bar

/// macOS's "Automatically hide and show the menu bar", and SpaceJumper's
/// sooner reveal (`MenuBarRevealer`).
private struct MenuBarSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Section {
            MacOSSettingRow(title: "Automatically hide and show the menu bar",
                            explanation: "The macOS setting in Menu Bar.",
                            open: model.openMenuBarSettings) {
                Picker("Automatically hide and show the menu bar", selection: Binding(
                    get: { model.macOSSettings.menuBarHiding },
                    set: { model.setMenuBarHiding($0) })) {
                    ForEach(MenuBarHiding.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            if model.macOSSettings.menuBarHiding != .never {
                Toggle(isOn: $model.menuBarRevealsSooner) {
                    Text("Show the menu bar sooner")
                    Text("The menu bar slides in when the pointer reaches the top edge, and hides 0.2 s after the pointer leaves it. An open menu keeps it shown.")
                }
                if model.menuBarRevealsSooner {
                    TimingSlider(title: "Wait before showing",
                               explanation: "How long the pointer stays at the top edge before the menu bar slides in. macOS waits 350 ms or longer.",
                               value: Binding(get: { Double(model.menuBarRevealWaitMilliseconds) },
                                              set: { model.menuBarRevealWaitMilliseconds = Int(($0 / 10).rounded()) * 10 }),
                               range: 0...300, label: { $0 == 0 ? "Off" : "\(Int($0)) ms" },
                               onEditingChanged: { _ in })
                }
            }
        } header: {
            Text("Menu Bar")
        }
    }
}

// MARK: Dock

/// A slider of the macOS tab, laid out like Duration in the Spaces tab.
private struct TimingSlider: View {
    let title: String
    let explanation: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: (Double) -> String
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        LabeledContent {
            HStack {
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                    .frame(width: 160)
                Text(label(value))
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        } label: {
            Text(title)
            Text(explanation)
        }
    }
}

/// The hidden Dock: macOS's auto-hide, and the keys of `com.apple.dock` that
/// System Settings does not show (see `DockPreferences`).
private struct DockSection: View {
    @ObservedObject var model: AppModel

    private var settings: MacOSSettings { model.macOSSettings }

    var body: some View {
        Section {
            MacOSSettingRow(
                title: "Automatically hide and show the Dock",
                explanation: "The macOS setting in Desktop & Dock.",
                isOn: Binding(get: { settings.dockAutohidesEffectively },
                              set: { model.setDockAutohides($0) }),
                open: model.openMissionControlSettings)
            if settings.dockAutohidesEffectively {
                // No `step` on the sliders: it draws a tick per step. The values
                // are rounded to 10 ms and 5 % instead.
                TimingSlider(title: "Wait on desktops", explanation: "How long the pointer rests at the edge of a desktop before the Dock appears. macOS default duration: 150 ms.",
                           value: Binding(get: { Double(settings.dockDesktopWaitMilliseconds) },
                                          set: { model.setDockDesktopWait(milliseconds: $0) }),
                           range: 0...300, label: Self.milliseconds,
                           onEditingChanged: model.dockSliderEditing)
                TimingSlider(title: "Push in full-screen apps", explanation: "How long the pointer has to keep pushing against the edge of a full-screen app before the Dock appears. A pause starts the count again, and resting at the edge never shows it. macOS default duration: 250 ms.",
                           value: Binding(get: { Double(settings.dockPushMilliseconds) },
                                          set: { model.setDockPush(milliseconds: $0) }),
                           range: 0...500, label: Self.milliseconds,
                           onEditingChanged: model.dockSliderEditing)
                TimingSlider(title: "Slide duration", explanation: "How long the Dock takes to slide in and out, compared with macOS. Off: no slide.",
                           value: Binding(get: { settings.dockAnimationShare },
                                          set: { model.setDockAnimationShare($0) }),
                           range: 0...1, label: Self.share,
                           onEditingChanged: model.dockSliderEditing)
                if settings.changesDockTiming {
                    LabeledContent {
                        Button("Restore Defaults") { model.restoreDockDefaults() }
                    } label: {
                        Text("macOS's own timing")
                        Text("Removes the settings SpaceJumper made for the Dock.")
                    }
                }
            }
        } header: {
            Text("Dock")
        } footer: {
            Text("The Dock restarts after a change to a slider, as it reads these settings only when it starts. System Settings does not show them; the README lists them.")
                .foregroundStyle(.secondary)
                .formFooter()
        }
    }

    private static func milliseconds(_ value: Double) -> String {
        value == 0 ? "Off" : "\(Int(value)) ms"
    }

    private static func share(_ value: Double) -> String {
        value == 0 ? "Off" : "\(Int((value * 100).rounded())) %"
    }
}

// MARK: macOS

/// The macOS settings that SpaceJumper works with or changes: Mission Control
/// and the hidden Dock.
private struct MacOSPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.switchesOnActivation) {
                    Text("Switch instantly with ⌘Tab")
                    Text("When ⌘Tab or the Dock activates an app with no window on this Space, SpaceJumper switches to a Space where it has one. macOS's option below has to be off.")
                }
                MacOSSettingRow(
                    title: "When switching to an application, switch to a Space with open windows for the application",
                    explanation: model.macOSSettings.switchOnActivateExplanation(spaceJumperSwitches: model.switchesOnActivation),
                    warns: model.macOSSettings.switchOnActivateNeeded(spaceJumperSwitches: model.switchesOnActivation) == false,
                    isOn: Binding(get: { model.macOSSettings.switchesOnActivateEffectively },
                                  set: { model.setMacOSSwitchesOnActivate($0) }),
                    open: model.openMissionControlSettings)
                MacOSSettingRow(
                    title: "Automatically rearrange Spaces based on most recent use",
                    explanation: model.macOSSettings.rearrangeExplanation,
                    isOn: Binding(get: { model.macOSSettings.rearrangesSpacesEffectively },
                                  set: { model.setMacOSRearrangesSpaces($0) }),
                    open: model.openMissionControlSettings)
            } header: {
                Text("Mission Control")
            }
            MenuBarSection(model: model)
            DockSection(model: model)
        }
        .formStyle(.grouped)
        // The window grows to fit the pane instead of scrolling it.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    /// Grouped forms on macOS 15 otherwise right-align section footers.
    func formFooter() -> some View {
        multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var model: AppModel
    @Bindable private var updater = Updater.shared

    var body: some View {
        Form {
            Section {
                Picker("Frame", selection: $model.menuBarFrame) {
                    ForEach(MenuBarFrame.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Shape", selection: $model.menuBarFrameShape) {
                    ForEach(MenuBarFrameShape.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(model.menuBarFrame == .none)
                Toggle(isOn: $model.menuBarShowsSpaceName) {
                    Text("Show the name of full-screen Spaces")
                    Text("The name Mission Control shows: the app, or both apps in split view. Desktops show their number alone.")
                }
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("A frame tells the Space's number apart from other numbers in the menu bar. Filled cuts the number out of the shape; a capsule around one digit is a circle.")
                    .foregroundStyle(.secondary)
                    .formFooter()
            }
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(
                    get: { model.opensAtLogin },
                    set: { model.setOpensAtLogin($0) }))
            }
            Section {
                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                Button("Check Now") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            } header: {
                Text("Updates")
            } footer: {
                Text(updater.isAvailable
                     ? "SpaceJumper checks once a week."
                     : "Updates are only available in SpaceJumper.app.")
                    .foregroundStyle(.secondary)
                    .formFooter()
            }
            .disabled(!updater.isAvailable)
        }
        .formStyle(.grouped)
        // The window grows to fit the pane instead of scrolling it.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}
