import Foundation
import SwiftData

@Model
final class UserPreferenceEntity {
    @Attribute(.unique) var id: String
    var holdShortcutData: Data
    var toggleShortcutData: Data
    var defaultModeRawValue: String
    var defaultModelID: String
    var languageOverride: String
    var launchAtLogin: Bool
    var insertionPrefersAccessibility: Bool
    var onboardingCompleted: Bool
    var hasOpenedDashboardOnce: Bool?
    var realtimeStreamingEnabled: Bool = false

    init(
        id: String = "default",
        holdShortcutData: Data,
        toggleShortcutData: Data,
        defaultModeRawValue: String,
        defaultModelID: String,
        languageOverride: String,
        launchAtLogin: Bool,
        insertionPrefersAccessibility: Bool,
        onboardingCompleted: Bool,
        hasOpenedDashboardOnce: Bool?,
        realtimeStreamingEnabled: Bool = false
    ) {
        self.id = id
        self.holdShortcutData = holdShortcutData
        self.toggleShortcutData = toggleShortcutData
        self.defaultModeRawValue = defaultModeRawValue
        self.defaultModelID = defaultModelID
        self.languageOverride = languageOverride
        self.launchAtLogin = launchAtLogin
        self.insertionPrefersAccessibility = insertionPrefersAccessibility
        self.onboardingCompleted = onboardingCompleted
        self.hasOpenedDashboardOnce = hasOpenedDashboardOnce
        self.realtimeStreamingEnabled = realtimeStreamingEnabled
    }
}
