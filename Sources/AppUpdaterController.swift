import AppKit
import Sparkle

@MainActor
private final class UpdaterDelegateProxy: NSObject, SPUUpdaterDelegate {
    var onUpdateCycleFinished: (() -> Void)?

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        onUpdateCycleFinished?()
    }
}

@MainActor
final class AppUpdaterController: NSObject {
    private let updaterDelegateProxy = UpdaterDelegateProxy()
    private let updaterController: SPUStandardUpdaterController

    var onUpdateCycleFinished: (() -> Void)? {
        get { updaterDelegateProxy.onUpdateCycleFinished }
        set { updaterDelegateProxy.onUpdateCycleFinished = newValue }
    }

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegateProxy,
            userDriverDelegate: nil
        )
        super.init()
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }
}
