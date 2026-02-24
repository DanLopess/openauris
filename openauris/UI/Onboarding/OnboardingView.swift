import SwiftUI

struct OnboardingView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var pageIndex = 0
    @State private var microphoneGrantedLocal = false
    @State private var requestingMicrophone = false
    @State private var microphoneHint: String?
    private let totalPages = 6

    var body: some View {
        VStack(spacing: 18) {
            ProgressView(value: Double(pageIndex + 1), total: Double(totalPages))
                .progressViewStyle(.linear)

            currentPage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.18), value: pageIndex)

            HStack {
                Text("Step \(pageIndex + 1) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                if pageIndex > 0 {
                    Button("Back") {
                        pageIndex -= 1
                    }
                }

                Spacer()

                if pageIndex < 5 {
                    Button("Continue") {
                        pageIndex += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Using OpenAuris") {
                        container.completeOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.cyan.opacity(0.12), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            container.permissionManager.refresh()
            microphoneGrantedLocal = container.permissionManager.microphoneGranted
            microphoneHint = nil
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch pageIndex {
        case 0: welcome
        case 1: microphone
        case 2: modelSetup
        case 3: accessibility
        case 4: shortcuts
        default: ready
        }
    }

    private var welcome: some View {
        onboardingPage(
            title: "Welcome to OpenAuris",
            subtitle: "Private local dictation built for Apple Silicon.",
            body: {
                Text("OpenAuris keeps audio and transcripts on-device. No cloud upload, no lock-in.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        )
    }

    private var microphone: some View {
        onboardingPage(
            title: "Microphone Permission",
            subtitle: "Required for dictation.",
            body: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(microphoneGrantedLocal ? "Granted" : "Not granted", systemImage: microphoneGrantedLocal ? "checkmark.seal.fill" : "exclamationmark.triangle")
                        .foregroundStyle(microphoneGrantedLocal ? .green : .orange)

                    HStack {
                        Button(requestingMicrophone ? "Requesting..." : "Request Microphone Access") {
                            Task {
                                requestingMicrophone = true
                                let granted = await container.permissionManager.requestMicrophone()
                                container.permissionManager.refresh()
                                microphoneGrantedLocal = container.permissionManager.microphoneGranted
                                requestingMicrophone = false

                                if granted {
                                    microphoneHint = "Microphone access granted."
                                } else {
                                    microphoneHint = "If prompted permission was dismissed/denied, open Settings and enable Microphone for OpenAuris."
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(requestingMicrophone || microphoneGrantedLocal)

                        Button("Open Settings") {
                            container.permissionManager.openMicrophoneSettings()
                        }
                        .buttonStyle(.bordered)
                    }

                    if let microphoneHint {
                        Text(microphoneHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        )
    }

    private var modelSetup: some View {
        let defaultModelID = container.modelManager.defaultModelID
        let isInstalled = container.modelManager.isModelInstalled(defaultModelID)
        let isDownloading = container.modelManager.isModelDownloading(defaultModelID)
        let progress = container.modelManager.downloadProgress[defaultModelID]
        let effectivelyInstalled = isInstalled || (progress ?? 0) >= 1.0

        return onboardingPage(
            title: "Model Auto-Download",
            subtitle: "The default balanced model installs automatically.",
            body: {
                VStack(alignment: .leading, spacing: 8) {
                    if effectivelyInstalled {
                        Label("Default model is installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if isDownloading && !effectivelyInstalled {
                        if let progress {
                            ProgressView("Downloading...", value: progress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView("Preparing model...")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if !effectivelyInstalled {
                        Button("Download Default Model") {
                            Task {
                                await container.modelManager.installDefaultModelIfNeeded()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if !effectivelyInstalled && !isDownloading {
                        Text("The app should auto-download this on first launch. If it failed, use the button above to retry.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        )
    }

    private var accessibility: some View {
        onboardingPage(
            title: "Accessibility Permission",
            subtitle: "Improves direct insertion into other apps.",
            body: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(container.permissionManager.accessibilityGranted ? "Granted" : "Not granted", systemImage: container.permissionManager.accessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle")
                        .foregroundStyle(container.permissionManager.accessibilityGranted ? .green : .orange)

                    HStack {
                        Button("Request Access") {
                            container.permissionManager.requestAccessibilityPrompt()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open Settings") {
                            container.permissionManager.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        )
    }

    private var shortcuts: some View {
        onboardingPage(
            title: "Shortcut Defaults",
            subtitle: "You can change these in Settings any time.",
            body: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hold to speak: ⌃⌥Space")
                    Text("Toggle start/stop: ⌃⌥Return")
                }
                .font(.body.monospaced())
            }
        )
    }

    private var ready: some View {
        onboardingPage(
            title: "You’re Ready",
            subtitle: "Open the dashboard and start dictating.",
            body: {
                Text("Use your hold or toggle shortcut from any app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        )
    }

    private func onboardingPage<Content: View>(title: String, subtitle: String, @ViewBuilder body: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            AppBrandLogo(size: 54)

            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            body()

            Spacer()
        }
        .padding(8)
    }
}
