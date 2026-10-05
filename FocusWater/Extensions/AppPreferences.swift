import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .zhHans: "简体中文"
        case .english: "English"
        }
    }

    static var defaultValue: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zhHans : .english
    }

    static func fromStored(_ rawValue: String?) -> AppLanguage {
        guard let rawValue, let language = AppLanguage(rawValue: rawValue) else {
            return .defaultValue
        }
        return language
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static func fromStored(_ rawValue: String?) -> AppAppearanceMode {
        guard let rawValue, let mode = AppAppearanceMode(rawValue: rawValue) else {
            return .system
        }
        return mode
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .system:
            return AppLocalizer.text(.system, language)
        case .light:
            return AppLocalizer.text(.light, language)
        case .dark:
            return AppLocalizer.text(.dark, language)
        }
    }
}

enum AppTextKey {
    case appTitle
    case settings
    case settingsSubtitle
    case focusTab
    case warehouseTab
    case statsTab
    case operationNotCompleted
    case confirm
    case currentBottle
    case readyToStart
    case focused
    case today
    case tapBottleHint
    case focusTimer
    case timerReady
    case timerPaused
    case timerRunning
    case start
    case pause
    case reset
    case save
    case addFocus
    case refresh
    case timerMinOneMinuteHint
    case timerAvailableHintPrefix
    case bottleFilled
    case bottleStoredSuffix
    case addFocusTime
    case convertFocusSubtitle
    case cancel
    case quickPick
    case hours
    case minutes
    case notePlaceholder
    case fullBottleCount
    case totalFocus
    case consecutiveDays
    case warehouseEmpty
    case warehouseEmptySubtitle
    case close
    case focusRecords
    case completedAt
    case streakActive
    case streakInactive
    case weeklyTrend
    case goalLegend
    case todayFocus
    case weeklyTotal
    case maxSingleDay
    case totalBottleCount
    case heatmapTitle
    case less
    case more
    case recentSessions
    case noSessionsYet
    case editSession
    case deleteSession
    case deleteSessionConfirm
    case sessionDate
    case exportData
    case exportDataSubtitle
    case invalidSessionDuration
    case updateSessionFailed
    case deleteSessionFailed
    case setDailyGoal
    case goalIntro
    case currentCapacity
    case allowedRange
    case startFirstBottle
    case saveSettings
    case saved
    case appLanguage
    case appearance
    case chinese
    case english
    case system
    case light
    case dark
    case menuToday
    case menuCompleted
    case menuOpenMainWindow
    case menuQuit
    case readDataFailed
    case inputPositiveMinutes
    case saveFocusFailed
    case timerMinOneMinuteError
    case saveGoalFailed
    case iCloudSync
    case iCloudSyncSubtitle
    case iCloudSyncChecking
    case iCloudSyncAvailable
    case iCloudSyncNoAccount
    case iCloudSyncRestricted
    case iCloudSyncTemporary
    case iCloudSyncUnavailable
    case iCloudSyncError
    case iCloudSyncRefresh
    case iCloudSyncPrivacyNote
}

enum AppLocalizer {
    static func text(_ key: AppTextKey, _ language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            switch key {
            case .appTitle: "专注水瓶"
            case .settings: "设置"
            case .settingsSubtitle: "调整专注偏好，管理同步、本地备份与隐私。"
            case .focusTab: "专注"
            case .warehouseTab: "收藏"
            case .statsTab: "记录"
            case .operationNotCompleted: "操作未完成"
            case .confirm: "确定"
            case .currentBottle: "当前水瓶"
            case .readyToStart: "准备开始"
            case .focused: "已专注"
            case .today: "今天"
            case .tapBottleHint: "点击水瓶或按 + 键添加专注时间"
            case .focusTimer: "专注计时"
            case .timerReady: "准备开始一段专注"
            case .timerPaused: "已暂停，可继续或记入水瓶"
            case .timerRunning: "正在积累水滴"
            case .start: "开始"
            case .pause: "暂停"
            case .reset: "重置"
            case .save: "记入"
            case .addFocus: "添加专注"
            case .refresh: "刷新"
            case .timerMinOneMinuteHint: "计时满 1 分钟后可直接记入当前水瓶"
            case .timerAvailableHintPrefix: "当前可记入"
            case .bottleFilled: "水瓶已满!"
            case .bottleStoredSuffix: "瓶水已收入仓库"
            case .addFocusTime: "添加专注时间"
            case .convertFocusSubtitle: "把一段真实的投入，转成一口更清澈的水。"
            case .cancel: "取消"
            case .quickPick: "快速选择"
            case .hours: "小时"
            case .minutes: "分钟"
            case .notePlaceholder: "备注(可选)"
            case .fullBottleCount: "满瓶数"
            case .totalFocus: "总专注"
            case .consecutiveDays: "连续天数"
            case .warehouseEmpty: "仓库空空如也"
            case .warehouseEmptySubtitle: "专注时间还不够装满一瓶水哦\n回去加油吧～"
            case .close: "关闭"
            case .focusRecords: "专注记录"
            case .completedAt: "完成于"
            case .streakActive: "连续专注打卡"
            case .streakInactive: "今天还没专注哦"
            case .weeklyTrend: "本周趋势"
            case .goalLegend: "虚线 = 每日目标"
            case .todayFocus: "今日专注"
            case .weeklyTotal: "本周总计"
            case .maxSingleDay: "最高单日"
            case .totalBottleCount: "总瓶数"
            case .heatmapTitle: "近三个月热力图"
            case .less: "少"
            case .more: "多"
            case .recentSessions: "最近专注记录"
            case .noSessionsYet: "还没有记录，开始第一段专注后就会出现在这里。"
            case .editSession: "编辑记录"
            case .deleteSession: "删除记录"
            case .deleteSessionConfirm: "删除后会同步调整所属水瓶，且无法撤销。"
            case .sessionDate: "日期与时间"
            case .exportData: "导出 CSV"
            case .exportDataSubtitle: "导出全部专注记录，便于备份或在表格应用中分析。"
            case .invalidSessionDuration: "修改后的时长必须大于 0，且不能超过当前水瓶的剩余容量。"
            case .updateSessionFailed: "更新专注记录失败，请重试。"
            case .deleteSessionFailed: "删除专注记录失败，请重试。"
            case .setDailyGoal: "设置每日目标"
            case .goalIntro: "每日目标是当天的专注目标，也决定新水瓶的容量。水瓶跨天积累，不会在午夜清空；已有进度的水瓶保留原容量。"
            case .currentCapacity: "当前容量"
            case .allowedRange: "允许范围：1h - 18h"
            case .startFirstBottle: "开始装第一瓶水"
            case .saveSettings: "保存设置"
            case .saved: "已保存"
            case .appLanguage: "语言"
            case .appearance: "外观"
            case .chinese: "简体中文"
            case .english: "English"
            case .system: "跟随系统"
            case .light: "浅色"
            case .dark: "深色"
            case .menuToday: "今日:"
            case .menuCompleted: "满瓶:"
            case .menuOpenMainWindow: "打开主窗口"
            case .menuQuit: "退出"
            case .readDataFailed: "读取专注数据失败，请稍后重试。"
            case .inputPositiveMinutes: "请输入大于 0 分钟的专注时长。"
            case .saveFocusFailed: "保存专注记录失败，请重试。"
            case .timerMinOneMinuteError: "专注计时至少满 1 分钟后才能记入水瓶。"
            case .saveGoalFailed: "保存设置失败，请重试。"
            case .iCloudSync: "iCloud 同步"
            case .iCloudSyncSubtitle: "启用且可用时，系统通过你的私有 iCloud 数据库同步记录、水瓶和设置。"
            case .iCloudSyncChecking: "正在检查 iCloud 状态"
            case .iCloudSyncAvailable: "iCloud 账户可用，等待系统同步"
            case .iCloudSyncNoAccount: "未登录 iCloud"
            case .iCloudSyncRestricted: "当前账号受限制"
            case .iCloudSyncTemporary: "iCloud 暂时不可用"
            case .iCloudSyncUnavailable: "当前使用本地存储"
            case .iCloudSyncError: "无法检查 iCloud 状态"
            case .iCloudSyncRefresh: "刷新同步状态"
            case .iCloudSyncPrivacyNote: "无需额外账号。本机保留数据副本；同步不会将记录发送到开发者自建服务器。"
            }
        case .english:
            switch key {
            case .appTitle: "FocusWater"
            case .settings: "Settings"
            case .settingsSubtitle: "Adjust focus preferences, sync, local backups and privacy."
            case .focusTab: "Focus"
            case .warehouseTab: "Collection"
            case .statsTab: "Activity"
            case .operationNotCompleted: "Action Incomplete"
            case .confirm: "OK"
            case .currentBottle: "Current Bottle"
            case .readyToStart: "Ready to Start"
            case .focused: "Focused"
            case .today: "Today"
            case .tapBottleHint: "Tap the bottle or press + to add focus time"
            case .focusTimer: "Focus Timer"
            case .timerReady: "Ready to begin a session"
            case .timerPaused: "Paused. Resume or save it into the bottle."
            case .timerRunning: "Collecting drops"
            case .start: "Start"
            case .pause: "Pause"
            case .reset: "Reset"
            case .save: "Save"
            case .addFocus: "Add Focus"
            case .refresh: "Refresh"
            case .timerMinOneMinuteHint: "The timer must reach 1 minute before it can be saved"
            case .timerAvailableHintPrefix: "Ready to save"
            case .bottleFilled: "Bottle Filled!"
            case .bottleStoredSuffix: "has been stored"
            case .addFocusTime: "Add Focus Time"
            case .convertFocusSubtitle: "Turn a real stretch of focus into a clearer bottle of water."
            case .cancel: "Cancel"
            case .quickPick: "Quick Picks"
            case .hours: "Hours"
            case .minutes: "Minutes"
            case .notePlaceholder: "Note (Optional)"
            case .fullBottleCount: "Filled"
            case .totalFocus: "Total Focus"
            case .consecutiveDays: "Streak"
            case .warehouseEmpty: "Archive is empty"
            case .warehouseEmptySubtitle: "You have not filled a bottle yet.\nGo add some focus time."
            case .close: "Close"
            case .focusRecords: "Focus Records"
            case .completedAt: "Completed"
            case .streakActive: "Consecutive focus days"
            case .streakInactive: "No focus session yet today"
            case .weeklyTrend: "Weekly Trend"
            case .goalLegend: "Dashed line = daily goal"
            case .todayFocus: "Today"
            case .weeklyTotal: "This Week"
            case .maxSingleDay: "Best Day"
            case .totalBottleCount: "Bottles"
            case .heatmapTitle: "Last 3 Months"
            case .less: "Less"
            case .more: "More"
            case .recentSessions: "Recent Sessions"
            case .noSessionsYet: "No sessions yet. Your first focus session will appear here."
            case .editSession: "Edit Session"
            case .deleteSession: "Delete Session"
            case .deleteSessionConfirm: "This adjusts its bottle and cannot be undone."
            case .sessionDate: "Date & Time"
            case .exportData: "Export CSV"
            case .exportDataSubtitle: "Export every focus session for backup or spreadsheet analysis."
            case .invalidSessionDuration: "The duration must be positive and fit within this bottle's remaining capacity."
            case .updateSessionFailed: "Failed to update this focus session. Please try again."
            case .deleteSessionFailed: "Failed to delete this focus session. Please try again."
            case .setDailyGoal: "Set Daily Goal"
            case .goalIntro: "Your daily goal is your focus target for today and sets new bottle capacities. Bottles accumulate across days; a bottle with progress keeps its original capacity."
            case .currentCapacity: "Current Capacity"
            case .allowedRange: "Range: 1h - 18h"
            case .startFirstBottle: "Start Filling the First Bottle"
            case .saveSettings: "Save Settings"
            case .saved: "Saved"
            case .appLanguage: "Language"
            case .appearance: "Appearance"
            case .chinese: "简体中文"
            case .english: "English"
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            case .menuToday: "Today:"
            case .menuCompleted: "Filled:"
            case .menuOpenMainWindow: "Open Main Window"
            case .menuQuit: "Quit"
            case .readDataFailed: "Failed to load focus data. Please try again."
            case .inputPositiveMinutes: "Enter a focus duration greater than 0 minutes."
            case .saveFocusFailed: "Failed to save this focus record. Please try again."
            case .timerMinOneMinuteError: "The timer must run for at least 1 minute before saving."
            case .saveGoalFailed: "Failed to save settings. Please try again."
            case .iCloudSync: "iCloud Sync"
            case .iCloudSyncSubtitle: "When enabled and available, the system syncs records, bottles and settings with your private iCloud database."
            case .iCloudSyncChecking: "Checking iCloud status"
            case .iCloudSyncAvailable: "iCloud account available. Sync is managed by the system."
            case .iCloudSyncNoAccount: "Not signed in to iCloud"
            case .iCloudSyncRestricted: "This account is restricted"
            case .iCloudSyncTemporary: "iCloud is temporarily unavailable"
            case .iCloudSyncUnavailable: "Using local storage"
            case .iCloudSyncError: "Could not check iCloud status"
            case .iCloudSyncRefresh: "Refresh Sync Status"
            case .iCloudSyncPrivacyNote: "No extra account. Data stays on your device and in your private iCloud database, not on a developer-operated server."
            }
        }
    }
}
