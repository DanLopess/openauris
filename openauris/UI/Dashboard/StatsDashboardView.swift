import SwiftUI

struct StatsDashboardView: View {
    @Environment(AppContainer.self) private var container

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
                        Text("\(day.avgWPM.formatted(.number.precision(.fractionLength(0)))) WPM")
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
