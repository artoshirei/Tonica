import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultSize = NSSize(width: 468, height: 410)

    init(controller: AppController) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.identifier = NSUserInterfaceItemIdentifier("tonica.settings")
        window.contentMinSize = Self.defaultSize
        window.contentMaxSize = Self.defaultSize

        let host = NSHostingController(rootView: SettingsView(controller: controller))
        window.contentViewController = host
        window.setContentSize(Self.defaultSize)

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        guard let window else { return }
        positionWindowOnPrimaryScreen(window)
        showWindow(nil)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        AppController.shared.settingsDidClose()
    }

    private func positionWindowOnPrimaryScreen(_ window: NSWindow) {
        guard let screen = primaryScreen() ?? NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let origin = CGPoint(
            x: round(visibleFrame.midX - Self.defaultSize.width / 2),
            y: round(visibleFrame.midY - Self.defaultSize.height / 2)
        )

        let frame = NSRect(origin: origin, size: Self.defaultSize)
        window.setFrame(frame, display: false)
    }

    private func primaryScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }

            return CGDisplayIsMain(number.uint32Value) != 0
        }
    }
}
