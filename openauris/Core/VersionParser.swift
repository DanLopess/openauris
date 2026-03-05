import Foundation

struct AppVersion: Equatable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    var string: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

enum VersionParser {
    /// Parses "1.2.3" or "1.2" into AppVersion. Returns nil if invalid.
    static func parse(_ string: String) -> AppVersion? {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else { return nil }
        let patch = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
        return AppVersion(major: major, minor: minor, patch: patch)
    }

    /// Given a "major.minor" string and existing git tag strings (e.g. ["v0.0.1", "v0.0.2"]),
    /// returns the next full version string (e.g. "0.0.3").
    static func nextVersion(majorMinor: String, existingTags: [String]) -> String {
        guard let base = parse(majorMinor) else { return "\(majorMinor).1" }

        let prefix = "v\(base.major).\(base.minor)."
        let patches = existingTags
            .filter { $0.hasPrefix(prefix) }
            .compactMap { tag -> Int? in Int(String(tag.dropFirst(prefix.count))) }

        let nextPatch: Int
        if let max = patches.max() {
            nextPatch = max + 1
        } else if existingTags.isEmpty {
            nextPatch = 1  // absolute first release — no tags exist yet
        } else {
            nextPatch = 0  // new version line — tags exist but none for this major.minor
        }
        return "\(base.major).\(base.minor).\(nextPatch)"
    }
}
