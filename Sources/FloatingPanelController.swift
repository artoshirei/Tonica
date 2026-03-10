import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class FloatingPanelController: NSWindowController, NSWindowDelegate {
    private static let defaultWindowSize = NSSize(width: 1260, height: 840)
    private static let revealAnimationDuration: TimeInterval = 0.08
    private static let hideAnimationDuration: TimeInterval = 0.06

    private let model: AppModel
    private var isAnimatingDismissal = false

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
        window.animationBehavior = .none
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

        isAnimatingDismissal = false
        prepareFrame(for: window)
        window.alphaValue = 0
        showWindow(nil)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        animate(window: window, toAlpha: 1, duration: Self.revealAnimationDuration)
        AppLogger.panel.debug("Presented panel at x=\(Int(window.frame.origin.x), privacy: .public) y=\(Int(window.frame.origin.y), privacy: .public) w=\(Int(window.frame.width), privacy: .public) h=\(Int(window.frame.height), privacy: .public)")
    }

    func dismiss() {
        AppLogger.panel.debug("Dismissing panel window")
        guard let window else { return }

        rememberFrame(from: window)
        isAnimatingDismissal = true
        animate(window: window, toAlpha: 0, duration: Self.hideAnimationDuration) { [weak self] in
            guard let self else { return }
            window.orderOut(nil)
            window.alphaValue = 1
            self.isAnimatingDismissal = false
        }
    }

    func windowWillClose(_ notification: Notification) {
        AppController.shared.panelDidClose()
    }

    func windowDidMove(_ notification: Notification) {
        guard !isAnimatingDismissal, let window else { return }
        rememberFrame(from: window)
    }

    private func prepareFrame(for window: NSWindow) {
        if let rememberedFrame = AppPreferences.loadPanelFrame() {
            let targetFrame = constrainedFrame(for: rememberedFrame)
            window.setContentSize(targetFrame.size)
            window.setFrame(targetFrame, display: false)
            return
        }

        let targetScreen = primaryScreen() ?? NSScreen.main ?? NSScreen.screens.first

        guard let targetScreen else {
            let defaultFrame = NSRect(origin: .zero, size: Self.defaultWindowSize)
            window.setFrame(defaultFrame, display: false)
            window.center()
            rememberFrame(from: window)
            return
        }

        let targetFrame = fittedFrame(for: targetScreen)
        window.setContentSize(targetFrame.size)
        window.setFrame(targetFrame, display: false)
        rememberFrame(from: window)
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

    private func constrainedFrame(for frame: NSRect) -> NSRect {
        let targetScreen = screen(containing: frame) ?? primaryScreen() ?? NSScreen.main ?? NSScreen.screens.first

        guard let targetScreen else { return frame }

        let visible = targetScreen.visibleFrame
        let size = NSSize(
            width: min(frame.width, visible.width),
            height: min(frame.height, visible.height)
        )
        let maxX = visible.maxX - size.width
        let maxY = visible.maxY - size.height
        let origin = CGPoint(
            x: min(max(frame.origin.x, visible.minX), maxX),
            y: min(max(frame.origin.y, visible.minY), maxY)
        )

        return NSRect(origin: origin, size: size)
    }

    private func screen(containing frame: NSRect) -> NSScreen? {
        let frameCenter = CGPoint(x: frame.midX, y: frame.midY)

        if let exact = NSScreen.screens.first(where: { $0.visibleFrame.contains(frameCenter) }) {
            return exact
        }

        return NSScreen.screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(frame).area < rhs.visibleFrame.intersection(frame).area
        }
    }

    private func rememberFrame(from window: NSWindow) {
        AppPreferences.savePanelFrame(window.frame)
    }

    private func animate(
        window: NSWindow,
        toAlpha alpha: CGFloat,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = alpha
        } completionHandler: {
            completion?()
        }
    }
}

private final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
