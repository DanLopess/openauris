import AppKit
import SwiftUI

private enum ActivitySort: String, CaseIterable, Identifiable {
    case newest
    case words
    case speed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .words: return "Most words"
        case .speed: return "Fastest WPM"
        }
    }
}

struct HistoryDashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var searchQuery = ""
    @State private var debouncedSearchQuery = ""
    @State private var selectedMode = "all"
    @State private var selectedModel = "all"
    @State private var selectedLanguage = "all"
    @State private var sort: ActivitySort = .newest
    @State private var expandedIDs = Set<UUID>()
    @State private var pendingDelete: DictationSessionEntity?
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Activity",
                    subtitle: "Review transcripts with filters and fast follow-up actions."
                )

                controls

                if filteredSessions.isEmpty {
                    DashboardEmptyState(
                        title: "No matching transcripts",
                        subtitle: "Try adjusting filters or run a new dictation session.",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSessions) { session in
                            activityRow(session)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DashboardTheme.pagePadding)
        }
        .confirmationDialog("Delete this transcript?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let pendingDelete else { return }
                container.deleteSession(pendingDelete)
                self.pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Clear all history and metrics?", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                container.clearAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes sessions, daily stats, and milestones progress.")
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(250))
            debouncedSearchQuery = searchQuery
        }
    }

    private var controls: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Search transcripts", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)

                    Picker("Sort", selection: $sort) {
                        ForEach(ActivitySort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Clear History", systemImage: "trash", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }

                filterChips
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            chipGroup(
                label: "Mode",
                selection: $selectedMode,
                options: ["all"] + uniqueModes
            )
            chipGroup(
                label: "Model",
                selection: $selectedModel,
                options: ["all"] + uniqueModels
            )
            chipGroup(
                label: "Language",
                selection: $selectedLanguage,
                options: ["all"] + uniqueLanguages
            )
        }
    }

    private func chipGroup(label: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(optionTitle(option)) {
                    selection.wrappedValue = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                Text(optionTitle(selection.wrappedValue))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .dashboardGlassCard(cornerRadius: 10, interactive: true)
        }
        .menuStyle(.button)
    }

    private func activityRow(_ session: DictationSessionEntity) -> some View {
        let isExpanded = expandedIDs.contains(session.id)

        return DashboardCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.endedAt, format: .dateTime.day().month().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(session.finalText)
                            .font(.body)
                            .lineLimit(isExpanded ? nil : 2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(session.wordCount) words")
                            .font(.caption.weight(.semibold))
                        Text("\(session.wpm.formatted(.number.precision(.fractionLength(0)))) WPM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    DashboardStatusPill(text: session.modeRawValue, color: .blue)
                    DashboardStatusPill(text: session.modelID, color: .mint)
                    DashboardStatusPill(text: session.languageCode.uppercased(), color: .indigo)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Button(isExpanded ? "Collapse" : "Expand", systemImage: "text.alignleft") {
                        toggleExpansion(for: session.id)
                    }
                    .buttonStyle(.bordered)

                    Button("Copy", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.finalText, forType: .string)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingDelete = session
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var filteredSessions: [DictationSessionEntity] {
        var sessions = container.sessions

        let normalized = debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            sessions = sessions.filter { $0.finalText.localizedStandardContains(normalized) }
        }

        if selectedMode != "all" {
            sessions = sessions.filter { $0.modeRawValue == selectedMode }
        }

        if selectedModel != "all" {
            sessions = sessions.filter { $0.modelID == selectedModel }
        }

        if selectedLanguage != "all" {
            sessions = sessions.filter { $0.languageCode == selectedLanguage }
        }

        switch sort {
        case .newest:
            sessions.sort { $0.endedAt > $1.endedAt }
        case .words:
            sessions.sort { $0.wordCount > $1.wordCount }
        case .speed:
            sessions.sort { $0.wpm > $1.wpm }
        }

        return sessions
    }

    private var uniqueModes: [String] {
        Array(Set(container.sessions.map(\.modeRawValue))).sorted()
    }

    private var uniqueModels: [String] {
        Array(Set(container.sessions.map(\.modelID))).sorted()
    }

    private var uniqueLanguages: [String] {
        Array(Set(container.sessions.map(\.languageCode))).sorted()
    }

    private func optionTitle(_ value: String) -> String {
        value == "all" ? "All" : value
    }

    private func toggleExpansion(for id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
}
