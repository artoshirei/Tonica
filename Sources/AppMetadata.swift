import AppKit

@MainActor
enum AppMetadata {
    static var appName: String {
        stringValue(for: "CFBundleDisplayName")
            ?? stringValue(for: "CFBundleName")
            ?? "Tonica"
    }

    static var shortVersion: String {
        stringValue(for: "CFBundleShortVersionString") ?? "0.0.0"
    }

    static var buildNumber: String {
        stringValue(for: "CFBundleVersion") ?? "0"
    }

    static var versionDescription: String {
        guard buildNumber != shortVersion else { return shortVersion }
        return "\(shortVersion) (\(buildNumber))"
    }

    static var menuVersionTitle: String {
        "Version \(versionDescription)"
    }

    static var aboutPanelOptions: [NSApplication.AboutPanelOptionKey: Any] {
        [
            .applicationName: appName,
            .applicationVersion: "Version \(versionDescription)",
            .applicationIcon: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath),
            .version: ""
        ]
    }

    private static func stringValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
