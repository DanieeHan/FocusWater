import SwiftData
import SwiftUI

struct WarehouseView: View {
    var viewModel: FocusViewModel
    @State private var selectedBottle: WaterBottle?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 156), spacing: 16)]

    private var language: AppLanguage {
        viewModel.appLanguage
    }

    private var compactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(language == .zhHans ? "把专注，收藏起来。" : "A collection of focus.")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(language == .zhHans ? "每一瓶，都是你真实投入的时间。" : "Every bottle holds time you truly invested.")
                        .font(.callout).foregroundStyle(Color.secondaryText)
                }.padding(.horizontal)
                summaryCards
                    .padding(.horizontal)

                if viewModel.completedBottles.isEmpty {
                    emptyState
                        .padding(.horizontal)
                        .padding(.top, 44)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.completedBottles.sorted(by: { $0.serialNumber > $1.serialNumber })) {
                            bottle in
                            Button {
                                selectedBottle = bottle
                            } label: {
                                BottleCard(bottle: bottle, language: language)
                            }.buttonStyle(.plain)
                                .accessibilityLabel(
                                    language == .zhHans
                                        ? "查看第 \(bottle.serialNumber) 瓶水" : "View bottle \(bottle.serialNumber)")
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .platformMinFrame(width: 380, height: 500)
        .background(Color.appBackgroundGradient.ignoresSafeArea())
        .sheet(item: $selectedBottle) { bottle in
            bottleDetailView(bottle)
                .presentationDetents(compactLayout ? [.large] : [.fraction(0.72)])
        }
    }

    private var summaryCards: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    summaryCardFilled
                    summaryCardFocus
                    summaryCardStreak
                }
            } else if compactLayout {
                VStack(spacing: 12) {
                    summaryCardFilled
                    HStack(spacing: 12) {
                        summaryCardFocus
                        summaryCardStreak
                    }
                }
            } else {
                HStack(spacing: 12) {
                    summaryCardFilled
                    summaryCardFocus
                    summaryCardStreak
                }
            }
        }
    }

    private var summaryCardFilled: some View {
        StatCard(
            icon: "drop.fill",
            iconColor: .accentBlue,
            value: "\(viewModel.totalBottles)",
            label: AppLocalizer.text(.fullBottleCount, language)
        )
    }

    private var summaryCardFocus: some View {
        StatCard(
            icon: "clock.fill",
            iconColor: .neutralIcon,
            value: String(format: "%.1f h", viewModel.totalFocusHours),
            label: AppLocalizer.text(.totalFocus, language)
        )
    }

    private var summaryCardStreak: some View {
        StatCard(
            icon: "calendar",
            iconColor: .neutralIcon,
            value: "\(viewModel.consecutiveDays)",
            label: AppLocalizer.text(.consecutiveDays, language)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.tertiaryText)
            Text(AppLocalizer.text(.warehouseEmpty, language))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(Color.primaryText)
            Text(AppLocalizer.text(.warehouseEmptySubtitle, language))
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }

    private func bottleDetailView(_ bottle: WaterBottle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detailTitle(for: bottle))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryText)
                        if let date = bottle.completedAt {
                            Text(
                                "\(AppLocalizer.text(.completedAt, language)) \(date.formatted(.dateTime.month(.wide).day().hour().minute().locale(language.locale)))"
                            )
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        }
                    }
                    Spacer()
                    Button(AppLocalizer.text(.close, language)) {
                        selectedBottle = nil
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondaryButtonFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.cardStroke, lineWidth: 1)
                            )
                    )
                }

                Divider()
                    .overlay(Color.separatorLine)

                if let sessions = bottle.sessions, !sessions.isEmpty {
                    Text(AppLocalizer.text(.focusRecords, language))
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    ForEach(sessions.sorted(by: { $0.date > $1.date })) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Color.accentBlue)
                                Text(
                                    session.date.formatted(
                                        .dateTime.month(.abbreviated).day().hour().minute().locale(language.locale))
                                )
                                .font(.callout)
                                .foregroundStyle(Color.secondaryText)
                                Spacer()
                                Text(viewModel.formatMinutes(session.duration))
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(Color.primaryText)
                            }

                            if let note = session.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .padding(.leading, 14)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

            }
            .padding(24)
            .frame(maxWidth: compactLayout ? .infinity : 420, minHeight: compactLayout ? 0 : 420)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackgroundGradient.ignoresSafeArea())
    }

    private func detailTitle(for bottle: WaterBottle) -> String {
        switch language {
        case .zhHans:
            return "第 \(bottle.serialNumber) 瓶水"
        case .english:
            return "Bottle #\(bottle.serialNumber)"
        }
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(Color.primaryText)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }
}
