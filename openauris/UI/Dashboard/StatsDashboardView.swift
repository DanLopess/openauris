import Charts
import SwiftUI

private enum InsightsMetric: String, CaseIterable, Identifiable {
    case words
    case sessions
    case wpm

    var id: String { rawValue }
}

struct StatsDashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var metric: InsightsMetric = .words
    @State private var rangeDays = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Insights",
                    subtitle: "Monitor trends and consistency over the last 7 or 30 days."
                )

                controls
                summaryCards
                trendChart
                topApps
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DashboardTheme.pagePadding)
        }
    }

    private var controls: some View {
        DashboardCard {
            HStack {
                Picker("Window", selection: $rangeDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Spacer()

                Picker("Metric", selection: $metric) {
                    Text("Words").tag(InsightsMetric.words)
                    Text("Sessions").tag(InsightsMetric.sessions)
                    Text("WPM").tag(InsightsMetric.wpm)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            DashboardMetricCard(
                title: "Total Words",
                value: "\(filteredStats.reduce(0) { $0 + $1.words })",
                caption: "In selected window",
                accent: .cyan
            )
            DashboardMetricCard(
                title: "Sessions",
                value: "\(filteredStats.reduce(0) { $0 + $1.sessions })",
                caption: "Captured days included",
                accent: .blue
            )
            DashboardMetricCard(
                title: "Avg WPM",
                value: averageWPM.formatted(.number.precision(.fractionLength(0))),
                caption: "Daily average speed",
                accent: .mint
            )
        }
    }

    private var trendChart: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Trend")
                    .font(.headline)

                if filteredStats.isEmpty {
                    Text("No data in this range yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(filteredStats, id: \.date) { day in
                        LineMark(
                            x: .value("Day", day.date),
                            y: .value("Value", metricValue(for: day))
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.cyan)

                        AreaMark(
                            x: .value("Day", day.date),
                            y: .value("Value", metricValue(for: day))
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.cyan.opacity(0.18))
                    }
                    .frame(height: 220)
                }
            }
        }
    }

    private var topApps: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Top Target Apps")
                    .font(.headline)
                    .foregroundStyle(.indigo.gradient)

                if topTargetApps.isEmpty {
                    Text("No app activity in this range.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(topTargetApps.prefix(5).enumerated()), id: \.element.bundleID) { index, app in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(accentColor(for: index))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(accentColor(for: index))

                                if app.bundleID.lowercased() != "unknown" {
                                    Text(app.bundleID)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(app.sessionCount) sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(app.totalWords) words")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var filteredStats: [DailyStatsEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(max(1, rangeDays) - 1), to: today) ?? .distantPast
        return container.dailyStats
            .filter { calendar.startOfDay(for: $0.date) >= start }
            .sorted { $0.date < $1.date }
    }

    private var averageWPM: Double {
        guard !filteredStats.isEmpty else { return 0 }
        return filteredStats.reduce(0) { $0 + $1.avgWPM } / Double(filteredStats.count)
    }

    private func metricValue(for day: DailyStatsEntity) -> Double {
        switch metric {
        case .words:
            return Double(day.words)
        case .sessions:
            return Double(day.sessions)
        case .wpm:
            return day.avgWPM
        }
    }

    private var topTargetApps: [TopTargetAppUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(max(1, rangeDays) - 1), to: today) ?? .distantPast
        let sessions = container.sessions.filter { calendar.startOfDay(for: $0.endedAt) >= start }

        var map: [String: (sessionCount: Int, totalWords: Int, lastUsedAt: Date)] = [:]
        for session in sessions {
            let key = session.targetBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unknown" : session.targetBundleID
            var current = map[key] ?? (0, 0, .distantPast)
            current.sessionCount += 1
            current.totalWords += session.wordCount
            current.lastUsedAt = max(current.lastUsedAt, session.endedAt)
            map[key] = current
        }

        return map.map { key, value in
            TopTargetAppUsage(
                bundleID: key,
                sessionCount: value.sessionCount,
                totalWords: value.totalWords,
                lastUsedAt: value.lastUsedAt
            )
        }
        .sorted {
            if $0.sessionCount != $1.sessionCount {
                return $0.sessionCount > $1.sessionCount
            }
            return $0.totalWords > $1.totalWords
        }
    }

    private func accentColor(for rank: Int) -> Color {
        switch rank {
        case 0:
            return .indigo
        case 1:
            return .blue
        case 2:
            return .teal
        default:
            return .cyan
        }
    }
}
