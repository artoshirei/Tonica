import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self(
        "togglePanel",
        default: .init(.c, modifiers: [.control, .option, .command])
    )
}

enum PanelHotKey {
    @MainActor
    static func ensureDefaultShortcut() {
        guard KeyboardShortcuts.getShortcut(for: .togglePanel) == nil else { return }
        KeyboardShortcuts.reset(.togglePanel)
    }

    @MainActor
    static func resetToDefault() {
        KeyboardShortcuts.reset(.togglePanel)
    }

    @MainActor
    static var description: String {
        KeyboardShortcuts.getShortcut(for: .togglePanel)?.description ?? "Not set"
    }
}
