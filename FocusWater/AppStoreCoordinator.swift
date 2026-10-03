import Combine
import CryptoKit
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AppStoreMode: String, Equatable {
    case cloud
    case local
}

struct DataStoreRecoveryIssue {
    let occurredAt: Date
    let cloudErrorDescription: String
    let localErrorDescription: String
    let recoveryErrorDescription: String?
}

@MainActor
final class AppStoreCoordinator: ObservableObject {
    typealias ContainerBuilder = (Schema, URL, AppStoreMode) throws -> ModelContainer

    static let cloudKitContainerIdentifier = "iCloud.com.hanzibo.FocusWater"
    static let cloudPreferenceKey = "com.hanzibo.FocusWater.cloudSyncRequested"

    @Published private(set) var container: ModelContainer?
    @Published private(set) var cloudSyncEnabled = false
    @Published private(set) var recoveryIssue: DataStoreRecoveryIssue?
    @Published private(set) var isWorking = false
    @Published private(set) var cloudFallbackDescription: String?
    @Published private(set) var lastBackupLocation: URL?

    let storeURL: URL

    private let fileManager: FileManager
    private let containerBuilder: ContainerBuilder
    private let userDefaults: UserDefaults

    init(
        storeURL: URL? = nil,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        containerBuilder: ContainerBuilder? = nil,
        loadImmediately: Bool = true
    ) {
        let schema = Self.makeSchema()
        self.storeURL =
            storeURL
            ?? ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            ).url
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.containerBuilder = containerBuilder ?? Self.defaultContainerBuilder

        if loadImmediately {
            loadStore()
        }
    }

    func retry() {
        guard container == nil else { return }
        loadStore()
    }

    func rebuildLocalDatabase() {
        guard container == nil, !isWorking else { return }

        isWorking = true
        do {
            lastBackupLocation = try moveStoreFilesToRecoveryBackup()
            isWorking = false
            loadStore()
        } catch {
            isWorking = false
            let previous = recoveryIssue
            recoveryIssue = DataStoreRecoveryIssue(
                occurredAt: .now,
                cloudErrorDescription: previous?.cloudErrorDescription ?? "Not attempted",
                localErrorDescription: previous?.localErrorDescription ?? "Not attempted",
                recoveryErrorDescription: Self.describe(error)
            )
        }
    }

    func diagnosticsReport() -> String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let issue = recoveryIssue

        return [
            "FocusWater Data Store Diagnostics",
            "Generated: \(Date().formatted(.iso8601))",
            "App version: \(version) (\(build))",
            "Bundle identifier: \(bundle.bundleIdentifier ?? "Unknown")",
            "Operating system: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "CloudKit container: \(Self.cloudKitContainerIdentifier)",
            "Store file: \(storeURL.lastPathComponent)",
            "Cloud store error: \(issue?.cloudErrorDescription ?? cloudFallbackDescription ?? "None")",
            "Local store error: \(issue?.localErrorDescription ?? "None")",
            "Recovery error: \(issue?.recoveryErrorDescription ?? "None")",
            "Recovery backup created: \(lastBackupLocation != nil)",
            "",
            "This report contains no focus sessions, notes, or other user-created content.",
        ].joined(separator: "\n")
    }

    static func makeSchema() -> Schema {
        Schema([FocusSession.self, WaterBottle.self, FocusSettings.self])
    }

    private func loadStore() {
        guard !isWorking else { return }

        isWorking = true
        defer { isWorking = false }

        let schema = Self.makeSchema()
        var cloudRequested = userDefaults.object(forKey: Self.cloudPreferenceKey) as? Bool ?? true
        #if DEBUG
            if ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_MODE"] == "1" { cloudRequested = false }
        #endif
        if cloudRequested {
            do {
                container = try containerBuilder(schema, storeURL, .cloud)
                cloudSyncEnabled = true
                cloudFallbackDescription = nil
                recoveryIssue = nil
                return
            } catch {
                cloudFallbackDescription = Self.describe(error)
            }
        } else {
            cloudFallbackDescription = nil
        }

        do {
            container = try containerBuilder(schema, storeURL, .local)
            cloudSyncEnabled = false
            recoveryIssue = nil
        } catch {
            let localDescription = Self.describe(error)
            container = nil
            cloudSyncEnabled = false
            recoveryIssue = DataStoreRecoveryIssue(
                occurredAt: .now,
                cloudErrorDescription: cloudFallbackDescription ?? "Unknown CloudKit error",
                localErrorDescription: localDescription,
                recoveryErrorDescription: nil
            )
        }
    }

    private func moveStoreFilesToRecoveryBackup() throws -> URL? {
        let parent = storeURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: parent.path) else { return nil }

        let storeName = storeURL.lastPathComponent
        let entries = try fileManager.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: nil,
            options: []
        )
        let storeFiles = entries.filter { url in
            let name = url.lastPathComponent
            return name == storeName || name.hasPrefix("\(storeName)-") || name.hasPrefix("\(storeName).")
                || name == ".\(storeName)_SUPPORT" || name == "\(storeName)_SUPPORT"
        }
        guard !storeFiles.isEmpty else { return nil }

        let backupRoot = parent.appendingPathComponent("FocusWater Recovery Backups", isDirectory: true)
        try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        let folderName =
            ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString
        let backupDirectory = backupRoot.appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(
            at: backupDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        #if os(iOS)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: backupDirectory.path)
        #endif

        // Never touch the original store until every file has a verified copy.
        for source in storeFiles {
            let destination = backupDirectory.appendingPathComponent(source.lastPathComponent)
            try fileManager.copyItem(
                at: source,
                to: destination
            )
            try verifyCopy(source, destination)
        }
        lastBackupLocation = backupDirectory
        do {
            for source in storeFiles { try fileManager.removeItem(at: source) }
        } catch {
            // A cleanup failure must not leave the original store split in two.
            for source in storeFiles where !fileManager.fileExists(atPath: source.path) {
                try fileManager.copyItem(
                    at: backupDirectory.appendingPathComponent(source.lastPathComponent), to: source)
            }
            throw error
        }

        return backupDirectory
    }

    private func verifyCopy(_ source: URL, _ destination: URL) throws {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
        if values.isDirectory == true {
            for child in try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                try verifyCopy(child, destination.appendingPathComponent(child.lastPathComponent))
            }
        } else {
            let original = try Data(contentsOf: source, options: .mappedIfSafe)
            let copy = try Data(contentsOf: destination, options: .mappedIfSafe)
            guard SHA256.hash(data: original) == SHA256.hash(data: copy) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
    }

    private static let defaultContainerBuilder: ContainerBuilder = { schema, url, mode in
        #if DEBUG
            // Preview/demo launches must never seed or delete the real local store.
            if ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_MODE"] == "1" {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            }
        #endif
        let configuration: ModelConfiguration
        switch mode {
        case .cloud:
            // Unsigned simulator/test builds cannot safely invoke CloudKit APIs.
            guard AppStoreCoordinator.hasEmbeddedCodeSignature else { throw CocoaError(.featureUnsupported) }
            configuration = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .automatic
            )
        case .local:
            configuration = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }
        let container = try ModelContainer(for: schema, configurations: configuration)
        container.mainContext.autosaveEnabled = false
        return container
    }

    static var hasEmbeddedCodeSignature: Bool {
        #if os(macOS)
            let root = Bundle.main.bundleURL.appendingPathComponent("Contents")
        #else
            let root = Bundle.main.bundleURL
        #endif
        return FileManager.default.fileExists(atPath: root.appendingPathComponent("_CodeSignature/CodeResources").path)
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        // Descriptions/userInfo may include notes, account details, or absolute paths.
        let allowedDomains = [NSCocoaErrorDomain, NSPOSIXErrorDomain, NSURLErrorDomain, "CKErrorDomain"]
        let domain = allowedDomains.contains(nsError.domain) ? nsError.domain : "DataStoreError"
        return "\(domain) (\(nsError.code))"
    }
}

struct DataStoreDiagnosticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    let content: String

    init(content: String = "") {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let content = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = content
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}

struct DataRecoveryView: View {
    @ObservedObject var coordinator: AppStoreCoordinator

    @State private var showRebuildConfirmation = false
    @State private var showDiagnosticsExporter = false
    @State private var diagnosticsDocument: DataStoreDiagnosticsDocument?
    @State private var exportMessage: String?

    private var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }

    var body: some View {
        ZStack {
            Color.appBackgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    recoveryMark

                    VStack(spacing: 8) {
                        Text(isChinese ? "数据需要恢复" : "Your data needs attention")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                            .multilineTextAlignment(.center)

                        Text(
                            isChinese
                                ? "FocusWater 无法安全打开数据。请先重试或导出诊断信息；重建前会保留完整恢复备份。"
                                : "FocusWater couldn't safely open its data. Retry or export diagnostics first. A complete recovery backup is retained before rebuilding."
                        )
                        .font(.body)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    statusCard
                    actionCard

                    if let exportMessage {
                        Text(exportMessage)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Text(
                        isChinese
                            ? "诊断文件不包含专注记录、备注或其他用户内容。"
                            : "Diagnostics contain no focus sessions, notes, or other user content."
                    )
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .fileExporter(
            isPresented: $showDiagnosticsExporter,
            document: diagnosticsDocument,
            contentType: .plainText,
            defaultFilename: "FocusWater-Diagnostics"
        ) { result in
            switch result {
            case .success:
                exportMessage = isChinese ? "诊断文件已导出。" : "Diagnostics exported."
            case .failure(let error):
                exportMessage =
                    isChinese
                    ? "导出失败：\(error.localizedDescription)"
                    : "Export failed: \(error.localizedDescription)"
            }
        }
        .alert(
            isChinese ? "重建本地数据库？" : "Rebuild local database?",
            isPresented: $showRebuildConfirmation
        ) {
            Button(isChinese ? "取消" : "Cancel", role: .cancel) {}
            Button(isChinese ? "备份并重建" : "Back Up and Rebuild", role: .destructive) {
                coordinator.rebuildLocalDatabase()
            }
        } message: {
            Text(
                isChinese
                    ? "FocusWater 会先复制并校验完整数据库备份，再创建新数据库。未同步的记录不会自动出现在新库中，可能需要人工恢复；云端数据不会被删除。"
                    : "FocusWater first copies and verifies a complete database backup, then creates a new store. Unsynced records may require manual recovery. Cloud data is not deleted."
            )
        }
    }

    private var recoveryMark: some View {
        ZStack {
            Circle()
                .fill(Color.waterGlow.opacity(0.34))
                .frame(width: 122, height: 122)
                .blur(radius: 1)

            Circle()
                .fill(Color.glassCardFill)
                .frame(width: 94, height: 94)
                .overlay(Circle().stroke(Color.cardStroke, lineWidth: 1))
                .shadow(color: Color.accentBlue.opacity(0.14), radius: 18, y: 8)

            Image(systemName: "drop.triangle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.accentBlue)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isChinese ? "数据存储错误" : "Data storage error")
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                isChinese ? "你的数据仍被保留" : "Your data is still preserved",
                systemImage: "externaldrive.fill.badge.checkmark"
            )
            .font(.headline)
            .foregroundStyle(Color.primaryText)

            Text(
                isChinese
                    ? "当前存储模式未能打开数据库。重建前会先完成备份校验；请不要卸载应用，以免丢失本机数据。"
                    : "The current storage mode could not open the database. Backup verification comes before rebuilding. Do not uninstall the app while recovering local data."
            )
            .font(.callout)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            if let issue = coordinator.recoveryIssue {
                Divider().overlay(Color.separatorLine)
                Text(isChinese ? "错误摘要" : "Error summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Text(issue.localErrorDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.tertiaryText)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground(cornerRadius: 20, shadowRadius: 8, shadowY: 3)
    }

    private var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                coordinator.retry()
            } label: {
                recoveryButtonLabel(
                    title: isChinese ? "重试打开数据" : "Retry Opening Data",
                    systemImage: "arrow.clockwise",
                    showsProgress: coordinator.isWorking
                )
            }
            .buttonStyle(RecoveryButtonStyle(role: .primary))
            .disabled(coordinator.isWorking)

            Button {
                diagnosticsDocument = DataStoreDiagnosticsDocument(content: coordinator.diagnosticsReport())
                showDiagnosticsExporter = true
            } label: {
                recoveryButtonLabel(
                    title: isChinese ? "导出诊断信息" : "Export Diagnostics",
                    systemImage: "square.and.arrow.up",
                    showsProgress: false
                )
            }
            .buttonStyle(RecoveryButtonStyle(role: .secondary))
            .disabled(coordinator.isWorking)

            Divider().overlay(Color.separatorLine)

            Button(role: .destructive) {
                showRebuildConfirmation = true
            } label: {
                Label(isChinese ? "重建本地数据库" : "Rebuild Local Database", systemImage: "externaldrive.badge.xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .disabled(coordinator.isWorking)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardBackground(cornerRadius: 20, shadowRadius: 8, shadowY: 3)
    }

    private func recoveryButtonLabel(title: String, systemImage: String, showsProgress: Bool) -> some View {
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView().tint(.white)
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecoveryButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(role == .primary ? Color.white : Color.primaryText)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(role == .primary ? Color.primaryButtonFill : Color.secondaryButtonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(role == .primary ? Color.white.opacity(0.18) : Color.cardStroke, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
