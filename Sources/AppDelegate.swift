import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.lifecycle.notice("Application did finish launching")
        ProcessInfo.processInfo.disableAutomaticTermination("Keep menu bar app alive")
        AppController.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
