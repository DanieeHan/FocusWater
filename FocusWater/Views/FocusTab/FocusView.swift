import SwiftUI

struct FocusView: View {
    var viewModel: FocusViewModel
    @State private var showAddSheet = false
    @State private var confirmReset = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var language: AppLanguage { viewModel.appLanguage }
    private var number: Int {
        viewModel.currentBottle?.serialNumber ?? ((viewModel.completedBottles.map(\.serialNumber).max() ?? 0) + 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(AppLocalizer.text(.focusTimer, language))
                            .font(.title2.bold())
                        Text(
                            "\(AppLocalizer.text(.today, language)) · \(viewModel.formatMinutes(viewModel.todayMinutes))"
                        )
                        .font(.body).foregroundStyle(Color.secondaryText)
                        controls
                        hero(height: 250)
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                } else if geometry.size.width >= 980 {
                    HStack(spacing: 44) {
                        hero(height: min(560, max(360, geometry.size.height - 100)))
                        controls.frame(maxWidth: 340)
                    }
                    .padding(36).frame(maxWidth: 1080)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                } else {
                    VStack(spacing: 20) {
                        hero(height: min(geometry.size.width >= 600 ? 520 : 440, max(250, geometry.size.height - 400)))
                        controls
                    }
                    .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 24)
                    .frame(maxWidth: 580)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .platformMinFrame(width: 360, height: 560)
        .background(Color.appBackgroundGradient.ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            AddFocusSheet(language: language) { minutes, note in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    viewModel.addFocus(minutes: minutes, note: note)
                }
            }
            .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(400), .large])
            .presentationDragIndicator(.visible).presentationCornerRadius(28)
        }
        .confirmationDialog(
            language == .zhHans ? "清空这段未记入的计时？" : "Discard this unsaved timer?", isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.text(.reset, language), role: .destructive) { viewModel.resetTimer() }
            Button(AppLocalizer.text(.cancel, language), role: .cancel) {}
        } message: {
            Text(language == .zhHans ? "已保存的专注记录不会受影响。" : "Your saved focus records will not be changed.")
        }
        #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_SCENE"] == "add" { showAddSheet = true }
            }
        #endif
    }

    private func hero(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            if !typeSize.isAccessibilitySize {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FOCUS WATER").font(.caption.weight(.semibold)).tracking(2.2)
                            .foregroundStyle(Color.secondaryText)
                        Text(language == .zhHans ? "让投入，有迹可循。" : "Make your focus visible.")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(AppLocalizer.text(.today, language)).font(.caption).foregroundStyle(Color.secondaryText)
                        Text(viewModel.formatMinutes(viewModel.todayMinutes))
                            .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Button {
                showAddSheet = true
            } label: {
                ZStack {
                    BottleCanvas(
                        progress: viewModel.currentBottle?.progress ?? 0, serialNumber: number,
                        isCompleted: false, size: CGSize(width: height * 0.74, height: height))
                    if viewModel.showCompletionAnimation {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Color.accentBlue)
                            Text(AppLocalizer.text(.bottleFilled, language)).font(.headline)
                        }
                        .padding(24).glassCardBackground(cornerRadius: 24).transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language == .zhHans ? "第 \(number) 瓶水，添加专注" : "Bottle \(number), add focus")
            .accessibilityValue(
                "\(viewModel.formatMinutes(viewModel.currentBottle?.totalMinutes ?? 0)) / \(viewModel.currentBottleCapacityText)"
            )
            VStack(spacing: 10) {
                let layout =
                    typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                layout {
                    Text(language == .zhHans ? "第 \(number) 瓶 · 正在积累" : "Bottle \(number) · In progress")
                        .foregroundStyle(Color.secondaryText)
                    if !typeSize.isAccessibilitySize { Spacer() }
                    Text(
                        "\(viewModel.formatMinutes(viewModel.currentBottle?.totalMinutes ?? 0)) / \(viewModel.currentBottleCapacityText)"
                    )
                    .foregroundStyle(Color.primaryText).monospacedDigit()
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
                ProgressView(value: viewModel.currentBottle?.progress ?? 0).tint(Color.accentBlue)
                    .accessibilityLabel(AppLocalizer.text(.currentBottle, language))
                Text(language == .zhHans ? "水瓶跨天积累 · 今日时长按记录日期统计" : "Bottles accumulate across days · Today uses record dates")
                    .font(.caption2).foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 16) {
                if typeSize.isAccessibilitySize {
                    timerHeading
                    timerDigits
                    startPause
                    saveTimer
                    resetTimer
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center) {
                            timerHeading
                            Spacer()
                            timerDigits
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            timerHeading
                            timerDigits
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            startPause
                            saveTimer
                            resetTimer
                        }
                        VStack(spacing: 10) {
                            startPause
                            saveTimer
                            resetTimer
                        }
                    }
                }
                if let notice = viewModel.timerNotice {
                    Text(notice).font(.caption).foregroundStyle(Color.secondaryText)
                } else {
                    Text(
                        language == .zhHans
                            ? "离开应用也会继续计时 · 满 1 分钟即可记入" : "Continues in the background · Save after 1 minute"
                    )
                    .font(.caption2).foregroundStyle(Color.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18).glassCardBackground(cornerRadius: 24, shadowRadius: 8, shadowY: 3)
            Button {
                showAddSheet = true
            } label: {
                Label(language == .zhHans ? "补记一段专注" : "Log a focus session", systemImage: "plus")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Color.accentBlue).keyboardShortcut("n", modifiers: .command)
        }
    }
    private var timerHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppLocalizer.text(.focusTimer, language)).font(.headline)
            Label(viewModel.timerStatusText, systemImage: viewModel.isTimerRunning ? "circle.inset.filled" : "clock")
                .font(.caption).foregroundStyle(Color.secondaryText)
        }
    }
    private var timerDigits: some View {
        Text(viewModel.formattedTimerDuration)
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            .accessibilityLabel(language == .zhHans ? "已计时" : "Elapsed time")
            .accessibilityValue(viewModel.formattedTimerDuration)
    }
    private var startPause: some View {
        Button {
            if viewModel.isTimerRunning { viewModel.pauseTimer() } else { viewModel.startTimer() }
        } label: {
            Label(
                viewModel.isTimerRunning ? AppLocalizer.text(.pause, language) : AppLocalizer.text(.start, language),
                systemImage: viewModel.isTimerRunning ? "pause.fill" : "play.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(FocusActionStyle(primary: !viewModel.isTimerRunning))
    }
    private var saveTimer: some View {
        Button {
            viewModel.saveTimerFocus()
        } label: {
            Text(AppLocalizer.text(.save, language)).frame(maxWidth: .infinity)
        }
        .buttonStyle(FocusActionStyle(primary: viewModel.isTimerRunning && viewModel.trackedTimerMinutes > 0))
        .disabled(viewModel.trackedTimerMinutes == 0)
    }
    private var resetTimer: some View {
        Button {
            confirmReset = true
        } label: {
            Image(systemName: "arrow.counterclockwise").frame(minWidth: 20)
        }
        .buttonStyle(FocusActionStyle(primary: false))
        .disabled(viewModel.timerElapsedSeconds == 0 && !viewModel.isTimerRunning)
        .accessibilityLabel(AppLocalizer.text(.reset, language))
    }
}

struct FocusActionStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Color.primaryText)
            .padding(.horizontal, 14).padding(.vertical, 13).frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 15).fill(primary ? Color.primaryButtonFill : Color.secondaryButtonFill)
            )
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.38)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
