import SwiftUI

struct ModelsDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Whisper Models")
                .font(.largeTitle.bold())

            Text("Models download automatically and stay local on your Mac.")
                .foregroundStyle(.secondary)

            List(container.modelManager.models) { model in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(model.displayName)
                                .font(.headline)
                            if model.id == container.modelManager.defaultModelID {
                                Text("Default")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.thinMaterial, in: Capsule())
                            }
                        }

                        Text(model.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(ByteCountFormatter.string(fromByteCount: model.estimatedSizeBytes, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if container.modelManager.installedModelIDs.contains(model.id) {
                        Button("Make Default") {
                            container.makeDefaultModel(model.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.id == container.modelManager.defaultModelID)

                        if model.id != container.modelManager.defaultModelID {
                            Button("Remove", role: .destructive) {
                                container.modelManager.remove(modelID: model.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        if let progress = container.modelManager.downloadProgress[model.id], progress < 1 {
                            ProgressView(value: progress)
                                .frame(width: 120)
                        } else {
                            Button("Download") {
                                container.requestModelInstall(model)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.inset)
        }
    }
}
