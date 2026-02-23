import SwiftUI

struct StatsDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Stats")
                .font(.largeTitle.bold())

            Text("Streak day threshold: \(OpenAurisConstants.minimumDailyWordsForStreak) words")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(container.dailyStats) { day in
                HStack {
                    VStack(alignment: .leading) {
                        Text(day.date, style: .date)
                            .font(.headline)
                        Text(day.streakQualified ? "Streak qualified" : "Below streak threshold")
                            .font(.caption)
                            .foregroundStyle(day.streakQualified ? .green : .secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(day.words) words")
                        Text(String(format: "%.0f WPM", day.avgWPM))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }
}
