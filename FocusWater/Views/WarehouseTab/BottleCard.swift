import SwiftUI

struct BottleCard: View {
    let bottle: WaterBottle
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 10) {
            BottleCanvas(
                progress: 1,
                serialNumber: bottle.serialNumber,
                isCompleted: true,
                size: CGSize(width: 72, height: 120)
            )
            .frame(width: 72, height: 120)

            VStack(spacing: 3) {
                Text("#\(bottle.serialNumber)")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.primaryText)

                if let date = bottle.completedAt {
                    Text(date.formatted(.dateTime.month(.abbreviated).day().locale(language.locale)))
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                Text(formattedCapacity)
                    .font(.caption2)
                    .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }

    private var formattedCapacity: String {
        if bottle.capacityMinutes >= 60 {
            let hours = bottle.capacityMinutes / 60
            let minutes = bottle.capacityMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
        }
        return "\(bottle.capacityMinutes)m"
    }
}
