import SwiftUI

struct EditFocusSessionSheet: View {
    let session: FocusSession
    let language: AppLanguage
    let onSave: (Date, Int, String?) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var duration: Int
    @State private var note: String

    init(
        session: FocusSession,
        language: AppLanguage,
        onSave: @escaping (Date, Int, String?) -> Bool
    ) {
        self.session = session
        self.language = language
        self.onSave = onSave
        _date = State(initialValue: session.date)
        _duration = State(initialValue: session.duration)
        _note = State(initialValue: session.note ?? "")
    }

    private var maximumDuration: Int {
        session.duration + (session.bottle?.remainingMinutes ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        AppLocalizer.text(.sessionDate, language),
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Stepper(value: $duration, in: 1...max(maximumDuration, 1)) {
                        HStack {
                            Text(AppLocalizer.text(.focused, language))
                            Spacer()
                            Text(formattedDuration)
                                .fontDesign(.rounded)
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    TextField(AppLocalizer.text(.notePlaceholder, language), text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(AppLocalizer.text(.editSession, language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalizer.text(.cancel, language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalizer.text(.save, language)) {
                        if onSave(date, duration, note) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .platformMinFrame(width: 360, height: 360)
    }

    private var formattedDuration: String {
        let hours = duration / 60
        let minutes = duration % 60
        if hours == 0 {
            return language == .zhHans ? "\(minutes) 分钟" : "\(minutes) min"
        }
        if minutes == 0 {
            return language == .zhHans ? "\(hours) 小时" : "\(hours) hr"
        }
        return language == .zhHans ? "\(hours) 小时 \(minutes) 分钟" : "\(hours) hr \(minutes) min"
    }
}
