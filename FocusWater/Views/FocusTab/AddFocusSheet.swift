import SwiftUI

struct AddFocusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let language: AppLanguage
    var onAdd: (Int, String?) -> Bool
    @State private var saveFailed = false
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var note: String = ""

    private let hourOptions = Array(0...8)
    private let minuteOptions = Array(0...59)

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var compactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    quickPickSection
                    durationSection
                    noteField
                    if saveFailed {
                        Text(
                            language == .zhHans
                                ? "保存未完成，内容已保留。请重试。" : "Could not save. Your entry is still here; try again."
                        )
                        .font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .frame(maxWidth: compactLayout ? .infinity : 460)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            Divider()
                .overlay(Color.separatorLine)

            addButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(Color.appBackgroundGradient.ignoresSafeArea())
        .platformMinFrame(width: 420, height: 420)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalizer.text(.addFocusTime, language))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text(AppLocalizer.text(.convertFocusSubtitle, language))
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.secondaryButtonFill))
                    .overlay(Circle().stroke(Color.cardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(AppLocalizer.text(.cancel, language))
        }
    }

    private var quickPickSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalizer.text(.quickPick, language))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.secondaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 95 : 56), spacing: 8)], spacing: 8
            ) {
                presetButtons
            }
        }
    }

    private var durationSection: some View {
        HStack(alignment: .bottom, spacing: 10) {
            pickerColumn(
                title: AppLocalizer.text(.hours, language),
                selection: $hours,
                options: hourOptions,
                formatter: formattedHours
            )
            pickerColumn(
                title: AppLocalizer.text(.minutes, language),
                selection: $minutes,
                options: minuteOptions,
                formatter: formattedMinutes
            )
        }
    }

    private var noteField: some View {
        TextField(AppLocalizer.text(.notePlaceholder, language), text: $note, axis: .vertical)
            .lineLimit(1...3)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 46)
            .onChange(of: note) { _, value in
                if value.count > 4_000 { note = String(value.prefix(4_000)) }
            }
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.glassCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
            )
    }

    private var addButton: some View {
        Button {
            if onAdd(totalMinutes, note.isEmpty ? nil : note) {
                dismiss()
            } else {
                saveFailed = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("\(AppLocalizer.text(.addFocus, language)) \(formatTime(totalMinutes))")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LiquidSheetButtonStyle(role: .primary))
        .disabled(totalMinutes == 0)
    }

    init(
        language: AppLanguage,
        initialHours: Int = 0,
        initialMinutes: Int = 30,
        initialNote: String = "",
        onAdd: @escaping (Int, String?) -> Bool
    ) {
        self.language = language
        self.onAdd = onAdd
        _hours = State(initialValue: initialHours)
        _minutes = State(initialValue: initialMinutes)
        _note = State(initialValue: initialNote)
    }

    @ViewBuilder
    private var presetButtons: some View {
        ForEach(presets, id: \.minutes) { preset in
            Button {
                hours = preset.minutes / 60
                minutes = preset.minutes % 60
            } label: {
                Text(preset.label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(totalMinutes == preset.minutes ? Color.white : Color.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(
                                totalMinutes == preset.minutes
                                    ? AnyShapeStyle(Color.primaryButtonFill) : AnyShapeStyle(Color.glassCardFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(
                                totalMinutes == preset.minutes ? Color.white.opacity(0.22) : Color.cardStroke,
                                lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(totalMinutes == preset.minutes ? .isSelected : [])
        }
    }

    private func pickerColumn<T: Hashable>(
        title: String,
        selection: Binding<T>,
        options: [T],
        formatter: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(formatter(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.glassCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity)
        }
    }

    private let presets: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("25m", 25),
        ("30m", 30),
        ("1h", 60),
        ("2h", 120),
    ]

    private func formatTime(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            if language == .zhHans {
                return m == 0 ? "\(h)小时" : "\(h)h\(m)m"
            }
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return language == .zhHans ? "\(mins)分钟" : "\(mins)m"
    }

    private func formattedHours(_ value: Int) -> String {
        language == .zhHans ? "\(value) 小时" : "\(value) h"
    }

    private func formattedMinutes(_ value: Int) -> String {
        language == .zhHans ? "\(value) 分钟" : "\(value) m"
    }

}

private struct LiquidSheetButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(role == .primary ? Color.primaryButtonFill : Color.secondaryButtonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(role == .primary ? Color.white.opacity(0.18) : Color.cardStroke, lineWidth: 1)
                    )
            )
            .foregroundStyle(role == .primary ? Color.white : Color.primaryText)
            .shadow(
                color: role == .primary
                    ? Color.accentBlue.opacity(configuration.isPressed ? 0.10 : 0.16)
                    : Color.glassShadow.opacity(configuration.isPressed ? 0.05 : 0.08),
                radius: configuration.isPressed ? 5 : 8, y: configuration.isPressed ? 2 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
