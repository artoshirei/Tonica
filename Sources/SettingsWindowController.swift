import AppKit
import KeyboardShortcuts
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let controller: AppController
    private var topSwitch: NSButton!
    private var launchSwitch: NSButton!
    private var loginSwitch: NSButton!
    private var updateSwitch: NSButton!
    private var downloadSwitch: NSButton!
    private let loginStatus = label("", size: 11, secondary: true)
    init(controller: AppController) {
        self.controller = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 480), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = AppRuntime.isPreview ? "Tonica Preview Settings" : "Tonica Settings"
        window.isReleasedWhenClosed = false
        window.backgroundColor = TonicaAppearance.background
        window.titlebarAppearsTransparent = true
        super.init(window: window)
        window.delegate = self
        buildContent()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .tonicaModelChanged, object: controller.model)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func checkbox(_ title: String, action: Selector) -> NSButton { NSButton(checkboxWithTitle: title, target: self, action: action) }
    private func buildContent() {
        topSwitch = checkbox("Keep Tonica above other windows", action: #selector(changeTop))
        launchSwitch = checkbox("Show the circle when Tonica starts", action: #selector(changeLaunch))
        loginSwitch = checkbox("Launch at login", action: #selector(changeLogin))
        loginSwitch.isEnabled = !AppRuntime.isPreview
        let general = CardView(stack([label("General", size: 14, weight: .semibold), loginSwitch, loginStatus, launchSwitch, topSwitch], spacing: 10))
        let recorder = KeyboardShortcuts.RecorderCocoa(for: AppRuntime.isPreview ? .init("previewRecorder") : .togglePanel)
        recorder.isEnabled = !AppRuntime.isPreview
        let reset = ActionButton("Restore default") { [weak self] in self?.controller.resetHotKeyToDefault() }
        reset.isEnabled = !AppRuntime.isPreview
        let shortcut = CardView(stack([label("Keyboard shortcut", size: 14, weight: .semibold), label(AppRuntime.isPreview ? "Global shortcuts are disabled in this isolated preview." : "Show or hide Tonica from any app. Clear the recorder to disable.", size: 11, secondary: true), stack([recorder, reset], vertical: false)], spacing: 10))
        updateSwitch = checkbox("Automatically check for updates", action: #selector(changeUpdates))
        downloadSwitch = checkbox("Download updates automatically", action: #selector(changeDownloads))
        let check = ActionButton("Check for Updates…") { [weak self] in self?.controller.checkForUpdates() }
        check.isEnabled = AppRuntime.canUpdate
        let updates = CardView(stack([label("Updates", size: 14, weight: .semibold), label("Tonica \(AppMetadata.versionDescription)", size: 11, secondary: true), updateSwitch, downloadSwitch, check], spacing: 10))
        let content = stack([general, shortcut, updates], spacing: 14)
        content.translatesAutoresizingMaskIntoConstraints = false
        let root = FocusRootView(); window?.contentView = root; root.addSubview(content)
        window?.initialFirstResponder = root
        for card in [general, shortcut, updates] { card.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20), content.topAnchor.constraint(equalTo: root.topAnchor, constant: 20)])
    }
    func present() {
        refresh()
        if window?.isVisible != true { window?.center() }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(window?.contentView)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) { controller.settingsDidClose() }
    @objc private func refresh() {
        topSwitch.state = controller.model.keepOnTop ? .on : .off
        launchSwitch.state = controller.model.showOnLaunch ? .on : .off
        let status = SMAppService.mainApp.status
        loginSwitch.state = status == .enabled || status == .requiresApproval ? .on : .off
        loginStatus.stringValue = AppRuntime.isPreview ? "Login registration is disabled in this preview." : status == .requiresApproval ? "Allow Tonica in System Settings → General → Login Items." : "Keep your harmony reference one click away."
        updateSwitch.state = controller.automaticallyChecksForUpdates ? .on : .off
        downloadSwitch.state = controller.automaticallyDownloadsUpdates ? .on : .off
        updateSwitch.isEnabled = AppRuntime.canUpdate
        downloadSwitch.isEnabled = AppRuntime.canUpdate && updateSwitch.state == .on
    }
    @objc private func changeTop() { controller.model.keepOnTop = topSwitch.state == .on }
    @objc private func changeLaunch() { controller.model.showOnLaunch = launchSwitch.state == .on }
    @objc private func changeUpdates() { controller.automaticallyChecksForUpdates = updateSwitch.state == .on; refresh() }
    @objc private func changeDownloads() { controller.automaticallyDownloadsUpdates = downloadSwitch.state == .on; refresh() }
    @objc private func changeLogin() {
        guard !AppRuntime.isPreview else { return }
        do {
            if loginSwitch.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            refresh()
            let alert = NSAlert(error: error)
            if let window { alert.beginSheetModal(for: window) }
        }
    }
}
