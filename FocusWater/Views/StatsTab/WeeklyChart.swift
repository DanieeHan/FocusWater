import Charts
import SwiftUI

struct WeeklyChart: View {
    let data: [(day: String, minutes: Int)]
    let dailyGoalMinutes: Int
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalizer.text(.weeklyTrend, language))
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Chart {
                ForEach(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentBlue.opacity(0.58), .accentBlue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                RuleMark(y: .value("Goal", dailyGoalMinutes))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5]))
                    .foregroundStyle(Color.tertiaryText.opacity(0.72))
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.secondaryText)
                    AxisGridLine()
                        .foregroundStyle(Color.separatorLine)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .frame(height: 184)
            .accessibilityLabel(AppLocalizer.text(.weeklyTrend, language))

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.tertiaryText.opacity(0.72))
                    .frame(width: 10, height: 4)
                Text("\(AppLocalizer.text(.goalLegend, language)) \(goalLabel)")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }

    private var goalLabel: String {
        if dailyGoalMinutes >= 60 {
            let hours = dailyGoalMinutes / 60
            let minutes = dailyGoalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
        }
        return "\(dailyGoalMinutes)m"
    }
}
