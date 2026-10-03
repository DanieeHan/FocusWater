import SwiftUI
import UniformTypeIdentifiers

struct StatsView: View {
    var viewModel: FocusViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSession: FocusSession?
    @State private var sessionPendingDeletion: FocusSession?
    @State private var exportDocument = FocusCSVDocument()
    @State private var isExporting = false
    @State private var section = 0
    @State private var searchText = ""
    @State private var visibleCount = 30
    @Environment(\.dynamicTypeSize) private var typeSize

    private var language: AppLanguage {
        viewModel.appLanguage
    }

    private var compactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .zhHans ? "每一段投入，都算数。" : "Every session counts.")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Picker(language == .zhHans ? "记录页面" : "Activity view", selection: $section) {
                        Text(language == .zhHans ? "趋势" : "Overview").tag(0)
                        Text(language == .zhHans ? "全部记录" : "All sessions").tag(1)
                    }.pickerStyle(.segmented)
                }.padding(.horizontal)
                if section == 0 {
                    StreakBadge(days: viewModel.consecutiveDays, language: language)
                        .padding(.horizontal)

                    WeeklyChart(
                        data: viewModel.weeklyData,
                        dailyGoalMinutes: viewModel.dailyGoalMinutes,
                        language: language
                    )
                    .padding(.horizontal)

                    summaryCards
                        .padding(.horizontal)

                    heatmapSection
                        .padding(.horizontal)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.secondaryText)
                        TextField(
                            language == .zhHans ? "搜索备注" : "Search notes", text: $searchText,
                            prompt: Text(language == .zhHans ? "搜索备注" : "Search notes").foregroundStyle(
                                Color.secondaryText)
                        )
                        .textFieldStyle(.plain)
                    }
                    .padding(14).glassCardBackground(cornerRadius: 14).padding(.horizontal)
                    .onChange(of: searchText) { _, _ in visibleCount = 30 }
                }

                recentSessionsSection
                    .padding(.horizontal)
                exportSection.padding(.horizontal)
            }
            .padding(.vertical)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .platformMinFrame(width: 380, height: 500)
        .background(Color.appBackgroundGradient.ignoresSafeArea())
        #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_SCENE"] == "records" { section = 1 }
            }
        #endif
        .sheet(item: $selectedSession) { session in
            EditFocusSessionSheet(session: session, language: language) { date, minutes, note in
                viewModel.updateSession(session, date: date, minutes: minutes, note: note)
            }
        }
        .alert(
            AppLocalizer.text(.deleteSession, language),
            isPresented: Binding(
                get: { sessionPendingDeletion != nil },
                set: { if !$0 { sessionPendingDeletion = nil } }
            )
        ) {
            Button(AppLocalizer.text(.cancel, language), role: .cancel) {
                sessionPendingDeletion = nil
            }
            Button(AppLocalizer.text(.deleteSession, language), role: .destructive) {
                if let sessionPendingDeletion {
                    viewModel.deleteSession(sessionPendingDeletion)
                }
                self.sessionPendingDeletion = nil
            }
        } message: {
            Text(AppLocalizer.text(.deleteSessionConfirm, language))
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "FocusWater-Export"
        ) { result in
            if case .failure = result {
                viewModel.errorMessage = AppLocalizer.text(.saveFocusFailed, language)
            }
        }
    }

    private var summaryCards: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    summaryCardToday
                    summaryCardWeek
                    summaryCardBest
                    summaryCardBottles
                }
            } else if compactLayout {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        summaryCardToday
                        summaryCardWeek
                    }
                    HStack(spacing: 12) {
                        summaryCardBest
                        summaryCardBottles
                    }
                }
            } else {
                HStack(spacing: 12) {
                    summaryCardToday
                    summaryCardWeek
                    summaryCardBest
                    summaryCardBottles
                }
            }
        }
    }

    private var summaryCardToday: some View {
        StatCard(
            icon: "sun.max.fill",
            iconColor: .neutralIcon,
            value: viewModel.formatMinutes(viewModel.todayMinutes),
            label: AppLocalizer.text(.todayFocus, language)
        )
    }

    private var summaryCardWeek: some View {
        StatCard(
            icon: "chart.bar.fill",
            iconColor: .neutralIcon,
            value: viewModel.formatMinutes(viewModel.weekMinutes),
            label: AppLocalizer.text(.weeklyTotal, language)
        )
    }

    private var summaryCardBest: some View {
        StatCard(
            icon: "trophy.fill",
            iconColor: .neutralIcon,
            value: viewModel.formatMinutes(viewModel.historicalMaxDailyMinutes),
            label: AppLocalizer.text(.maxSingleDay, language)
        )
    }

    private var summaryCardBottles: some View {
        StatCard(
            icon: "drop.fill",
            iconColor: .accentBlue,
            value: "\(viewModel.totalBottles)",
            label: AppLocalizer.text(.totalBottleCount, language)
        )
    }

    private var recentSessionsSection: some View {
        let filtered = viewModel.allSessions.filter {
            searchText.isEmpty || ($0.note ?? "").localizedCaseInsensitiveContains(searchText)
        }
        let recentSessions = Array(
            (section == 0 ? viewModel.allSessions : filtered).prefix(section == 0 ? 5 : visibleCount))

        return VStack(alignment: .leading, spacing: 14) {
            Text(
                section == 0
                    ? AppLocalizer.text(.recentSessions, language)
                    : (language == .zhHans ? "全部记录 · \(filtered.count)" : "All sessions · \(filtered.count)")
            )
            .font(.headline)
            .foregroundStyle(Color.primaryText)

            if recentSessions.isEmpty {
                Text(
                    searchText.isEmpty
                        ? AppLocalizer.text(.noSessionsYet, language)
                        : (language == .zhHans ? "没有找到匹配的备注。" : "No matching notes.")
                )
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
            } else {
                ForEach(recentSessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    session.date.formatted(
                                        .dateTime.month(.abbreviated).day().hour().minute().locale(language.locale))
                                )
                                .font(.callout)
                                .foregroundStyle(Color.primaryText)
                                if let note = session.note,
                                    !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer()

                            Text(viewModel.formatMinutes(session.duration))
                                .font(.callout)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.accentBlue)

                            Menu {
                                Button {
                                    selectedSession = session
                                } label: {
                                    Label(AppLocalizer.text(.editSession, language), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    sessionPendingDeletion = session
                                } label: {
                                    Label(AppLocalizer.text(.deleteSession, language), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(Color.secondaryText)
                                    .padding(.leading, 4)
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(language == .zhHans ? "编辑或删除这条记录" : "Edit or delete this session")
                        }

                        if session.id != recentSessions.last?.id {
                            Divider()
                                .overlay(Color.separatorLine)
                        }
                    }
                }
                if section == 1, filtered.count > visibleCount {
                    Button(language == .zhHans ? "加载更多" : "Load more") { visibleCount += 30 }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(18)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }

    private var exportSection: some View {
        Button {
            exportDocument = FocusCSVDocument(content: viewModel.exportCSV())
            isExporting = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(Color.accentBlue)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.controlBackground))

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppLocalizer.text(.exportData, language))
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Text(AppLocalizer.text(.exportDataSubtitle, language))
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.tertiaryText)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
        .disabled(viewModel.allSessions.isEmpty)
        .opacity(viewModel.allSessions.isEmpty ? 0.55 : 1)
    }

    private var heatmapSection: some View {
        let data = viewModel.monthlyHeatmapData
        let columns = 12
        let rows = 7

        return VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalizer.text(.heatmapTitle, language))
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = col * rows + row
                            if index < data.count {
                                let item = data[index]
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(heatmapColor(item.minutes))
                                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                    .accessibilityLabel(
                                        "\(item.date.formatted(.dateTime.month().day().locale(language.locale))): \(viewModel.formatMinutes(item.minutes))"
                                    )
                                    .platformHelp(
                                        "\(item.date.formatted(.dateTime.month().day().locale(language.locale))): \(viewModel.formatMinutes(item.minutes))"
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.clear)
                                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text(AppLocalizer.text(.less, language))
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(heatmapColor(i * 120))
                        .frame(width: 12, height: 12)
                }
                Text(AppLocalizer.text(.more, language))
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(18)
        .glassCardBackground(cornerRadius: 18, shadowRadius: 6, shadowY: 2)
    }

    private func heatmapColor(_ minutes: Int) -> Color {
        switch minutes {
        case 0:
            return Color.controlBackground
        case 1..<60:
            return .accentBlue.opacity(0.18)
        case 60..<180:
            return .accentBlue.opacity(0.32)
        case 180..<360:
            return .accentBlue.opacity(0.52)
        default:
            return .accentBlue.opacity(0.84)
        }
    }
}
