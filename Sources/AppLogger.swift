import Foundation
import OSLog
import Security

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.playground.tonica"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let hotKey = Logger(subsystem: subsystem, category: "hotkey")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let updates = Logger(subsystem: subsystem, category: "updates")
}

func describeOSStatus(_ status: OSStatus) -> String {
    if status == noErr {
        return "noErr"
    }

    if let message = SecCopyErrorMessageString(status, nil) as String? {
        return "\(message) (\(status))"
    }

    return "OSStatus(\(status))"
}
