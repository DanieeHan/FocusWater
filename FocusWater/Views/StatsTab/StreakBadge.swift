import SwiftUI

struct StreakBadge: View {
    let days: Int
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.controlBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )

                Image(systemName: days > 0 ? "flame.fill" : "flame")
                    .font(.title2)
                    .foregroundStyle(days > 0 ? Color.warningTint : Color.neutralIcon)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primaryText)
                    Text(language == .zhHans ? "天" : "days")
                        .font(.title3)
                        .foregroundStyle(Color.secondaryText)
                }
                Text(days > 0 ? AppLocalizer.text(.streakActive, language) : AppLocalizer.text(.streakInactive, language))
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()
        }
        .padding(18)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }
}
