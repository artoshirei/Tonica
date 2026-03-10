import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSWindowController, NSWindowDelegate {
    private static let defaultWindowSize = NSSize(width: 1260, height: 840)

    private let model: AppModel

    init(model: AppModel) {
        self.model = model

        let window = FloatingWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.level = .floating
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .utilityWindow
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true

        let host = NSHostingController(rootView: CirclePanelView(model: model))
        host.sizingOptions = []
        host.preferredContentSize = Self.defaultWindowSize
        window.contentViewController = host
        window.setContentSize(Self.defaultWindowSize)
        window.setFrame(NSRect(origin: .zero, size: Self.defaultWindowSize), display: false)

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        guard let window else {
            AppLogger.panel.error("Panel presentation skipped because the window controller has no window")
            return
        }

        prepareFrame(for: window)
        showWindow(nil)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        AppLogger.panel.debug("Presented panel at x=\(Int(window.frame.origin.x), privacy: .public) y=\(Int(window.frame.origin.y), privacy: .public) w=\(Int(window.frame.width), privacy: .public) h=\(Int(window.frame.height), privacy: .public)")
    }

    func dismiss() {
        AppLogger.panel.debug("Dismissing panel window")
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppController.shared.panelDidClose()
    }

    private func prepareFrame(for window: NSWindow) {
        let targetScreen = primaryScreen() ?? NSScreen.main ?? NSScreen.screens.first

        guard let targetScreen else {
            window.setFrame(NSRect(origin: .zero, size: Self.defaultWindowSize), display: false)
            window.center()
            return
        }

        let targetFrame = fittedFrame(for: targetScreen)
        window.setContentSize(targetFrame.size)
        window.setFrame(targetFrame, display: false)
    }

    private func primaryScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }

            return CGDisplayIsMain(number.uint32Value) != 0
        }
    }

    private func fittedFrame(for screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let inset: CGFloat = 40
        let availableWidth = max(visible.width - inset * 2, 480)
        let availableHeight = max(visible.height - inset * 2, 360)
        let scale = min(
            1,
            availableWidth / Self.defaultWindowSize.width,
            availableHeight / Self.defaultWindowSize.height
        )
        let size = NSSize(
            width: floor(Self.defaultWindowSize.width * scale),
            height: floor(Self.defaultWindowSize.height * scale)
        )
        let origin = CGPoint(
            x: round(visible.midX - size.width / 2),
            y: round(visible.midY - size.height / 2)
        )

        return NSRect(origin: origin, size: size)
    }
}

private final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
