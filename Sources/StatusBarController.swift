import AppKit

@MainActor
final class StatusBarController: NSObject {
    private weak var controller: AppController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "Reveal Circle", action: #selector(togglePanel), keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
    private var animationTimer: Timer?
    private let animationStartDate = Date()

    init(controller: AppController) {
        self.controller = controller
        super.init()
        configureMenu()
        configureStatusItem()
        startStatusItemAnimation()
    }

    func update(isPanelVisible: Bool, shortcutDescription: String) {
        toggleItem.title = isPanelVisible ? "Hide Circle" : "Reveal Circle"
        shortcutItem.title = "Shortcut: \(shortcutDescription)"
        statusItem.button?.toolTip = "Tonica"
    }

    private func configureMenu() {
        toggleItem.target = self
        shortcutItem.isEnabled = false
        settingsItem.target = self
        quitItem.target = self

        menu.items = [
            toggleItem,
            .separator(),
            shortcutItem,
            .separator(),
            settingsItem,
            .separator(),
            quitItem
        ]
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            AppLogger.lifecycle.error("Failed to create status item button")
            return
        }

        let image = Self.makeStatusBarImage(phase: 0)
        image.isTemplate = false

        button.image = image
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Tonica"

        statusItem.menu = menu
        statusItem.isVisible = true

        AppLogger.lifecycle.notice("Installed AppKit status item")
    }

    private func startStatusItemAnimation() {
        animationTimer?.invalidate()

        let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimatedStatusItemImage()
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateAnimatedStatusItemImage() {
        guard let button = statusItem.button else { return }
        let phase = Date().timeIntervalSince(animationStartDate)
        let image = Self.makeStatusBarImage(phase: phase)
        image.isTemplate = false
        button.image = image
    }

    @objc
    private func togglePanel() {
        controller?.togglePanelFromMenuBar()
    }

    @objc
    private func openSettings() {
        controller?.openSettingsWindow()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private static func makeStatusBarImage(phase: TimeInterval, size: CGFloat = 19) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize, flipped: false) { rect in
            let side = min(rect.width, rect.height)
            let pulseCycle = phase * (.pi * 2.0) / 2.9
            let middlePulse = (sin(pulseCycle - (.pi / 2.0)) + 1.0) * 0.5
            let innerPulse = (sin((pulseCycle * 1.08) + (.pi / 5.0)) + 1.0) * 0.5
            let outerDiameter = side * 0.96
            let sizeRatios: [CGFloat] = [1.0, 496.0 / 652.0, 292.0 / 652.0]
            let colors: [NSColor] = [
                NSColor(calibratedRed: 1.0, green: 0.792, blue: 0.157, alpha: 1.0),
                NSColor(calibratedRed: 0.0, green: 0.812, blue: 1.0, alpha: 1.0),
                NSColor(calibratedRed: 1.0, green: 0.235, blue: 0.675, alpha: 1.0)
            ]
            let scaleModifiers: [CGFloat] = [
                1.0,
                0.93 + (0.08 * middlePulse),
                0.83 + (0.16 * innerPulse)
            ]

            for (index, ratio) in sizeRatios.enumerated() {
                let layerSize = outerDiameter * ratio * scaleModifiers[index]
                let layerRect = CGRect(
                    x: rect.midX - layerSize * 0.5,
                    y: rect.midY - layerSize * 0.5,
                    width: layerSize,
                    height: layerSize
                )

                colors[index].setFill()
                NSBezierPath(ovalIn: layerRect).fill()
            }

            return true
        }

        return image
    }
}
