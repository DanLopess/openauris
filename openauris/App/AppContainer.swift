import Combine
import Foundation
import SwiftData

@MainActor
final class AppContainer: ObservableObject {
    let modelContainer: ModelContainer
    let repository: AppRepository
    let permissionManager: PermissionManager
    let bubbleViewModel: BubbleViewModel
    let overlayController: OverlayPanelController
    let modelManager: WhisperModelManager
    let sessionManager: DictationSessionManager
    let hotkeyManager: GlobalHotkeyManager

    @Published var preferences: UserPreferenceEntity?
    @Published var sessions: [DictationSessionEntity] = []
    @Published var dailyStats: [DailyStatsEntity] = []
    @Published var achievements: [AchievementEntity] = []
    @Published var usageSnapshot = UsageSnapshot(
        totalWords: 0,
        totalSessions: 0,
        totalSpeakingSeconds: 0,
        averageWPM: 0,
        currentStreakDays: 0
    )
    @Published var searchQuery: String = "" {
        didSet {
            reloadSessions()
        }
    }
    @Published var selectedTab: DashboardTab = .home
    @Published var showOnboarding = false
    @Published var startupErrorMessage: String?
    @Published var pendingInitialDashboardOpen = false

    private var didBootstrap = false
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

            if prefs.hasOpenedDashboardOnce != true {
                prefs.hasOpenedDashboardOnce = true
                try repository.savePreferences(prefs)
                pendingInitialDashboardOpen = true
            }

            showOnboarding = !prefs.onboardingCompleted
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

        preferences.onboardingCompleted = true
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
            preferences.holdShortcutData = try encoder.encode(shortcut)
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
            preferences.toggleShortcutData = try encoder.encode(shortcut)
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

    func consumeInitialDashboardOpen() {
        pendingInitialDashboardOpen = false
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
        let toggleShortcut = (try? decoder.decode(ShortcutBinding.self, from: preferences.toggleShortcutData)) ?? .defaultToggle

        hotkeyManager.registerShortcuts(hold: holdShortcut, toggle: toggleShortcut)
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
