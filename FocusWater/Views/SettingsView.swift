import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var viewModel: FocusViewModel

    @State private var hours: Int
    @State private var minutes: Int
    @State private var language: AppLanguage
    @State private var appearance: AppAppearanceMode
    @State private var saveSucceeded = false
    @State private var selectedSection = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(viewModel: FocusViewModel) {
        self.viewModel = viewModel
        _hours = State(initialValue: viewModel.dailyGoalHours)
        _minutes = State(initialValue: viewModel.dailyGoalRemainingMinutes)
        _language = State(initialValue: viewModel.appLanguage)
        _appearance = State(initialValue: viewModel.appearanceMode)
    }

    private var compactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var formattedGoal: String {
        if minutes == 0 {
            return formattedHours(hours)
        }
        return "\(formattedHours(hours)) \(formattedMinutes(minutes))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compactLayout ? 18 : 22) {
                header
                Picker(language == .zhHans ? "设置分类" : "Settings section", selection: $selectedSection) {
                    Text(language == .zhHans ? "偏好" : "Preferences").tag(0)
                    Text(language == .zhHans ? "数据与隐私" : "Data & privacy").tag(1)
                }.pickerStyle(.segmented)
                if selectedSection == 0 {
                    goalSection
                    languageSection
                    appearanceSection
                    capacitySection
                    saveButton
                } else {
                    syncSection
                    DataPrivacySection(viewModel: viewModel)
                }
            }
            .padding(.horizontal, compactLayout ? 20 : 28)
            .padding(.top, compactLayout ? 18 : 28)
            .padding(.bottom, 110)
            .frame(maxWidth: compactLayout ? .infinity : 520, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .platformMinFrame(width: 380, height: 500)
        .background(Color.appBackgroundGradient.ignoresSafeArea())
        .onAppear(perform: syncFromViewModel)
        #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_SCENE"] == "privacy" {
                    selectedSection = 1
                }
            }
        #endif
        .task {
            await viewModel.refreshCloudSyncStatus()
        }
        .onChange(of: viewModel.dailyGoalMinutes) { _, _ in
            syncFromViewModel()
        }
        .onChange(of: viewModel.appLanguage) { _, _ in
            syncFromViewModel()
        }
        .onChange(of: viewModel.appearanceMode) { _, _ in
            syncFromViewModel()
        }
        .onChange(of: hours) { _, newValue in
            saveSucceeded = false
            if newValue == 18 && minutes > 0 {
                minutes = 0
            }
        }
        .onChange(of: minutes) { _, newValue in
            saveSucceeded = false
            if hours == 18 && newValue > 0 {
                minutes = 0
            }
        }
        .onChange(of: language) { _, _ in
            saveSucceeded = false
        }
        .onChange(of: appearance) { _, _ in
            saveSucceeded = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalizer.text(.settings, language))
                .font(.system(size: compactLayout ? 30 : 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryText)
            Text(AppLocalizer.text(.settingsSubtitle, language))
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var goalSection: some View {
        sectionContainer {
            goalStepper(
                title: AppLocalizer.text(.hours, language),
                value: $hours,
                range: 1...18,
                step: 1,
                valueText: formattedHours(hours)
            )

            sectionDivider

            goalStepper(
                title: AppLocalizer.text(.minutes, language),
                value: $minutes,
                range: 0...55,
                step: 5,
                valueText: formattedMinutes(minutes)
            )
        }
    }

    private var languageSection: some View {
        labeledSection(title: AppLocalizer.text(.appLanguage, language)) {
            Picker(AppLocalizer.text(.appLanguage, language), selection: $language) {
                ForEach(AppLanguage.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)
        }
    }

    private var appearanceSection: some View {
        labeledSection(title: AppLocalizer.text(.appearance, language)) {
            Picker(AppLocalizer.text(.appearance, language), selection: $appearance) {
                ForEach(AppAppearanceMode.allCases) { item in
                    Text(item.displayName(language: language)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)
        }
    }

    private var capacitySection: some View {
        sectionContainer {
            VStack(alignment: .leading, spacing: 7) {
                Text(AppLocalizer.text(.currentCapacity, language))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                Text(formattedGoal)
                    .font(.system(size: compactLayout ? 34 : 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(AppLocalizer.text(.allowedRange, language))
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var syncSection: some View {
        labeledSection(title: AppLocalizer.text(.iCloudSync, language)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.cloudSyncStatusSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(viewModel.cloudSyncStatus == .available ? Color.accentBlue : Color.neutralIcon)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.controlBackground)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(viewModel.cloudSyncStatusText)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(AppLocalizer.text(.iCloudSyncSubtitle, language))
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        Task {
                            await viewModel.refreshCloudSyncStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.controlBackground)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppLocalizer.text(.iCloudSyncRefresh, language))
                }
                .padding(16)

                sectionDivider

                if let date = viewModel.lastCloudTransferAt {
                    Text(
                        (language == .zhHans ? "最近一次成功传输：" : "Last successful transfer: ")
                            + date.formatted(.dateTime.month().day().hour().minute().locale(language.locale))
                    )
                    .font(.caption).foregroundStyle(Color.secondaryText)
                    .padding(.horizontal, 16).padding(.top, 12)
                }

                Text(AppLocalizer.text(.iCloudSyncPrivacyNote, language))
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveSucceeded = viewModel.savePreferences(
                hours: hours,
                minutes: minutes,
                language: language,
                appearance: appearance
            )
        } label: {
            Label(
                saveSucceeded ? AppLocalizer.text(.saved, language) : AppLocalizer.text(.saveSettings, language),
                systemImage: saveSucceeded ? "checkmark.circle.fill" : "checkmark.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GoalPrimaryButtonStyle())
        .disabled(
            !(FocusViewModel.minimumDailyGoalMinutes...FocusViewModel.maximumDailyGoalMinutes).contains(totalMinutes)
        )
        .padding(.top, 4)
    }

    private func syncFromViewModel() {
        hours = viewModel.dailyGoalHours
        minutes = viewModel.dailyGoalRemainingMinutes
        language = viewModel.appLanguage
        appearance = viewModel.appearanceMode
    }

    private func labeledSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.secondaryText)
                .padding(.leading, 16)

            sectionContainer {
                content()
            }
        }
    }

    private func goalStepper(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        valueText: String
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text(valueText)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.separatorLine)
            .padding(.leading, 16)
    }

    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.glassCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
        )
    }

    private func formattedHours(_ value: Int) -> String {
        language == .zhHans ? "\(value) 小时" : "\(value) h"
    }

    private func formattedMinutes(_ value: Int) -> String {
        language == .zhHans ? "\(value) 分钟" : "\(value) m"
    }
}

struct DataPrivacySection: View {
    var viewModel: FocusViewModel
    @AppStorage(AppStoreCoordinator.cloudPreferenceKey) private var wantsCloud = true
    @State private var proposedCloud: Bool?
    @State private var backupDocument = FocusBackupDocument()
    @State private var exportingBackup = false
    @State private var importingBackup = false
    @State private var pendingBackup: FocusBackup?
    @State private var message: String?
    @State private var isReading = false
    private var zh: Bool { viewModel.appLanguage == .zhHans }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(zh ? "数据与隐私" : "Data & privacy")
                .font(.system(.title3, design: .rounded, weight: .bold))
            VStack(alignment: .leading, spacing: 14) {
                Toggle(
                    zh ? "使用 iCloud 同步" : "Use iCloud sync",
                    isOn: Binding(
                        get: { wantsCloud }, set: { proposedCloud = $0 }
                    ))
                Text(
                    wantsCloud != viewModel.isCloudSyncEnabled
                        ? (zh
                            ? "设置将在下次启动时尝试应用。本机数据会保留；云端已有数据不会被删除。"
                            : "This preference will be applied on next launch. Local data is retained; existing iCloud data is not deleted.")
                        : (zh
                            ? "同步使用你的私有 iCloud 数据库。切换设置需重启应用。"
                            : "Sync uses your private iCloud database. Changes require restarting the app.")
                )
                .font(.caption).foregroundStyle(Color.secondaryText)
            }
            .padding(16).glassCardBackground(cornerRadius: 18)

            VStack(alignment: .leading, spacing: 14) {
                Label(zh ? "完整备份" : "Full backup", systemImage: "externaldrive.badge.checkmark")
                    .font(.headline)
                Text(
                    zh
                        ? "包含专注记录、水瓶与偏好，可在 FocusWater 中恢复。导出的 JSON 是明文文件，包含备注，请存放在可信位置。"
                        : "Includes sessions, bottles and preferences for restoring in FocusWater. Exported JSON is readable and includes notes; keep it in a trusted location."
                )
                .font(.caption).foregroundStyle(Color.secondaryText)
                Button {
                    do {
                        backupDocument = FocusBackupDocument(data: try viewModel.makeBackup().encoded())
                        exportingBackup = true
                    } catch {
                        message =
                            zh
                            ? "暂时无法生成备份，原数据未改变。请重试。" : "Could not create a backup. Your data is unchanged; try again."
                    }
                } label: {
                    Label(zh ? "导出完整备份" : "Export full backup", systemImage: "square.and.arrow.up").frame(
                        maxWidth: .infinity)
                }
                .buttonStyle(FocusActionStyle(primary: false))
                Button {
                    importingBackup = true
                } label: {
                    Label(zh ? "从备份恢复…" : "Restore from backup…", systemImage: "square.and.arrow.down").frame(
                        maxWidth: .infinity)
                }
                .buttonStyle(FocusActionStyle(primary: false)).disabled(isReading)
                if isReading { ProgressView(zh ? "正在检查备份…" : "Checking backup…") }
            }
            .padding(16).glassCardBackground(cornerRadius: 18)

            VStack(alignment: .leading, spacing: 10) {
                Label(zh ? "你的数据，由你掌握" : "Your data stays yours", systemImage: "hand.raised.fill").font(.headline)
                Text(
                    zh
                        ? "专注数据保存在应用的本地数据区；开启同步后会传输至你的私有 iCloud 数据库。应用没有广告、第三方统计或开发者自建服务器，也不会申请通知权限。"
                        : "Focus data is stored in the app's local storage and, when enabled, your private iCloud database. There are no ads, third-party analytics, developer-operated servers or notification permission requests."
                )
                Text(
                    zh
                        ? "设备解锁后可读取本地数据，请使用系统密码保护设备。导出文件由你选择的位置管理；不要把包含私人备注的备份发给陌生人。"
                        : "Local data can be accessed on an unlocked device; protect your device with a passcode. Exported files are managed at the location you choose. Do not share backups containing private notes with strangers."
                )
                Text(
                    "FocusWater · "
                        + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                )
                .foregroundStyle(Color.secondaryText)
            }
            .font(.caption).foregroundStyle(Color.secondaryText)
            .padding(16).glassCardBackground(cornerRadius: 18)
        }
        .fileExporter(
            isPresented: $exportingBackup, document: backupDocument, contentType: .json,
            defaultFilename: "FocusWater-Backup"
        ) { result in
            switch result {
            case .success: message = zh ? "完整备份已导出。" : "Full backup exported."
            case .failure: message = zh ? "导出未完成，原数据未改变。" : "Export was not completed. Your data is unchanged."
            }
        }
        .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            isReading = true
            Task {
                do {
                    let backup = try await Task.detached(priority: .userInitiated) { try FocusBackup.read(from: url) }
                        .value
                    pendingBackup = backup
                } catch {
                    message =
                        zh
                        ? "无法读取这个备份。请使用有效的 FocusWater JSON 文件（不超过 20 MB）。未修改任何数据。"
                        : "Invalid backup. Choose a valid FocusWater JSON file under 20 MB. No data was changed."
                }
                isReading = false
            }
        }
        .alert(
            zh ? "恢复备份？" : "Restore backup?",
            isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } })
        ) {
            Button(zh ? "合并恢复" : "Merge & restore") {
                guard let backup = pendingBackup else { return }
                do {
                    let count = try viewModel.restoreBackup(backup)
                    message =
                        zh
                        ? "已恢复 \(count) 条新记录；已有记录未覆盖。"
                        : "Restored \(count) new records. Existing records were not overwritten."
                } catch {
                    message =
                        zh
                        ? "恢复未完成：备份与本机数据冲突或存储不可用。未提交任何更改。"
                        : "Restore failed due to conflicting records or a storage error. No changes were committed."
                }
                pendingBackup = nil
            }
            Button(AppLocalizer.text(.cancel, viewModel.appLanguage), role: .cancel) { pendingBackup = nil }
        } message: {
            Text(
                zh
                    ? "备份包含 \(pendingBackup?.sessions.count ?? 0) 条记录。只添加缺失记录，不覆盖已有数据；已开启的 iCloud 同步也会同步恢复后的记录。"
                    : "The backup contains \(pendingBackup?.sessions.count ?? 0) records. Only missing records will be added. Restored records also sync if iCloud is enabled."
            )
        }
        .alert(
            zh ? "更改 iCloud 设置？" : "Change iCloud preference?",
            isPresented: Binding(get: { proposedCloud != nil }, set: { if !$0 { proposedCloud = nil } })
        ) {
            Button(zh ? "确认，下次启动生效" : "Apply on next launch") {
                if let value = proposedCloud { wantsCloud = value }
                proposedCloud = nil
            }
            Button(AppLocalizer.text(.cancel, viewModel.appLanguage), role: .cancel) { proposedCloud = nil }
        } message: {
            Text(
                zh
                    ? "不会清空本机或云端记录。关闭同步不会删除已存于 iCloud 的副本。请先保存正在计时的专注，再自行重启应用。"
                    : "This does not erase local or cloud records. Disabling sync does not remove existing iCloud copies. Save your timer before restarting the app."
            )
        }
        .alert(
            zh ? "数据管理" : "Data management",
            isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
        ) {
            Button(AppLocalizer.text(.confirm, viewModel.appLanguage), role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}
