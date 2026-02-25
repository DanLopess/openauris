import SwiftUI

struct ModelsDashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var pendingRemoveModelID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Models",
                    subtitle: "Manage on-device Whisper models, default selection, and lifecycle state."
                )

                LazyVStack(spacing: 12) {
                    ForEach(container.modelManager.models) { model in
                        modelCard(for: model)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DashboardTheme.pagePadding)
        }
        .confirmationDialog(
            "Remove this model from local storage?",
            isPresented: Binding(
                get: { pendingRemoveModelID != nil },
                set: { if !$0 { pendingRemoveModelID = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                guard let pendingRemoveModelID else { return }
                container.modelManager.remove(modelID: pendingRemoveModelID)
                self.pendingRemoveModelID = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func modelCard(for model: WhisperModelDescriptor) -> some View {
        let isInstalled = container.modelManager.isModelInstalled(model.id)
        let isDownloading = container.modelManager.isModelDownloading(model.id)
        let progress = container.modelManager.downloadProgress[model.id]
        let isDefault = model.id == container.modelManager.defaultModelID

        return DashboardCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .font(.title3.weight(.bold))

                        if isDefault {
                            DashboardStatusPill(text: "Default", color: .cyan)
                        }

                        DashboardStatusPill(
                            text: stateLabel(isInstalled: isInstalled, isDownloading: isDownloading),
                            color: stateColor(isInstalled: isInstalled, isDownloading: isDownloading)
                        )
                    }

                    Text(model.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(ByteCountFormatter.string(fromByteCount: model.estimatedSizeBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isDownloading {
                        ProgressView(value: progress ?? 0)
                            .frame(maxWidth: 200)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if isDownloading {
                        Text("Downloading...")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if isInstalled {
                        Button("Make Default") {
                            container.makeDefaultModel(model.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isDefault)

                        Button("Reinstall", systemImage: "arrow.triangle.2.circlepath") {
                            Task {
                                do {
                                    try await container.modelManager.reinstall(modelID: model.id)
                                } catch {
                                    container.startupErrorMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.bordered)

                        if !isDefault {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                pendingRemoveModelID = model.id
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Download", systemImage: "arrow.down.circle.fill") {
                            container.requestModelInstall(model)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func stateLabel(isInstalled: Bool, isDownloading: Bool) -> String {
        if isDownloading { return "Downloading" }
        return isInstalled ? "Installed" : "Not Installed"
    }

    private func stateColor(isInstalled: Bool, isDownloading: Bool) -> Color {
        if isDownloading { return .orange }
        return isInstalled ? .green : .secondary
    }
}
