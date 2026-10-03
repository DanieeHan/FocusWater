import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData
import SwiftUI

enum CloudSyncStatus: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case unavailable
    case error
}

@MainActor
@Observable
final class FocusViewModel {
    static let minimumDailyGoalMinutes = 60
    static let maximumDailyGoalMinutes = 1080
    static let defaultDailyGoalMinutes = 480
    static let cloudKitContainerIdentifier = "iCloud.com.hanzibo.FocusWater"

    var currentBottle: WaterBottle?
    var completedBottles: [WaterBottle] = []
    var allSessions: [FocusSession] = []
    var showCompletionAnimation = false
    var completingBottleID: UUID?
    var errorMessage: String?
    var timerElapsedSeconds = 0
    var isTimerRunning = false
    var dailyGoalMinutes = defaultDailyGoalMinutes
    var needsInitialGoalSetup = false
    var appLanguage = AppLanguage.defaultValue
    var appearanceMode = AppAppearanceMode.system
    var isCloudSyncEnabled = false
    var cloudSyncStatus = CloudSyncStatus.checking
    var cloudIsSyncing = false
    var lastCloudTransferAt: Date?
    var cloudTransferFailed = false
    var timerNotice: String?

    private var modelContext: ModelContext?
    private var timerStartedAt: Date?
    private var timerMonotonicStart: TimeInterval?
    private var timerEntryID = UUID()
    private var timerAccumulatedSeconds = 0
    private var didRestoreTimerState = false
    private var settings: FocusSettings?
    private let timerPersistence: FocusTimerPersistence
    private let clock: FocusClock
    private let saveContext: (ModelContext) throws -> Void
    @ObservationIgnored private var cloudObservers: [NSObjectProtocol] = []
    private var activeCloudEvents: Set<UUID> = []
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    private var appLocale: Locale {
        appLanguage.locale
    }

    init(
        timerPersistence: FocusTimerPersistence = FocusTimerPersistence(),
        clock: FocusClock = .live,
        saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.timerPersistence = timerPersistence
        self.clock = clock
        self.saveContext = saveContext
    }

    func configure(with context: ModelContext, cloudSyncEnabled: Bool = true) {
        if modelContext === context {
            fetchData()
            return
        }
        self.modelContext = context
        self.isCloudSyncEnabled = cloudSyncEnabled
        #if DEBUG
            seedScreenshotDemoDataIfNeeded(in: context)
        #endif
        fetchData()
        restoreTimerStateIfNeeded()
        #if DEBUG
            applyScreenshotSceneStateIfNeeded()
        #endif
        refreshCloudSyncStatusWhenAvailable()
        observeCloudChangesIfNeeded()
    }

    func fetchData() {
        guard let context = modelContext else { return }
        let settingsDescriptor = FetchDescriptor<FocusSettings>(sortBy: [SortDescriptor(\.createdAt)])
        let bottleDescriptor = FetchDescriptor<WaterBottle>(sortBy: [SortDescriptor(\.serialNumber)])
        let sessionDescriptor = FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])

        do {
            let settingsList = try context.fetch(settingsDescriptor)
            if let existingSettings = settingsList.first {
                settings = existingSettings
                dailyGoalMinutes = normalizedGoalMinutes(existingSettings.dailyGoalMinutes)
                appLanguage = AppLanguage.fromStored(existingSettings.languageCode)
                appearanceMode = AppAppearanceMode.fromStored(existingSettings.appearanceMode)
                needsInitialGoalSetup = false
            } else {
                settings = nil
                dailyGoalMinutes = Self.defaultDailyGoalMinutes
                appLanguage = .defaultValue
                appearanceMode = .system
                needsInitialGoalSetup = true
            }

            let bottles = try context.fetch(bottleDescriptor)
            completedBottles = bottles.filter { $0.isCompleted }
            currentBottle = bottles.first { !$0.isCompleted }
            allSessions = try context.fetch(sessionDescriptor)
        } catch {
            errorMessage = AppLocalizer.text(.readDataFailed, appLanguage)
        }
    }

    @discardableResult
    func getOrCreateCurrentBottle() throws -> WaterBottle {
        if let bottle = currentBottle, !bottle.isCompleted {
            return bottle
        }
        guard let context = modelContext else {
            throw FocusWaterError.dataStoreUnavailable
        }
        let existingBottles = try context.fetch(FetchDescriptor<WaterBottle>())
        let nextSerial = (existingBottles.map(\.serialNumber).max() ?? 0) + 1
        let newBottle = WaterBottle(serialNumber: nextSerial, capacityMinutes: dailyGoalMinutes)
        context.insert(newBottle)
        currentBottle = newBottle
        return newBottle
    }

    @discardableResult
    func addFocus(minutes: Int, note: String? = nil, timerEntryID: UUID? = nil) -> Bool {
        guard let context = modelContext else { return false }
        guard minutes > 0, minutes <= 10_080 else {
            errorMessage = AppLocalizer.text(.inputPositiveMinutes, appLanguage)
            return false
        }

        var remaining = minutes

        do {
            if let timerEntryID {
                let receipt = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.timerEntryID == timerEntryID })
                if try context.fetchCount(receipt) > 0 { return true }
            }
            while remaining > 0 {
                let bottle = try getOrCreateCurrentBottle()
                guard bottle.capacityMinutes > 0 else { throw CocoaError(.validationMissingMandatoryProperty) }
                let space = bottle.remainingMinutes
                if space == 0 {
                    completeBottle(bottle)
                    continue
                }
                let toAdd = min(remaining, space)

                let session = FocusSession(date: clock.now(), duration: toAdd, note: normalizedNote(note))
                session.timerEntryID = timerEntryID
                context.insert(session)
                session.bottle = bottle
                bottle.totalMinutes += toAdd

                if bottle.sessions == nil {
                    bottle.sessions = []
                }
                bottle.sessions?.append(session)

                remaining -= toAdd

                if bottle.totalMinutes >= bottle.capacityMinutes {
                    completeBottle(bottle)
                }
            }

            try saveContext(context)
            fetchData()
        } catch {
            context.rollback()
            showCompletionAnimation = false
            completingBottleID = nil
            errorMessage = AppLocalizer.text(.saveFocusFailed, appLanguage)
            fetchData()
            return false
        }

        if showCompletionAnimation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showCompletionAnimation = false
                self?.completingBottleID = nil
            }
        }
        return true
    }

    private func completeBottle(_ bottle: WaterBottle) {
        bottle.isCompleted = true
        bottle.completedAt = .now
        currentBottle = nil
        showCompletionAnimation = true
        completingBottleID = bottle.id
    }

    func clearError() {
        errorMessage = nil
    }

    @discardableResult
    func updateSession(
        _ session: FocusSession,
        date: Date,
        minutes: Int,
        note: String?
    ) -> Bool {
        guard let context = modelContext, let bottle = session.bottle else { return false }
        let maximumDuration = session.duration + bottle.remainingMinutes
        guard minutes > 0, minutes <= maximumDuration else {
            errorMessage = AppLocalizer.text(.invalidSessionDuration, appLanguage)
            return false
        }

        let oldDuration = session.duration

        session.duration = minutes
        session.date = date
        session.note = normalizedNote(note)
        bottle.totalMinutes += minutes - oldDuration
        reconcileCompletionState(for: bottle)

        do {
            try saveContext(context)
            fetchData()
            return true
        } catch {
            context.rollback()
            errorMessage = AppLocalizer.text(.updateSessionFailed, appLanguage)
            fetchData()
            return false
        }
    }

    @discardableResult
    func deleteSession(_ session: FocusSession) -> Bool {
        guard let context = modelContext else { return false }
        let bottle = session.bottle

        if let bottle {
            bottle.totalMinutes = max(bottle.totalMinutes - session.duration, 0)
            bottle.sessions?.removeAll { $0.id == session.id }
            reconcileCompletionState(for: bottle)
        }
        context.delete(session)

        if let bottle, bottle.totalMinutes == 0 {
            context.delete(bottle)
        }

        do {
            try saveContext(context)
            fetchData()
            return true
        } catch {
            context.rollback()
            errorMessage = AppLocalizer.text(.deleteSessionFailed, appLanguage)
            fetchData()
            return false
        }
    }

    func exportCSV() -> String {
        let header = "date,duration_minutes,note,bottle_number"
        let rows = allSessions.sorted { $0.date < $1.date }.map { session in
            [
                Self.csvDateFormatter.string(from: session.date),
                String(session.duration),
                csvSafeNote(session.note ?? ""),
                session.bottle.map { String($0.serialNumber) } ?? "",
            ]
            .map(csvEscaped)
            .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    func makeBackup() throws -> FocusBackup {
        guard let context = modelContext else { throw FocusWaterError.dataStoreUnavailable }
        let bottles = try context.fetch(FetchDescriptor<WaterBottle>())
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        return try FocusBackup(
            bottles: bottles.map {
                .init(
                    id: $0.id, serialNumber: $0.serialNumber, capacityMinutes: $0.capacityMinutes,
                    createdAt: $0.createdAt, completedAt: $0.completedAt)
            },
            sessions: sessions.map {
                .init(
                    id: $0.id, date: $0.date, duration: $0.duration, note: $0.note, bottleID: $0.bottle?.id,
                    timerEntryID: $0.timerEntryID)
            },
            preferences: settings.map {
                .init(
                    dailyGoalMinutes: $0.dailyGoalMinutes, languageCode: $0.languageCode,
                    appearanceMode: $0.appearanceMode)
            }
        ).validated()
    }

    /// Merge only missing identifiers; never erase or replace the user's records.
    @discardableResult
    func restoreBackup(_ backup: FocusBackup) throws -> Int {
        guard let context = modelContext else { throw FocusWaterError.dataStoreUnavailable }
        _ = try backup.validated()
        do {
            let existingBottles = try context.fetch(FetchDescriptor<WaterBottle>())
            let existingSessions = try context.fetch(FetchDescriptor<FocusSession>())
            var byID: [UUID: WaterBottle] = [:]
            existingBottles.forEach { byID[$0.id] = $0 }
            let sessionIDs = Set(existingSessions.map(\.id))
            let missingSessions = backup.sessions.filter { !sessionIDs.contains($0.id) }
            let neededBottles = Set(missingSessions.compactMap(\.bottleID))
            var nextNumber = (existingBottles.map(\.serialNumber).max() ?? 0) + 1
            var usedNumbers = Set(existingBottles.map(\.serialNumber))
            for item in backup.bottles where neededBottles.contains(item.id) {
                if let existing = byID[item.id] {
                    guard existing.capacityMinutes == item.capacityMinutes else {
                        throw FocusBackup.BackupError.conflictingRecords
                    }
                } else {
                    let number = usedNumbers.contains(item.serialNumber) ? nextNumber : item.serialNumber
                    let bottle = WaterBottle(serialNumber: number, capacityMinutes: item.capacityMinutes)
                    bottle.id = item.id
                    bottle.createdAt = item.createdAt
                    bottle.completedAt = item.completedAt
                    context.insert(bottle)
                    byID[item.id] = bottle
                    usedNumbers.insert(number)
                    nextNumber = max(nextNumber, number + 1)
                }
            }
            for item in missingSessions {
                let session = FocusSession(date: item.date, duration: item.duration, note: item.note)
                session.id = item.id
                session.timerEntryID = item.timerEntryID
                context.insert(session)
                if let id = item.bottleID, let bottle = byID[id] {
                    session.bottle = bottle
                    if bottle.sessions == nil { bottle.sessions = [] }
                    if bottle.sessions?.contains(where: { $0.id == session.id }) != true {
                        bottle.sessions?.append(session)
                    }
                }
            }
            for id in neededBottles {
                guard let bottle = byID[id] else { throw FocusBackup.BackupError.invalidFormat }
                let total = (bottle.sessions ?? []).reduce(0) { $0 + $1.duration }
                guard total <= bottle.capacityMinutes else { throw FocusBackup.BackupError.conflictingRecords }
                bottle.totalMinutes = total
                reconcileCompletionState(for: bottle)
            }
            if try context.fetchCount(FetchDescriptor<FocusSettings>()) == 0, let preferences = backup.preferences {
                context.insert(
                    FocusSettings(
                        dailyGoalMinutes: preferences.dailyGoalMinutes, languageCode: preferences.languageCode,
                        appearanceMode: preferences.appearanceMode))
            }
            try saveContext(context)
            fetchData()
            return missingSessions.count
        } catch {
            context.rollback()
            fetchData()
            throw error
        }
    }

    @discardableResult
    func savePreferences(
        hours: Int,
        minutes: Int,
        language: AppLanguage,
        appearance: AppAppearanceMode
    ) -> Bool {
        let totalMinutes = normalizedGoalMinutes(hours * 60 + minutes)
        guard let context = modelContext else { return false }

        do {
            if let settings {
                settings.dailyGoalMinutes = totalMinutes
                settings.languageCode = language.rawValue
                settings.appearanceMode = appearance.rawValue
            } else {
                let newSettings = FocusSettings(
                    dailyGoalMinutes: totalMinutes,
                    languageCode: language.rawValue,
                    appearanceMode: appearance.rawValue
                )
                context.insert(newSettings)
                settings = newSettings
            }

            dailyGoalMinutes = totalMinutes
            appLanguage = language
            appearanceMode = appearance
            needsInitialGoalSetup = false

            if let currentBottle, currentBottle.totalMinutes == 0, !currentBottle.isCompleted {
                currentBottle.capacityMinutes = totalMinutes
            }

            try saveContext(context)
            fetchData()
            return true
        } catch {
            context.rollback()
            fetchData()
            errorMessage = AppLocalizer.text(.saveGoalFailed, language)
            return false
        }
    }

    func startTimer() {
        guard !isTimerRunning else { return }

        timerStartedAt = clock.now()
        timerMonotonicStart = clock.elapsedTime()
        isTimerRunning = true
        syncTimerDisplay()
        persistTimerState()
        startTimerLoop()
    }

    func pauseTimer() {
        guard isTimerRunning else { return }

        syncTimerDisplay()
        timerAccumulatedSeconds = timerElapsedSeconds
        timerStartedAt = nil
        timerMonotonicStart = nil
        isTimerRunning = false
        timerTask?.cancel()
        timerTask = nil
        persistTimerState()
    }

    func resetTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerStartedAt = nil
        timerMonotonicStart = nil
        timerAccumulatedSeconds = 0
        timerElapsedSeconds = 0
        isTimerRunning = false
        timerEntryID = UUID()
        timerNotice = nil
        timerPersistence.clear()
    }

    func saveTimerFocus() {
        if isTimerRunning {
            pauseTimer()
        }

        let minutes = timerElapsedSeconds / 60
        guard minutes > 0 else {
            errorMessage = AppLocalizer.text(.timerMinOneMinuteError, appLanguage)
            return
        }

        guard addFocus(minutes: minutes, timerEntryID: timerEntryID) else { return }
        // Keep partial minutes; a successful save must not silently discard them.
        let remainingSeconds = timerElapsedSeconds % 60
        resetTimer()
        timerAccumulatedSeconds = remainingSeconds
        timerElapsedSeconds = remainingSeconds
        persistTimerState()
    }

    func applicationDidBecomeActive() {
        fetchData()
        refreshCloudSyncStatusWhenAvailable()
        guard isTimerRunning else { return }
        syncTimerDisplay()
        startTimerLoop()
    }

    func applicationWillResignActive() {
        if isTimerRunning {
            syncTimerDisplay()
            timerAccumulatedSeconds = timerElapsedSeconds
            timerStartedAt = clock.now()
            timerMonotonicStart = clock.elapsedTime()
        }
        persistTimerState()
        timerTask?.cancel()
        timerTask = nil
    }

    var formattedTimerDuration: String {
        let hours = timerElapsedSeconds / 3600
        let minutes = (timerElapsedSeconds % 3600) / 60
        let seconds = timerElapsedSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var trackedTimerMinutes: Int {
        timerElapsedSeconds / 60
    }

    var timerStatusText: String {
        if isTimerRunning {
            return AppLocalizer.text(.timerRunning, appLanguage)
        }
        if timerElapsedSeconds > 0 {
            return AppLocalizer.text(.timerPaused, appLanguage)
        }
        return AppLocalizer.text(.timerReady, appLanguage)
    }

    var currentBottleCapacityText: String {
        formatMinutes(currentBottle?.capacityMinutes ?? dailyGoalMinutes)
    }

    var dailyGoalHours: Int {
        dailyGoalMinutes / 60
    }

    var dailyGoalRemainingMinutes: Int {
        dailyGoalMinutes % 60
    }

    var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    var cloudSyncStatusText: String {
        if cloudTransferFailed {
            return appLanguage == .zhHans ? "同步暂未完成，数据已保存在本机" : "Sync incomplete. Your data is saved locally."
        }
        if cloudIsSyncing {
            return appLanguage == .zhHans ? "正在与 iCloud 传输数据…" : "Transferring data with iCloud…"
        }
        switch cloudSyncStatus {
        case .checking:
            return AppLocalizer.text(.iCloudSyncChecking, appLanguage)
        case .available:
            return AppLocalizer.text(.iCloudSyncAvailable, appLanguage)
        case .noAccount:
            return AppLocalizer.text(.iCloudSyncNoAccount, appLanguage)
        case .restricted:
            return AppLocalizer.text(.iCloudSyncRestricted, appLanguage)
        case .temporarilyUnavailable:
            return AppLocalizer.text(.iCloudSyncTemporary, appLanguage)
        case .unavailable:
            return AppLocalizer.text(.iCloudSyncUnavailable, appLanguage)
        case .error:
            return AppLocalizer.text(.iCloudSyncError, appLanguage)
        }
    }

    var cloudSyncStatusSymbol: String {
        switch cloudSyncStatus {
        case .checking:
            return "icloud"
        case .available:
            return "checkmark.icloud.fill"
        case .noAccount:
            return "person.crop.circle.badge.exclamationmark"
        case .restricted:
            return "lock.icloud.fill"
        case .temporarilyUnavailable:
            return "exclamationmark.icloud.fill"
        case .unavailable:
            return "icloud.slash"
        case .error:
            return "xmark.icloud.fill"
        }
    }

    func refreshCloudSyncStatus() async {
        #if DEBUG
            if screenshotModeEnabled {
                cloudSyncStatus = .unavailable
                return
            }
        #endif

        guard isCloudSyncEnabled, hasEmbeddedCodeSignature else {
            cloudSyncStatus = .unavailable
            return
        }

        cloudSyncStatus = .checking

        do {
            let status = try await CKContainer(identifier: Self.cloudKitContainerIdentifier).accountStatus()
            switch status {
            case .available:
                cloudSyncStatus = .available
            case .noAccount:
                cloudSyncStatus = .noAccount
            case .restricted:
                cloudSyncStatus = .restricted
            case .couldNotDetermine:
                cloudSyncStatus = .temporarilyUnavailable
            case .temporarilyUnavailable:
                cloudSyncStatus = .temporarilyUnavailable
            @unknown default:
                cloudSyncStatus = .error
            }
        } catch {
            cloudSyncStatus = .error
        }
    }

    private func refreshCloudSyncStatusWhenAvailable() {
        Task { [weak self] in
            await self?.refreshCloudSyncStatus()
        }
    }

    private func observeCloudChangesIfNeeded() {
        guard cloudObservers.isEmpty, isCloudSyncEnabled else { return }
        let center = NotificationCenter.default
        cloudObservers.append(
            center.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.fetchData() }
            })
        cloudObservers.append(
            center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.lastCloudTransferAt = nil
                    self.cloudTransferFailed = false
                    self.activeCloudEvents.removeAll()
                    self.cloudIsSyncing = false
                    self.fetchData()
                    await self.refreshCloudSyncStatus()
                }
            })
        cloudObservers.append(
            center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
            ) { [weak self] notification in
                guard
                    let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else { return }
                Task { @MainActor in
                    guard let self else { return }
                    if let end = event.endDate {
                        self.activeCloudEvents.remove(event.identifier)
                        if event.succeeded {
                            self.cloudTransferFailed = false
                            if event.type != .setup { self.lastCloudTransferAt = end }
                            self.fetchData()
                        } else {
                            self.cloudTransferFailed = true
                        }
                    } else {
                        self.activeCloudEvents.insert(event.identifier)
                    }
                    self.cloudIsSyncing = !self.activeCloudEvents.isEmpty
                }
            })
    }

    deinit {
        timerTask?.cancel()
        cloudObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func startTimerLoop() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self else { return }
                self.syncTimerDisplay()
            }
        }
    }

    private func syncTimerDisplay() {
        if let timerMonotonicStart {
            let delta = max(0, min(clock.elapsedTime() - timerMonotonicStart, 604_800))
            timerElapsedSeconds = min(604_800, timerAccumulatedSeconds + Int(delta))
        } else {
            timerElapsedSeconds = timerAccumulatedSeconds
        }
    }

    private func restoreTimerStateIfNeeded() {
        guard !didRestoreTimerState else { return }
        didRestoreTimerState = true

        #if DEBUG
            guard !screenshotModeEnabled else { return }
        #endif

        guard let snapshot = timerPersistence.load() else { return }
        timerEntryID = snapshot.entryID ?? UUID()
        timerAccumulatedSeconds = min(max(snapshot.accumulatedSeconds, 0), 604_800)
        if snapshot.isRunning, let startedAt = snapshot.startedAt {
            let elapsed = clock.now().timeIntervalSince(startedAt)
            if elapsed >= 0, elapsed <= 86_400 {
                timerAccumulatedSeconds = min(604_800, timerAccumulatedSeconds + Int(elapsed))
                timerStartedAt = clock.now()
                timerMonotonicStart = clock.elapsedTime()
                isTimerRunning = true
            } else {
                if elapsed > 0 {
                    timerAccumulatedSeconds = min(604_800, timerAccumulatedSeconds + Int(min(elapsed, 604_800)))
                }
                timerNotice =
                    appLanguage == .zhHans
                    ? "检测到长时间离开或系统时间变化，已暂停恢复的计时。请核对后再记入。"
                    : "A long absence or clock change was detected. The recovered timer is paused; review it before saving."
            }
        }
        if let entryID = snapshot.entryID {
            let saved = allSessions.filter { $0.timerEntryID == entryID }.reduce(0) { $0 + $1.duration }
            if saved > 0 {
                timerAccumulatedSeconds = max(0, timerAccumulatedSeconds - saved * 60)
                isTimerRunning = false
                timerStartedAt = nil
                timerMonotonicStart = nil
                timerEntryID = UUID()
            }
        }
        syncTimerDisplay()
        persistTimerState()

        if isTimerRunning {
            startTimerLoop()
        }
    }

    private func persistTimerState() {
        // A startup/recovery screen must not overwrite a timer we haven't loaded.
        guard didRestoreTimerState else { return }
        if timerElapsedSeconds == 0 && !isTimerRunning {
            timerPersistence.clear()
            return
        }

        timerPersistence.save(
            FocusTimerSnapshot(
                accumulatedSeconds: timerAccumulatedSeconds,
                startedAt: timerStartedAt,
                isRunning: isTimerRunning,
                entryID: timerEntryID
            ))
    }

    // MARK: - Statistics

    var totalBottles: Int { completedBottles.count }
    var totalFocusMinutes: Int { allSessions.reduce(0) { $0 + $1.duration } }
    var totalFocusHours: Double { Double(totalFocusMinutes) / 60.0 }

    var todayMinutes: Int {
        allSessions.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.duration }
    }

    var weekMinutes: Int {
        weeklyData.reduce(0) { $0 + $1.minutes }
    }

    var consecutiveDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(allSessions.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let latest = uniqueDays.first else { return 0 }

        let today = calendar.startOfDay(for: Date())
        if !calendar.isDate(latest, inSameDayAs: today),
            !calendar.isDate(latest, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!)
        {
            return 0
        }

        var count = 0
        var current = today
        if !uniqueDays.contains(today) {
            current = calendar.date(byAdding: .day, value: -1, to: today)!
        }

        for day in uniqueDays {
            if calendar.isDate(day, inSameDayAs: current) {
                count += 1
                current = calendar.date(byAdding: .day, value: -1, to: current)!
            } else {
                break
            }
        }
        return count
    }

    var weeklyData: [(day: String, minutes: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday
        let monday = calendar.date(byAdding: .day, value: mondayOffset, to: today)!

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let minutes =
                allSessions
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.duration }
            return (day.formatted(.dateTime.weekday(.abbreviated).locale(appLocale)), minutes)
        }
    }

    var historicalMaxDailyMinutes: Int {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allSessions) { calendar.startOfDay(for: $0.date) }
        return grouped.values.map { sessions in sessions.reduce(0) { $0 + $1.duration } }.max() ?? 0
    }

    var monthlyHeatmapData: [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -83, to: today)!

        let grouped = Dictionary(grouping: allSessions) { calendar.startOfDay(for: $0.date) }
        return (0..<84).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            let minutes = grouped[date]?.reduce(0) { $0 + $1.duration } ?? 0
            return (date, minutes)
        }
    }

    private func normalizedGoalMinutes(_ minutes: Int) -> Int {
        min(max(minutes, Self.minimumDailyGoalMinutes), Self.maximumDailyGoalMinutes)
    }

    private func reconcileCompletionState(for bottle: WaterBottle) {
        if bottle.totalMinutes >= bottle.capacityMinutes {
            bottle.totalMinutes = bottle.capacityMinutes
            bottle.isCompleted = true
            bottle.completedAt = bottle.completedAt ?? .now
        } else {
            bottle.isCompleted = false
            bottle.completedAt = nil
        }
    }

    private func normalizedNote(_ note: String?) -> String? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(4_000))
    }

    private func csvSafeNote(_ value: String) -> String {
        // Quoting alone does not prevent spreadsheet formula execution.
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        return first.map { "=+-@".contains($0) } == true ? "'" + value : value
    }

    private func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static let csvDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private var hasEmbeddedCodeSignature: Bool {
        AppStoreCoordinator.hasEmbeddedCodeSignature
    }

    func formatMinutes(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h)h" : "\(h)h\(m)m"
        }
        return "\(mins)m"
    }
}

#if DEBUG
    extension FocusViewModel {
        fileprivate var screenshotModeEnabled: Bool {
            ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_MODE"] == "1"
        }

        fileprivate var screenshotScene: String {
            ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_SCENE"] ?? "focus"
        }

        fileprivate var screenshotLanguage: AppLanguage {
            ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_LANGUAGE"] == "en" ? .english : .zhHans
        }

        fileprivate func seedScreenshotDemoDataIfNeeded(in context: ModelContext) {
            guard screenshotModeEnabled else { return }

            do {
                try context.fetch(FetchDescriptor<FocusSession>()).forEach { context.delete($0) }
                try context.fetch(FetchDescriptor<WaterBottle>()).forEach { context.delete($0) }
                try context.fetch(FetchDescriptor<FocusSettings>()).forEach { context.delete($0) }

                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let goalMinutes = 390

                let settings = FocusSettings(
                    dailyGoalMinutes: goalMinutes,
                    languageCode: screenshotLanguage.rawValue,
                    appearanceMode: ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_DARK"] == "1"
                        ? AppAppearanceMode.dark.rawValue : AppAppearanceMode.light.rawValue
                )
                context.insert(settings)

                let completedOffsets = [-18, -15, -12, -10, -8, -6, -4, -2]
                let sessionNotes =
                    screenshotLanguage == .english
                    ? [
                        "Course notes",
                        "Research reading",
                        "Deep writing",
                        "Exam prep",
                        "Product design",
                        "Code refactor",
                        "Weekly review",
                        "Quiet reading",
                    ]
                    : [
                        "整理课程笔记",
                        "阅读论文",
                        "深度写作",
                        "准备考试",
                        "产品设计",
                        "代码重构",
                        "复盘计划",
                        "无干扰阅读",
                    ]

                for (index, offset) in completedOffsets.enumerated() {
                    let bottle = WaterBottle(serialNumber: index + 1, capacityMinutes: goalMinutes)
                    bottle.totalMinutes = goalMinutes
                    bottle.isCompleted = true
                    bottle.createdAt = calendar.date(byAdding: .day, value: offset - 1, to: today) ?? today
                    bottle.completedAt = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                    bottle.sessions = []
                    context.insert(bottle)

                    let durations = [95, 125, 170]
                    for (part, duration) in durations.enumerated() {
                        let date = demoDate(
                            daysFromToday: offset,
                            hour: 9 + part * 3,
                            minute: part == 1 ? 20 : 0,
                            calendar: calendar,
                            today: today
                        )
                        let session = FocusSession(date: date, duration: duration, note: sessionNotes[index])
                        session.bottle = bottle
                        bottle.sessions?.append(session)
                        context.insert(session)
                    }
                }

                let current = WaterBottle(serialNumber: 9, capacityMinutes: goalMinutes)
                current.totalMinutes = 248
                current.createdAt = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                current.sessions = []
                context.insert(current)

                let currentSessions =
                    screenshotLanguage == .english
                    ? [
                        (duration: 55, note: "Morning reading", hour: 8, minute: 35),
                        (duration: 86, note: "Focused coding", hour: 13, minute: 10),
                        (duration: 107, note: "Project planning", hour: 19, minute: 0),
                    ]
                    : [
                        (duration: 55, note: "晨间阅读", hour: 8, minute: 35),
                        (duration: 86, note: "无干扰编码", hour: 13, minute: 10),
                        (duration: 107, note: "整理项目计划", hour: 19, minute: 0),
                    ]
                for item in currentSessions {
                    let session = FocusSession(
                        date: demoDate(
                            daysFromToday: 0, hour: item.hour, minute: item.minute, calendar: calendar, today: today),
                        duration: item.duration,
                        note: item.note
                    )
                    session.bottle = current
                    current.sessions?.append(session)
                    context.insert(session)
                }

                seedStatsOnlySessions(in: context, calendar: calendar, today: today)

                try context.save()
            } catch {
                context.rollback()
                print("Failed to seed screenshot demo data: \(error)")
            }
        }

        fileprivate func applyScreenshotSceneStateIfNeeded() {
            guard screenshotModeEnabled else { return }
            needsInitialGoalSetup = false
            appLanguage = screenshotLanguage
            appearanceMode = ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_DARK"] == "1" ? .dark : .light

            if screenshotScene == "timer" {
                timerElapsedSeconds = 18 * 60 + 32
                timerAccumulatedSeconds = timerElapsedSeconds
                isTimerRunning = true
            } else {
                timerElapsedSeconds = 0
                timerAccumulatedSeconds = 0
                isTimerRunning = false
            }
        }

        fileprivate func seedStatsOnlySessions(in context: ModelContext, calendar: Calendar, today: Date) {
            let weekday = calendar.component(.weekday, from: today)
            let mondayOffset = weekday == 1 ? -6 : 2 - weekday
            let weeklyDurations = [210, 335, 175, 420, 285, 145, 248]

            for dayIndex in 0..<7 {
                let daysFromToday = mondayOffset + dayIndex
                guard daysFromToday < 0 else { continue }
                let session = FocusSession(
                    date: demoDate(
                        daysFromToday: daysFromToday, hour: 16, minute: 15, calendar: calendar, today: today),
                    duration: weeklyDurations[dayIndex],
                    note: screenshotLanguage == .english ? "Weekly focus review" : "本周专注回顾"
                )
                context.insert(session)
            }

            for offset in stride(from: -82, through: -7, by: 3) {
                let intensity = abs(offset) % 4
                let duration = [45, 90, 150, 230][intensity]
                let session = FocusSession(
                    date: demoDate(
                        daysFromToday: offset, hour: 20, minute: intensity * 10, calendar: calendar, today: today),
                    duration: duration,
                    note: nil
                )
                context.insert(session)
            }
        }

        fileprivate func demoDate(daysFromToday: Int, hour: Int, minute: Int, calendar: Calendar, today: Date) -> Date {
            let day = calendar.date(byAdding: .day, value: daysFromToday, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
    }
#endif

private enum FocusWaterError: LocalizedError {
    case dataStoreUnavailable
}
