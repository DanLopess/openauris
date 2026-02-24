import Foundation

enum RealtimeInsertionPolicy {
    static func shouldInsertPartials(languageOverride: String?) -> Bool {
        guard let normalized = normalizedLanguageOverride(languageOverride) else {
            return false
        }

        return normalized != "auto"
    }

    private static func normalizedLanguageOverride(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}
