import SwiftData
import SwiftUI

#if os(macOS)
    import AppKit
#endif

@main
struct FocusWaterApp: App {
    @StateObject private var storeCoordinator = AppStoreCoordinator()
    @State private var viewModel = FocusViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootContent
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: viewModel.applicationDidBecomeActive()
                    case .inactive, .background: viewModel.applicationWillResignActive()
                    @unknown default: break
                    }
                }
        }
        #if os(macOS)
            .windowResizability(.contentMinSize)
            .defaultSize(width: 420, height: 620)
        #endif

        #if os(macOS)
            MenuBarExtra {
                menuBarContent
            } label: {
                Label(menuBarTitle, systemImage: "drop.fill")
            }
        #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        if let container = storeCoordinator.container {
            ContentView(viewModel: viewModel, cloudSyncEnabled: storeCoordinator.cloudSyncEnabled)
                .modelContainer(container)
        } else if storeCoordinator.recoveryIssue != nil {
            DataRecoveryView(coordinator: storeCoordinator)
        } else {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackgroundGradient.ignoresSafeArea())
        }
    }

    #if os(macOS)
        @ViewBuilder
        private var menuBarContent: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(menuBarTitle)
                    .font(.headline)

                Divider()

                if let container = storeCoordinator.container {
                    MenuBarStatsView()
                        .modelContainer(container)
                } else {
                    Text(menuBarLanguage == .zhHans ? "数据需要恢复" : "Data needs attention")
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button(AppLocalizer.text(.settings, menuBarLanguage)) {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.isKeyWindow || !$0.isMiniaturized }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                Button(AppLocalizer.text(.menuOpenMainWindow, menuBarLanguage)) {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.isKeyWindow || !$0.isMiniaturized }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                Button(AppLocalizer.text(.menuQuit, menuBarLanguage)) {
                    NSApp.terminate(nil)
                }
            }
            .padding()
            .frame(width: 200)
        }

        private var menuBarLanguage: AppLanguage {
            guard let container = storeCoordinator.container else {
                return .defaultValue
            }
            if let settings = try? container.mainContext.fetch(
                FetchDescriptor<FocusSettings>(sortBy: [SortDescriptor(\.createdAt)])),
                let first = settings.first
            {
                return AppLanguage.fromStored(first.languageCode)
            }
            return .defaultValue
        }

        private var menuBarTitle: String {
            AppLocalizer.text(.appTitle, menuBarLanguage)
        }
    #endif
}

#if os(macOS)
    struct MenuBarStatsView: View {
        @Query private var sessions: [FocusSession]
        @Query private var bottles: [WaterBottle]
        @Query(sort: \FocusSettings.createdAt) private var settings: [FocusSettings]

        private var language: AppLanguage {
            AppLanguage.fromStored(settings.first?.languageCode)
        }

        private var todayMinutes: Int {
            sessions
                .filter { Calendar.current.isDateInToday($0.date) }
                .reduce(0) { $0 + $1.duration }
        }

        private var completedBottles: Int {
            bottles.filter(\.isCompleted).count
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(AppLocalizer.text(.menuToday, language))
                    Spacer()
                    Text(formatMinutes(todayMinutes))
                        .fontWeight(.medium)
                }
                HStack {
                    Text(AppLocalizer.text(.menuCompleted, language))
                    Spacer()
                    Text(language == .zhHans ? "\(completedBottles) 瓶" : "\(completedBottles)")
                        .fontWeight(.medium)
                }
            }
            .font(.callout)
        }

        private func formatMinutes(_ mins: Int) -> String {
            if mins >= 60 {
                let h = mins / 60
                let m = mins % 60
                return m == 0 ? "\(h)h" : "\(h)h\(m)m"
            }
            return "\(mins)m"
        }
    }
#endif
