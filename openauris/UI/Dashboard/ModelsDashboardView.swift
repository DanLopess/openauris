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
                let isInstalled = container.modelManager.isModelInstalled(model.id)
                let isDownloading = container.modelManager.isModelDownloading(model.id)
                let progress = container.modelManager.downloadProgress[model.id]

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

                        if isDownloading {
                            HStack(spacing: 8) {
                                if let progress, progress > 0 {
                                    Text("Downloading \(Int(progress * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Downloading...")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Spacer()

                    if isDownloading {
                        if let progress {
                            ProgressView(value: progress)
                                .frame(width: 140)
                        } else {
                            ProgressView()
                                .frame(width: 140)
                        }
                    } else if isInstalled {
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
                        Button("Download") {
                            container.requestModelInstall(model)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.inset)
        }
    }
}
