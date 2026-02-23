import Combine
import Foundation

#if canImport(WhisperKit)
import WhisperKit
#endif

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

@MainActor
final class WhisperModelManager: ObservableObject {
    @Published private(set) var models: [WhisperModelDescriptor] = WhisperModelDescriptor.curated
    @Published private(set) var installedModelIDs: Set<String> = []
    @Published private(set) var defaultModelID: String = OpenAurisConstants.defaultModelID
    @Published private(set) var downloadProgress: [String: Double] = [:]

    private let repository: AppRepository

    init(repository: AppRepository) {
        self.repository = repository
        reloadFromStore()
    }

    func reloadFromStore() {
        guard let stored = try? repository.fetchModels() else {
            return
        }

        installedModelIDs = Set(stored.filter { $0.installedAt != nil }.map(\.modelID))
        defaultModelID = stored.first(where: { $0.isDefault })?.modelID ?? OpenAurisConstants.defaultModelID
    }

    func installDefaultModelIfNeeded() async {
        if installedModelIDs.contains(defaultModelID) {
            return
        }

        guard let descriptor = models.first(where: { $0.id == defaultModelID }) else {
            return
        }

        do {
            try await install(model: descriptor)
        } catch {
            // Keep app responsive if install fails; dashboard exposes retry controls.
        }
    }

    func install(model: WhisperModelDescriptor) async throws {
        try repository.upsertModel(
            modelID: model.id,
            displayName: model.displayName,
            sizeBytes: model.estimatedSizeBytes,
            state: "downloading",
            isDefault: model.id == defaultModelID
        )
        downloadProgress[model.id] = 0

        #if canImport(WhisperKit)
        _ = try await WhisperKit.download(variant: model.id) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress[model.id] = progress.fractionCompleted
            }
        }
        #else
        for step in 1...20 {
            try await Task.sleep(nanoseconds: 120_000_000)
            downloadProgress[model.id] = Double(step) / 20.0
        }
        #endif

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
        downloadProgress[model.id] = 1
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
            } catch {
                continue
            }
        }
    }

    func remove(modelID: String) {
        guard modelID != defaultModelID else { return }
        installedModelIDs.remove(modelID)

        if let descriptor = models.first(where: { $0.id == modelID }) {
            do {
                try repository.upsertModel(
                    modelID: modelID,
                    displayName: descriptor.displayName,
                    sizeBytes: descriptor.estimatedSizeBytes,
                    state: "not_installed",
                    isDefault: false,
                    installedAt: nil,
                    lastUsedAt: nil
                )
            } catch {
                return
            }
        }
    }
}
