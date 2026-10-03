import SwiftUI
import UniformTypeIdentifiers

struct DailyGoalSetupSheet: View {
    let initialHours: Int
    let initialMinutes: Int
    let initialLanguage: AppLanguage
    let initialAppearance: AppAppearanceMode
    let mode: Mode
    let onSave: (Int, Int, AppLanguage, AppAppearanceMode) -> Void

    @State private var hours: Int
    @State private var minutes: Int
    @State private var language: AppLanguage
    @State private var appearance: AppAppearanceMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case onboarding
        case settings
    }

    init(
        initialHours: Int,
        initialMinutes: Int,
        initialLanguage: AppLanguage,
        initialAppearance: AppAppearanceMode,
        mode: Mode = .onboarding,
        onSave: @escaping (Int, Int, AppLanguage, AppAppearanceMode) -> Void
    ) {
        self.initialHours = initialHours
        self.initialMinutes = initialMinutes
        self.initialLanguage = initialLanguage
        self.initialAppearance = initialAppearance
        self.mode = mode
        self.onSave = onSave
        _hours = State(initialValue: max(initialHours, 1))
        _minutes = State(initialValue: initialMinutes)
        _language = State(initialValue: initialLanguage)
        _appearance = State(initialValue: initialAppearance)
    }

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var formattedGoal: String {
        let hoursLabel = AppLocalizer.text(.hours, language)
        let minutesLabel = AppLocalizer.text(.minutes, language)
        if minutes == 0 {
            return "\(hours) \(hoursLabel)"
        }
        return "\(hours) \(hoursLabel) \(minutes) \(minutesLabel)"
    }

    private var compactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            Color.appBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: compactLayout ? 18 : 22) {
                    header
                    goalSection
                    languageSection
                    appearanceSection
                    capacitySection
                }
                .padding(.horizontal, compactLayout ? 20 : 28)
                .padding(.top, compactLayout ? 20 : 28)
                .padding(.bottom, 104)
                .frame(maxWidth: compactLayout ? .infinity : 460, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            bottomSaveBar
        }
        .onChange(of: hours) { _, newValue in
            if newValue == 18 && minutes > 0 {
                minutes = 0
            }
        }
        .onChange(of: minutes) { _, newValue in
            if hours == 18 && newValue > 0 {
                minutes = 0
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(titleText)
                    .font(.system(size: compactLayout ? 26 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primaryText)
                Text(subtitleText)
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if mode == .settings {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.controlBackground)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalizer.text(.close, language))
            }
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

    private var bottomSaveBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.separatorLine)

            Button {
                onSave(hours, minutes, language, appearance)
            } label: {
                Label(primaryButtonText, systemImage: mode == .onboarding ? "drop.fill" : "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GoalPrimaryButtonStyle())
            .disabled(!(60...1080).contains(totalMinutes))
            .padding(.horizontal, compactLayout ? 20 : 28)
            .padding(.vertical, 12)
        }
        .background(Color.groupedBackground)
    }

    private var titleText: String {
        switch mode {
        case .onboarding:
            return AppLocalizer.text(.setDailyGoal, language)
        case .settings:
            return AppLocalizer.text(.settings, language)
        }
    }

    private var subtitleText: String {
        switch mode {
        case .onboarding:
            return AppLocalizer.text(.goalIntro, language)
        case .settings:
            return AppLocalizer.text(.settingsSubtitle, language)
        }
    }

    private var primaryButtonText: String {
        switch mode {
        case .onboarding:
            return AppLocalizer.text(.startFirstBottle, language)
        case .settings:
            return AppLocalizer.text(.saveSettings, language)
        }
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

struct GoalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primaryButtonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(
                color: Color.accentBlue.opacity(configuration.isPressed ? 0.10 : 0.16),
                radius: configuration.isPressed ? 5 : 8, y: configuration.isPressed ? 2 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
