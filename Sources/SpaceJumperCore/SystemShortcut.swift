import Carbon.HIToolbox

/// An enabled macOS keyboard shortcut ("symbolic hotkey"), as SkyLight reports
/// it: a number, a key code, `CGEventFlags` and an internal name.
public struct SystemShortcut: Equatable, Sendable {
    public let id: Int32
    public let keyCode: Int
    public let flags: UInt64
    /// SkyLight's internal name, e.g. "WindowTileLeftHalf"; nil until looked up.
    public var identifier: String?

    public init(id: Int32, keyCode: Int, flags: UInt64, identifier: String? = nil) {
        self.id = id
        self.keyCode = keyCode
        self.flags = flags
        self.identifier = identifier
    }

    /// Where System Settings lists a shortcut: its label and its section under
    /// Keyboard → Keyboard Shortcuts.
    public struct Label: Equatable, Sendable {
        public let title: String
        public let section: String
    }

    /// The System Settings label for the internal names SpaceJumper knows.
    /// Each title is the English text of System Settings' table
    /// (`KeyboardSettings.appex/Contents/Resources/DefaultShortcutsTable.loctable`).
    public var label: Label? {
        guard let identifier else { return nil }
        switch identifier {
        case "WorkspacesLeft": return Label(title: "Move left a Space", section: "Mission Control")
        case "WorkspacesRight": return Label(title: "Move right a Space", section: "Mission Control")
        case "WindowTileLeftHalf": return Label(title: "Tile Left Half", section: "Windows")
        case "WindowTileRightHalf": return Label(title: "Tile Right Half", section: "Windows")
        case "WindowTileTopHalf": return Label(title: "Tile Top Half", section: "Windows")
        case "WindowTileBottomHalf": return Label(title: "Tile Bottom Half", section: "Windows")
        case "WindowArrangeLeftAndRight": return Label(title: "Arrange Left and Right", section: "Windows")
        case "WindowArrangeRightAndLeft": return Label(title: "Arrange Right and Left", section: "Windows")
        case "WindowArrangeTopAndBottom": return Label(title: "Arrange Top and Bottom", section: "Windows")
        case "WindowArrangeBottomAndTop": return Label(title: "Arrange Bottom and Top", section: "Windows")
        default:
            if identifier.hasPrefix("Workspaces"), let number = Int(identifier.dropFirst("Workspaces".count)) {
                return Label(title: "Switch to Desktop \(number)", section: "Mission Control")
            }
            return nil
        }
    }

    /// Whether the shortcut reacts to an arrow key without fn (Globe), as far
    /// as SpaceJumper can tell. For arrow keys SkyLight stores ⌃← and fn⌃←
    /// the same way (key 123, flags 0x840000, identical records), and
    /// WindowServer's matching reports both. Pressing ⌃← on macOS 27 does
    /// not trigger the window-tiling shortcuts (default fn⌃←), while the
    /// Mission Control family is defined with plain arrows: "Move left/right a
    /// Space" (`Workspaces…`) and Mission Control / Application windows
    /// (`WindowVous…`). Only that family counts; a shortcut the user rebinds
    /// to a plain arrow is missed.
    public var reactsToPlainArrowKeys: Bool {
        guard let identifier else {
            // Older macOS lacks SLSSymbolicHotKeyName. Use the established
            // symbolic IDs for Mission Control / Application windows (and slow
            // variants), and moving left/right a Space (and slow variants).
            // Unknown IDs stay excluded to avoid fn-arrow tiling false alarms.
            return (32...35).contains(id) || (79...82).contains(id)
        }
        return identifier.hasPrefix("Workspaces") || identifier.hasPrefix("WindowVous")
    }

    /// E.g. "“Tile Left Half” (Windows)", or "macOS shortcut 199
    /// (SplitViewMakeLeft)" when System Settings' label is not known.
    public var name: String {
        if let label { return "“\(label.title)” (\(label.section))" }
        return "macOS shortcut \(id)" + (identifier.map { " (\($0))" } ?? "")
    }
}

/// A binding of SpaceJumper that a macOS shortcut also reacts to.
public struct ShortcutClash: Equatable, Sendable {
    public let binding: HotKeyBinding
    public let shortcut: SystemShortcut

    /// E.g. "⌃← also triggers “Tile Left Half” (Windows)".
    public var description: String {
        "\(binding.name) also triggers \(shortcut.name)"
    }

    /// The clashes among `bindings`. Shortcuts on other keys are skipped; on
    /// arrow keys only those that react to plain arrows count (see
    /// `SystemShortcut.reactsToPlainArrowKeys`), which needs `identifier`. For
    /// the rest, `matches` decides, which in the app asks WindowServer with the
    /// key event the keyboard would send.
    public static func find(_ bindings: [HotKeyBinding], in shortcuts: [SystemShortcut],
                            matches: (HotKeyBinding, SystemShortcut) -> Bool) -> [ShortcutClash] {
        bindings.flatMap { binding in
            let isArrow = HotKeyBinding.arrowKeyCodes.contains(binding.keyCode)
            return shortcuts
                .filter { $0.keyCode == binding.keyCode && (!isArrow || $0.reactsToPlainArrowKeys) && matches(binding, $0) }
                .map { ShortcutClash(binding: binding, shortcut: $0) }
        }
    }
}
