import SwiftData
import SwiftUI

struct ContentView: View {
    let cloudSyncEnabled: Bool

    @State private var viewModel: FocusViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showGoalSetup = false
    @State private var selectedTab: Int

    init(viewModel: FocusViewModel, cloudSyncEnabled: Bool = true) {
        _viewModel = State(initialValue: viewModel)
        self.cloudSyncEnabled = cloudSyncEnabled
        _selectedTab = State(initialValue: Self.initialSelectedTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FocusView(viewModel: viewModel)
                .tabItem {
                    Label(AppLocalizer.text(.focusTab, viewModel.appLanguage), systemImage: "drop.fill")
                }
                .tag(0)

            WarehouseView(viewModel: viewModel)
                .tabItem {
                    Label(AppLocalizer.text(.warehouseTab, viewModel.appLanguage), systemImage: "archivebox.fill")
                }
                .tag(1)

            StatsView(viewModel: viewModel)
                .tabItem {
                    Label(AppLocalizer.text(.statsTab, viewModel.appLanguage), systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label(AppLocalizer.text(.settings, viewModel.appLanguage), systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(Color.accentBlue)
        .preferredColorScheme(viewModel.preferredColorScheme)
        .transaction {
            if reduceMotion {
                $0.animation = nil
                $0.disablesAnimations = true
            }
        }
        .onAppear {
            viewModel.configure(with: modelContext, cloudSyncEnabled: cloudSyncEnabled)
            showGoalSetup = viewModel.needsInitialGoalSetup
        }
        .onChange(of: viewModel.needsInitialGoalSetup) { _, newValue in
            showGoalSetup = newValue
        }
        .alert(
            AppLocalizer.text(.operationNotCompleted, viewModel.appLanguage),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.clearError()
                    }
                }
            )
        ) {
            Button(AppLocalizer.text(.confirm, viewModel.appLanguage), role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .goalSetupPresentation(isPresented: $showGoalSetup) {
            DailyGoalSetupSheet(
                initialHours: viewModel.dailyGoalHours,
                initialMinutes: viewModel.dailyGoalRemainingMinutes,
                initialLanguage: viewModel.appLanguage,
                initialAppearance: viewModel.appearanceMode
            ) { hours, minutes, language, appearance in
                if viewModel.savePreferences(hours: hours, minutes: minutes, language: language, appearance: appearance)
                {
                    showGoalSetup = false
                }
            }
            .interactiveDismissDisabled(viewModel.needsInitialGoalSetup)
        }
    }

    private static var initialSelectedTab: Int {
        #if DEBUG
            switch ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_SCENE"] {
            case "warehouse":
                return 1
            case "stats", "records":
                return 2
            case "settings", "privacy":
                return 3
            default:
                return 0
            }
        #else
            return 0
        #endif
    }
}

extension View {
    @ViewBuilder
    fileprivate func goalSetupPresentation<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
            sheet(isPresented: isPresented, content: content)
        #else
            fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}
