import Combine
import Foundation

import WhisperKit

struct WhisperModelDescriptor: Identifiable, Sendable {
    let id: String
    let displayName: String
    let estimatedSizeBytes: Int64
    let description: String

    static let curated: [WhisperModelDescriptor] = [
        WhisperModelDescriptor(id: "tiny", displayName: "Tiny", estimatedSizeBytes: 150_000_000, description: "Fastest, lower accuracy."),
        WhisperModelDescriptor(id: "small", displayName: "Small", estimatedSizeBytes: 500_000_000, description: "Balanced for speed and quality."),
        WhisperModelDescriptor(id: "medium", displayName: "Medium", estimatedSizeBytes: 1_500_000_000, description: "Higher quality, heavier memory usage.")
    ]
}

enum WhisperModelManagerError: LocalizedError {
    case unknownModel(String)
    case installedArtifactsMissing(String)

    var errorDescription: String? {
        switch self {
        case .unknownModel(let modelID):
            return "Unknown model: \(modelID)."
        case .installedArtifactsMissing(let modelID):
            return "Model artifacts are missing for \(modelID)."
        }
    }
}

@MainActor
final class WhisperModelManager: ObservableObject {
    @Published private(set) var models: [WhisperModelDescriptor] = WhisperModelDescriptor.curated
    @Published private(set) var installedModelIDs: Set<String> = []
    @Published private(set) var defaultModelID: String = OpenAurisConstants.defaultModelID
    @Published private(set) var downloadProgress: [String: Double] = [:]
    @Published private(set) var downloadStateByModelID: [String: String] = [:]

    private let repository: AppRepository
    private var installTasks: [String: Task<Void, Error>] = [:]

    init(repository: AppRepository) {
        self.repository = repository
        reloadFromStore()
    }

    func reloadFromStore() {
        guard let stored = try? repository.fetchModels() else {
            return
        }

        downloadStateByModelID = Dictionary(uniqueKeysWithValues: stored.map { ($0.modelID, $0.downloadState) })
        defaultModelID = stored.first(where: { $0.isDefault })?.modelID ?? OpenAurisConstants.defaultModelID

        var validatedInstalledIDs = Set<String>()
        for model in stored {
            if model.installedAt != nil && hasValidCachedArtifacts(for: model.modelID) {
                validatedInstalledIDs.insert(model.modelID)
                downloadStateByModelID[model.modelID] = "installed"
                continue
            }

            if model.installedAt != nil || model.downloadState == "installed" {
                try? repository.upsertModel(
                    modelID: model.modelID,
                    displayName: model.displayName,
                    sizeBytes: model.sizeBytes,
                    state: "not_installed",
                    isDefault: model.isDefault,
                    installedAt: nil,
                    lastUsedAt: nil,
                    overwriteInstalledAt: true,
                    overwriteLastUsedAt: true
                )
                downloadStateByModelID[model.modelID] = "not_installed"
            }
        }

        installedModelIDs = validatedInstalledIDs
    }

    func installDefaultModelIfNeeded() async {
        do {
            _ = try await ensureModelInstalled(defaultModelID)
        } catch {
            // Keep app responsive if install fails; dashboard exposes retry controls.
        }
    }

    func ensureModelInstalled(_ modelID: String) async throws -> String {
        guard let descriptor = models.first(where: { $0.id == modelID }) else {
            throw WhisperModelManagerError.unknownModel(modelID)
        }

        if installedModelIDs.contains(modelID) && !hasValidCachedArtifacts(for: modelID) {
            installedModelIDs.remove(modelID)
            downloadStateByModelID[modelID] = "not_installed"
        }

        try await install(model: descriptor)

        guard let folderPath = resolvedModelFolderPath(for: modelID) else {
            throw WhisperModelManagerError.installedArtifactsMissing(modelID)
        }

        return folderPath
    }

    func reinstall(modelID: String) async throws {
        guard let descriptor = models.first(where: { $0.id == modelID }) else {
            throw WhisperModelManagerError.unknownModel(modelID)
        }

        if let existingTask = installTasks[modelID] {
            _ = try? await existingTask.value
        }

        removeCachedArtifacts(for: modelID)
        installedModelIDs.remove(modelID)
        downloadProgress.removeValue(forKey: modelID)
        downloadStateByModelID[modelID] = "not_installed"

        try repository.upsertModel(
            modelID: descriptor.id,
            displayName: descriptor.displayName,
            sizeBytes: descriptor.estimatedSizeBytes,
            state: "not_installed",
            isDefault: descriptor.id == defaultModelID,
            installedAt: nil,
            lastUsedAt: nil,
            overwriteInstalledAt: true,
            overwriteLastUsedAt: true
        )

        try await install(model: descriptor)
    }

    func install(model: WhisperModelDescriptor) async throws {
        if installedModelIDs.contains(model.id) {
            return
        }

        if let existingTask = installTasks[model.id] {
            try await existingTask.value
            return
        }

        let installTask = Task { @MainActor in
            try await self.performInstall(model: model)
        }
        installTasks[model.id] = installTask
        defer { installTasks[model.id] = nil }

        do {
            try await installTask.value
        } catch {
            downloadProgress.removeValue(forKey: model.id)
            downloadStateByModelID[model.id] = "not_installed"
            try? repository.upsertModel(
                modelID: model.id,
                displayName: model.displayName,
                sizeBytes: model.estimatedSizeBytes,
                state: "not_installed",
                isDefault: model.id == defaultModelID,
                installedAt: nil,
                lastUsedAt: nil,
                overwriteInstalledAt: true,
                overwriteLastUsedAt: true
            )
            throw error
        }
    }

    private func performInstall(model: WhisperModelDescriptor) async throws {
        downloadStateByModelID[model.id] = "downloading"
        try repository.upsertModel(
            modelID: model.id,
            displayName: model.displayName,
            sizeBytes: model.estimatedSizeBytes,
            state: "downloading",
            isDefault: model.id == defaultModelID,
            installedAt: nil,
            overwriteInstalledAt: true
        )
        downloadProgress[model.id] = 0

        _ = try await WhisperKit.download(variant: model.id) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress[model.id] = progress.fractionCompleted
            }
        }

        try repository.upsertModel(
            modelID: model.id,
            displayName: model.displayName,
            sizeBytes: model.estimatedSizeBytes,
            state: "installed",
            isDefault: model.id == defaultModelID,
            installedAt: Date(),
            lastUsedAt: nil
        )

        installedModelIDs.insert(model.id)
        downloadStateByModelID[model.id] = "installed"
        downloadProgress[model.id] = 1
    }

    private func removeCachedArtifacts(for modelID: String) {
        let cachedFolders = cachedModelFolders(for: modelID)
        for url in cachedFolders {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func setDefaultModel(_ modelID: String) {
        defaultModelID = modelID

        for model in models {
            do {
                try repository.upsertModel(
                    modelID: model.id,
                    displayName: model.displayName,
                    sizeBytes: model.estimatedSizeBytes,
                    state: installedModelIDs.contains(model.id) ? "installed" : "not_installed",
                    isDefault: model.id == modelID
                )
                downloadStateByModelID[model.id] = installedModelIDs.contains(model.id) ? "installed" : "not_installed"
            } catch {
                continue
            }
        }
    }

    func remove(modelID: String) {
        guard modelID != defaultModelID else { return }
        installedModelIDs.remove(modelID)
        downloadProgress.removeValue(forKey: modelID)
        downloadStateByModelID[modelID] = "not_installed"
        removeCachedArtifacts(for: modelID)

        if let descriptor = models.first(where: { $0.id == modelID }) {
            do {
                try repository.upsertModel(
                    modelID: modelID,
                    displayName: descriptor.displayName,
                    sizeBytes: descriptor.estimatedSizeBytes,
                    state: "not_installed",
                    isDefault: false,
                    installedAt: nil,
                    lastUsedAt: nil,
                    overwriteInstalledAt: true,
                    overwriteLastUsedAt: true
                )
            } catch {
                return
            }
        }
    }

    func isModelInstalled(_ modelID: String) -> Bool {
        installedModelIDs.contains(modelID)
    }

    func isModelDownloading(_ modelID: String) -> Bool {
        if let progress = downloadProgress[modelID], progress < 1 {
            return true
        }
        return downloadStateByModelID[modelID] == "downloading"
    }

    func modelFolderPathIfAvailable(_ modelID: String) -> String? {
        resolvedModelFolderPath(for: modelID)
    }

    private func hasValidCachedArtifacts(for modelID: String) -> Bool {
        for folder in cachedModelFolders(for: modelID) {
            if hasRequiredArtifacts(in: folder) {
                return true
            }
        }

        return false
    }

    private func resolvedModelFolderPath(for modelID: String) -> String? {
        cachedModelFolders(for: modelID)
            .first(where: { hasRequiredArtifacts(in: $0) })
            .map(\.path)
    }

    private func hasRequiredArtifacts(in folder: URL) -> Bool {
        let requiredRelativePaths = [
            "AudioEncoder.mlmodelc/weights/weight.bin",
            "MelSpectrogram.mlmodelc/weights/weight.bin",
            "TextDecoder.mlmodelc/weights/weight.bin"
        ]

        for relativePath in requiredRelativePaths {
            let artifactURL = folder.appending(path: relativePath)
            guard
                let attributes = try? FileManager.default.attributesOfItem(atPath: artifactURL.path),
                let fileSize = attributes[.size] as? NSNumber,
                fileSize.intValue > 0
            else {
                return false
            }
        }

        return true
    }

    private func cachedModelFolders(for modelID: String) -> [URL] {
        let cacheRoot = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/huggingface/models/argmaxinc/whisperkit-coreml", directoryHint: .isDirectory)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let marker = "whisper-\(modelID.lowercased())"
        return contents.filter { $0.lastPathComponent.lowercased().contains(marker) }
    }
}
