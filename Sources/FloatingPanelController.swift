import AppKit

@MainActor
final class FloatingPanelController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var restoringFrame = false
    init(model: AppModel) {
        self.model = model
        let window = HarmonyWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = AppRuntime.isPreview ? "Tonica Preview · AppKit" : "Tonica"
        window.isReleasedWhenClosed = false
        window.backgroundColor = TonicaAppearance.background
        window.titlebarAppearsTransparent = true
        window.contentMinSize = NSSize(width: 940, height: 660)
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.contentViewController = HarmonyViewController(model: model)
        window.initialFirstResponder = window.contentView
        super.init(window: window)
        window.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(updateWindowLevel), name: .tonicaModelChanged, object: model)
        updateWindowLevel()
    }
    required init?(coder: NSCoder) { fatalError() }
    func present() {
        guard let window else { return }
        if !window.isVisible {
            restoringFrame = true
            let desired = AppPreferences.loadPanelFrame() ?? window.frame
            let screen = NSScreen.screens.max { $0.visibleFrame.intersection(desired).size.area < $1.visibleFrame.intersection(desired).size.area } ?? NSScreen.main
            if let screen {
                let visible = screen.visibleFrame
                let size = NSSize(width: min(max(940, desired.width), visible.width), height: min(max(688, desired.height), visible.height))
                let origin = AppPreferences.loadPanelFrame() == nil ? NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2) : NSPoint(x: min(max(desired.minX, visible.minX), visible.maxX - size.width), y: min(max(desired.minY, visible.minY), visible.maxY - size.height))
                window.setFrame(NSRect(origin: origin, size: size), display: false)
            }
            restoringFrame = false
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)
    }
    func dismiss() { remember(); window?.orderOut(nil) }
    func windowWillClose(_ notification: Notification) { remember(); AppController.shared.panelDidClose() }
    func windowDidMove(_ notification: Notification) { remember() }
    func windowDidResize(_ notification: Notification) { remember() }
    private func remember() { if !restoringFrame, let window { AppPreferences.savePanelFrame(window.frame) } }
    @objc private func updateWindowLevel() { window?.level = model.keepOnTop ? .floating : .normal }
}

private final class HarmonyWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { AppController.shared.hidePanel() }
}
private extension NSSize { var area: CGFloat { max(0, width) * max(0, height) } }
