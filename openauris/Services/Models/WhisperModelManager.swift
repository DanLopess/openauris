import Foundation
import Observation

import WhisperKit

struct WhisperModelDescriptor: Identifiable, Sendable {
    let id: String
    let displayName: String
    let estimatedSizeBytes: Int64
    let description: String

    static let curated: [WhisperModelDescriptor] = [
        WhisperModelDescriptor(id: "tiny", displayName: "Tiny", estimatedSizeBytes: 150_000_000, description: "Fastest, lower accuracy. Recommended only for English speakers."),
        WhisperModelDescriptor(id: "small", displayName: "Small", estimatedSizeBytes: 500_000_000, description: "Balanced for speed and quality."),
        WhisperModelDescriptor(id: "medium", displayName: "Medium", estimatedSizeBytes: 1_500_000_000, description: "Higher quality, heavier memory usage.")
    ]
}

enum WhisperModelManagerError: LocalizedError {
    case unknownModel(String)
    case installedArtifactsMissing(String)
    case modelDeletionFailed(modelID: String, underlyingErrors: [Error])
    case cannotDeleteDefaultModel
    case modelDeletionValidationFailed(modelID: String)

    var errorDescription: String? {
        switch self {
        case .unknownModel(let modelID):
            return "Unknown model: \(modelID)."
        case .installedArtifactsMissing(let modelID):
            return "Model artifacts are missing for \(modelID)."
        case .modelDeletionFailed(let modelID, _):
            return "Failed to delete model '\(modelID)'. Some files may remain."
        case .cannotDeleteDefaultModel:
            return "Cannot delete the default model. Set another model as default first."
        case .modelDeletionValidationFailed(let modelID):
            return "Model '\(modelID)' deletion validation failed."
        }
    }
}

@MainActor
@Observable
final class WhisperModelManager {
    private(set) var models: [WhisperModelDescriptor] = WhisperModelDescriptor.curated
    private(set) var installedModelIDs: Set<String> = []
    private(set) var defaultModelID: String = OpenAurisConstants.defaultModelID
    private(set) var downloadProgress: [String: Double] = [:]
    private(set) var downloadStateByModelID: [String: String] = [:]
    private(set) var downloadErrorByModelID: [String: String] = [:]

    var downloadBasePath: String?

    private var resolvedDownloadBase: URL {
        WhisperModelManager.downloadBase(for: downloadBasePath)
    }

    nonisolated static func downloadBase(for customPath: String?) -> URL {
        if let custom = customPath {
            return URL(filePath: custom)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appending(path: "OpenAuris/Models", directoryHint: .isDirectory)
    }

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

        try removeCachedArtifacts(for: modelID)
        installedModelIDs.remove(modelID)
        downloadProgress.removeValue(forKey: modelID)
        downloadStateByModelID[modelID] = "not_installed"
        downloadErrorByModelID.removeValue(forKey: modelID)

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

        downloadErrorByModelID.removeValue(forKey: model.id)

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
            downloadErrorByModelID[model.id] = error.localizedDescription
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

        let downloadBase = resolvedDownloadBase
        try FileManager.default.createDirectory(at: downloadBase, withIntermediateDirectories: true)

        // Track download start and network activity confirmation
        let downloadStartTime = Date()
        var hasNetworkActivityStarted = false

        _ = try await WhisperKit.download(variant: model.id, downloadBase: downloadBase) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Only show progress if at 0% or network activity confirmed
                if progress.fractionCompleted == 0 {
                    // Always allow 0% progress
                    self.downloadProgress[model.id] = 0
                } else if hasNetworkActivityStarted {
                    // Show progress if network activity confirmed
                    self.downloadProgress[model.id] = progress.fractionCompleted
                } else {
                    // Check if this is real progress (not cached/buffered)
                    let elapsed = Date().timeIntervalSince(downloadStartTime)
                    if elapsed > 1.0 { // Only consider real after 1 second
                        hasNetworkActivityStarted = true
                        self.downloadProgress[model.id] = progress.fractionCompleted
                    } else {
                        // Keep at 0% until network activity confirmed
                        self.downloadProgress[model.id] = 0
                    }
                }
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

    private func removeCachedArtifacts(for modelID: String) throws {
        let cachedFolders = cachedModelFolders(for: modelID)
        
        var fileDeletionErrors: [Error] = []
        
        for url in cachedFolders {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                fileDeletionErrors.append(error)
            }
        }
        
        if !fileDeletionErrors.isEmpty {
            throw WhisperModelManagerError.modelDeletionFailed(
                modelID: modelID,
                underlyingErrors: fileDeletionErrors
            )
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

    func remove(modelID: String) throws {
        guard modelID != defaultModelID else {
            throw WhisperModelManagerError.cannotDeleteDefaultModel
        }
        
        guard let descriptor = models.first(where: { $0.id == modelID }) else {
            throw WhisperModelManagerError.unknownModel(modelID)
        }
        
        // Step 1: Delete files
        try removeCachedArtifacts(for: modelID)
        
        // Step 2: Update database
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
        
        // Step 3: Update in-memory state (only if everything succeeded)
        installedModelIDs.remove(modelID)
        downloadProgress.removeValue(forKey: modelID)
        downloadStateByModelID[modelID] = "not_installed"
        
        // Step 4: Validate deletion
        if !validateModelDeletion(modelID) {
            throw WhisperModelManagerError.modelDeletionValidationFailed(modelID: modelID)
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

    private func validateModelDeletion(_ modelID: String) -> Bool {
        if installedModelIDs.contains(modelID) { return false }
        
        do {
            let models = try repository.fetchModels()
            if let model = models.first(where: { $0.modelID == modelID }), 
               model.downloadState == "installed" {
                return false
            }
        } catch { return false }
        
        if hasValidCachedArtifacts(for: modelID) { return false }
        
        return true
    }

    private func cachedModelFolders(for modelID: String) -> [URL] {
        // WhisperKit stores downloads at <downloadBase>/models/argmaxinc/whisperkit-coreml/
        let cacheRoot = resolvedDownloadBase
            .appending(path: "models/argmaxinc/whisperkit-coreml", directoryHint: .isDirectory)

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
