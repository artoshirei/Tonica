import Foundation

enum AppUpdateState: Equatable {
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(currentVersion: String, latestVersion: String, downloadURL: URL)
    case unavailable
}

enum AppUpdateChecker {
    static let stableDownloadURL = URL(string: "https://github.com/artoshirei/Tonica/releases/latest/download/Tonica.dmg")!
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/artoshirei/Tonica/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func checkForUpdates() async -> AppUpdateState {
        do {
            let latestVersion = try await fetchLatestReleaseVersion()
            let current = currentVersion

            if compareVersions(current, latestVersion) == .orderedAscending {
                return .updateAvailable(
                    currentVersion: current,
                    latestVersion: latestVersion,
                    downloadURL: stableDownloadURL
                )
            }

            return .upToDate(currentVersion: current)
        } catch {
            return .unavailable
        }
    }

    private static func fetchLatestReleaseVersion() async throws -> String {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Tonica/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return normalizedVersion(from: release.tagName)
    }

    private static func normalizedVersion(from rawVersion: String) -> String {
        rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = numericComponents(in: lhs)
        let rhsParts = numericComponents(in: rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0 ..< count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0

            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }

        return .orderedSame
    }

    private static func numericComponents(in version: String) -> [Int] {
        normalizedVersion(from: version)
            .split(separator: ".")
            .compactMap { Int($0) }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}
