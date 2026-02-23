import SwiftUI

struct HistoryDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.largeTitle.bold())

            HStack {
                TextField("Search transcripts", text: $container.searchQuery)
                    .textFieldStyle(.roundedBorder)

                Button("Clear History", role: .destructive) {
                    container.clearAllHistory()
                }
            }

            List(container.sessions) { session in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(session.endedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.endedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(session.wordCount) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(session.finalText)
                        .font(.body)
                        .lineLimit(3)

                    HStack {
                        Text(session.modeRawValue)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())

                        Text(session.modelID)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())

                        Spacer()

                        Button("Delete", role: .destructive) {
                            container.deleteSession(session)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }
}
