import AppKit
import Combine
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let repository: AppRepository
    let permissionManager: PermissionManager
    let bubbleViewModel: BubbleViewModel
    let overlayController: OverlayPanelController
    let modelManager: WhisperModelManager
    let sessionManager: DictationSessionManager
    let hotkeyManager: GlobalHotkeyManager

    var preferences: UserPreferenceEntity?
    var sessions: [DictationSessionEntity] = []
    var dailyStats: [DailyStatsEntity] = []
    var achievements: [AchievementEntity] = []
    var usageSnapshot = UsageSnapshot(
        totalWords: 0,
        totalSessions: 0,
        totalSpeakingSeconds: 0,
        averageWPM: 0,
        currentStreakDays: 0
    )
    var searchQuery: String = "" {
        didSet {
            reloadSessions()
        }
    }
    var showOnboarding = false
    var startupErrorMessage: String?

    private var didBootstrap = false
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("-openauris-ui-testing")
    private var cancellables = Set<AnyCancellable>()

    init() {
        modelContainer = PersistenceController.makeModelContainer()
        let context = modelContainer.mainContext
        repository = AppRepository(context: context)

        permissionManager = PermissionManager()
        bubbleViewModel = BubbleViewModel()
        overlayController = OverlayPanelController(viewModel: bubbleViewModel)
        modelManager = WhisperModelManager(repository: repository)
        hotkeyManager = GlobalHotkeyManager()

        let audioCaptureService = AudioCaptureService()
        let engine = WhisperKitTranscriptionEngine()
        let insertion = AccessibilityTextInsertionService()

        sessionManager = DictationSessionManager(
            audioCaptureService: audioCaptureService,
            transcriptionEngine: engine,
            insertionService: insertion,
            repository: repository,
            modelManager: modelManager,
            permissionManager: permissionManager,
            bubbleViewModel: bubbleViewModel,
            overlayController: overlayController
        )

        hotkeyManager.onAction = { [weak sessionManager] action in
            sessionManager?.handleHotkeyAction(action)
        }

        bindAppSignals()
        bootstrapIfNeeded()
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        do {
            let prefs = try repository.ensurePreferences()
            preferences = prefs
            applyHotkeys(from: prefs)

            if isUITesting {
                showOnboarding = false
            } else {
                let firstLaunch = !(prefs.hasOpenedDashboardOnce ?? false)
                showOnboarding = firstLaunch
                if firstLaunch {
                    prefs.hasOpenedDashboardOnce = true
                    try repository.savePreferences(prefs)
                }
            }

            if isUITesting && !(prefs.hasOpenedDashboardOnce ?? false) {
                prefs.hasOpenedDashboardOnce = true
                try repository.savePreferences(prefs)
            }

            permissionManager.refresh()

            await modelManager.installDefaultModelIfNeeded()
            refreshDashboardData()
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func refreshDashboardData() {
        do {
            sessions = try repository.fetchSessions(search: searchQuery)
            dailyStats = try repository.fetchDailyStats()
            achievements = try repository.fetchAchievements()
            usageSnapshot = try repository.usageSnapshot()
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func completeOnboarding() {
        guard let preferences else { return }

        preferences.hasOpenedDashboardOnce = true
        showOnboarding = false

        do {
            try repository.savePreferences(preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func requestModelInstall(_ model: WhisperModelDescriptor) {
        Task {
            do {
                try await modelManager.install(model: model)
                refreshDashboardData()
            } catch {
                startupErrorMessage = error.localizedDescription
            }
        }
    }

    func makeDefaultModel(_ modelID: String) {
        modelManager.setDefaultModel(modelID)
        guard let preferences else { return }

        preferences.defaultModelID = modelID

        do {
            try repository.savePreferences(preferences)
            refreshDashboardData()
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard let preferences else { return }

        preferences.launchAtLogin = enabled
        LoginItemManager.setEnabled(enabled)

        do {
            try repository.savePreferences(preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func setLanguageOverride(_ value: String) {
        guard let preferences else { return }

        preferences.languageOverride = value

        do {
            try repository.savePreferences(preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func setInsertionPreference(prefersAccessibility: Bool) {
        guard let preferences else { return }

        preferences.insertionPrefersAccessibility = prefersAccessibility

        do {
            try repository.savePreferences(preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func setDefaultMode(_ mode: DictationMode) {
        guard let preferences else { return }

        preferences.defaultModeRawValue = mode.rawValue

        do {
            try repository.savePreferences(preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func setHoldShortcut(_ shortcut: ShortcutBinding) {
        guard let preferences else { return }

        let encoder = JSONEncoder()
        do {
            let decoder = JSONDecoder()
            let currentToggle = (try? decoder.decode(ShortcutBinding.self, from: preferences.toggleShortcutData)) ?? .defaultToggle
            let resolvedToggle = resolveDistinctToggleShortcut(hold: shortcut, requestedToggle: currentToggle)

            preferences.holdShortcutData = try encoder.encode(shortcut)
            preferences.toggleShortcutData = try encoder.encode(resolvedToggle)
            try repository.savePreferences(preferences)
            applyHotkeys(from: preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func setToggleShortcut(_ shortcut: ShortcutBinding) {
        guard let preferences else { return }

        let encoder = JSONEncoder()
        do {
            let decoder = JSONDecoder()
            let currentHold = (try? decoder.decode(ShortcutBinding.self, from: preferences.holdShortcutData)) ?? .defaultHold
            let resolvedToggle = resolveDistinctToggleShortcut(hold: currentHold, requestedToggle: shortcut)

            preferences.toggleShortcutData = try encoder.encode(resolvedToggle)
            try repository.savePreferences(preferences)
            applyHotkeys(from: preferences)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func deleteSession(_ session: DictationSessionEntity) {
        do {
            try repository.markDeleted(session)
            refreshDashboardData()
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    func clearAllHistory() {
        do {
            try repository.clearAllHistory()
            refreshDashboardData()
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    private func reloadSessions() {
        do {
            sessions = try repository.fetchSessions(search: searchQuery)
        } catch {
            startupErrorMessage = error.localizedDescription
        }
    }

    private func applyHotkeys(from preferences: UserPreferenceEntity) {
        let decoder = JSONDecoder()

        let holdShortcut = (try? decoder.decode(ShortcutBinding.self, from: preferences.holdShortcutData)) ?? .defaultHold
        let requestedToggle = (try? decoder.decode(ShortcutBinding.self, from: preferences.toggleShortcutData)) ?? .defaultToggle
        let toggleShortcut = resolveDistinctToggleShortcut(hold: holdShortcut, requestedToggle: requestedToggle)

        hotkeyManager.registerShortcuts(hold: holdShortcut, toggle: toggleShortcut)

        if toggleShortcut != requestedToggle {
            startupErrorMessage = "Hold and toggle shortcuts cannot be the same. Toggle was reset to \(toggleShortcut.readable)."
        }
    }

    private func resolveDistinctToggleShortcut(hold: ShortcutBinding, requestedToggle: ShortcutBinding) -> ShortcutBinding {
        guard hold == requestedToggle else { return requestedToggle }

        let fallbackCandidates: [ShortcutBinding] = [
            .defaultToggle,
            ShortcutBinding(
                keyCode: 36,
                modifiersRawValue: (NSEvent.ModifierFlags.control.union(.command)).rawValue
            ),
            ShortcutBinding(
                keyCode: 49,
                modifiersRawValue: (NSEvent.ModifierFlags.control.union(.command)).rawValue
            )
        ]

        return fallbackCandidates.first(where: { $0 != hold }) ?? .defaultToggle
    }

    private func bindAppSignals() {
        NotificationCenter.default.publisher(for: .openAurisToggleDictation)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.sessionManager.handleHotkeyAction(.toggle)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .openAurisCancelDictation)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.sessionManager.cancelCurrentSession()
            }
            .store(in: &cancellables)
    }
}
