import Carbon.HIToolbox
import Testing
@testable import SpaceJumperCore

// Values as SkyLight reported them on macOS 27.0.1.
private let tileLeftHalf = SystemShortcut(id: 240, keyCode: kVK_LeftArrow, flags: 0x840000, identifier: "WindowTileLeftHalf")
private let splitViewMakeLeft = SystemShortcut(id: 199, keyCode: kVK_LeftArrow, flags: 0x840000, identifier: "SplitViewMakeLeft")
private let moveLeftASpace = SystemShortcut(id: 79, keyCode: kVK_LeftArrow, flags: 0x840000, identifier: "WorkspacesLeft")
private let moveLeftASpaceSlow = SystemShortcut(id: 80, keyCode: kVK_LeftArrow, flags: 0x860000, identifier: "WorkspacesLeftSlow")
private let switchToDesktop1 = SystemShortcut(id: 118, keyCode: kVK_ANSI_1, flags: 0x40000, identifier: "Workspaces1")

@Suite struct SystemShortcutTests {
    @Test func knownNamesUseTheSystemSettingsLabel() {
        #expect(tileLeftHalf.name == "“Tile Left Half” (Windows)")
        #expect(switchToDesktop1.name == "“Switch to Desktop 1” (Mission Control)")
        #expect(SystemShortcut(id: 127, keyCode: 0, flags: 0, identifier: "Workspaces10").name == "“Switch to Desktop 10” (Mission Control)")
        #expect(SystemShortcut(id: 79, keyCode: 0, flags: 0, identifier: "WorkspacesLeft").name == "“Move left a Space” (Mission Control)")
    }

    @Test func unknownNamesShowNumberAndIdentifier() {
        #expect(splitViewMakeLeft.name == "macOS shortcut 199 (SplitViewMakeLeft)")
        #expect(SystemShortcut(id: 300, keyCode: 0, flags: 0).name == "macOS shortcut 300")
        // Numbered keypad variants are not "Switch to Desktop N".
        #expect(SystemShortcut(id: 134, keyCode: 0, flags: 0, identifier: "WorkspacesNumPad1").label == nil)
    }

    @Test func missingNamesUseKnownMissionControlLabels() {
        for (id, title) in [(32, "Mission Control"), (34, "Application windows"),
                            (79, "Move left a Space"), (81, "Move right a Space")] {
            let shortcut = SystemShortcut(id: Int32(id), keyCode: 0, flags: 0)
            #expect(shortcut.label == .init(title: title, section: "Mission Control"))
        }
        for number in 1...9 {
            let shortcut = SystemShortcut(id: Int32(117 + number), keyCode: 0, flags: 0)
            #expect(shortcut.name == "“Switch to Desktop \(number)” (Mission Control)")
        }
        // Do not guess names for adjacent IDs or the slow/keypad variants.
        for id in [33, 35, 80, 82, 117, 127, 134, 300] {
            let shortcut = SystemShortcut(id: Int32(id), keyCode: 0, flags: 0)
            #expect(shortcut.label == nil)
            #expect(shortcut.name == "macOS shortcut \(id)")
        }
    }

    @Test func suppliedNamesOverrideNumericLabelFallbacks() {
        let known = SystemShortcut(id: 120, keyCode: 0, flags: 0, identifier: "WorkspacesLeft")
        #expect(known.name == "“Move left a Space” (Mission Control)")
        let unknown = SystemShortcut(id: 120, keyCode: 0, flags: 0, identifier: "SomethingElse")
        #expect(unknown.label == nil)
        #expect(unknown.name == "macOS shortcut 120 (SomethingElse)")
    }

    @Test func clashDescription() {
        let clash = ShortcutClash(binding: HotKeyBinding.arrowKeys(.control)[0], shortcut: tileLeftHalf)
        #expect(clash.description == "⌃← also triggers “Tile Left Half” (Windows)")
    }

    @Test func findAsksOnlyAboutShortcutsOnTheSameKey() {
        var asked: [Int32] = []
        let clashes = ShortcutClash.find(HotKeyBinding.desktopKeys(.control), in: [moveLeftASpace, switchToDesktop1]) { _, shortcut in
            asked.append(shortcut.id)
            return true
        }
        #expect(asked == [118])
        #expect(clashes.map(\.binding.name) == ["⌃1"])
    }

    @Test func findKeepsOnlyWhatTheMatcherConfirms() {
        let clashes = ShortcutClash.find(HotKeyBinding.arrowKeys(.control), in: [moveLeftASpace, moveLeftASpaceSlow]) { _, shortcut in
            shortcut.id == 79
        }
        #expect(clashes.map(\.shortcut.id) == [79])
    }

    /// Stored like ⌃← and matched by WindowServer, but pressing ⌃← does not
    /// trigger the tiling and split-view shortcuts (default fn⌃←).
    @Test func arrowShortcutsOutsideMissionControlDoNotCount() {
        let clashes = ShortcutClash.find(HotKeyBinding.arrowKeys(.control),
                                         in: [tileLeftHalf, splitViewMakeLeft, moveLeftASpace]) { _, _ in true }
        #expect(clashes.map(\.shortcut.id) == [79])
    }

    @Test func missionControlFamilyReactsToPlainArrows() {
        #expect(moveLeftASpace.reactsToPlainArrowKeys)
        #expect(SystemShortcut(id: 32, keyCode: kVK_UpArrow, flags: 0x840000, identifier: "WindowVousAll").reactsToPlainArrowKeys)
        #expect(!tileLeftHalf.reactsToPlainArrowKeys)
        #expect(!splitViewMakeLeft.reactsToPlainArrowKeys)
        #expect(SystemShortcut(id: 79, keyCode: kVK_LeftArrow, flags: 0x840000).reactsToPlainArrowKeys)
    }

    @Test func missingNamesUseMissionControlIDsForArrowConflicts() {
        let shortcuts = [32, 33, 34, 35, 79, 80, 81, 82, 199, 240, 300].map {
            SystemShortcut(id: Int32($0), keyCode: kVK_LeftArrow, flags: 0x840000)
        }
        let clashes = ShortcutClash.find(HotKeyBinding.arrowKeys(.control), in: shortcuts) { _, _ in true }
        #expect(clashes.map(\.shortcut.id) == [32, 33, 34, 35, 79, 80, 81, 82])
        #expect(clashes.first?.shortcut.name == "“Mission Control” (Mission Control)")
        // A supplied name remains authoritative, even for a known numeric ID.
        #expect(!SystemShortcut(id: 79, keyCode: kVK_LeftArrow, flags: 0,
                               identifier: "SomethingElse").reactsToPlainArrowKeys)
    }

    /// Digits carry no fn flag, so the tiling exception does not apply.
    @Test func digitShortcutsCountWhateverTheirName() {
        let other = SystemShortcut(id: 300, keyCode: kVK_ANSI_1, flags: 0x40000, identifier: "SomethingElse")
        let clashes = ShortcutClash.find(HotKeyBinding.desktopKeys(.control), in: [other]) { _, _ in true }
        #expect(clashes.map(\.shortcut.id) == [300])
    }
}
