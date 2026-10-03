import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var duration: Int = 0
    var note: String?
    // A durable receipt prevents a restored timer from being recorded twice.
    var timerEntryID: UUID?
    var bottle: WaterBottle?

    init(date: Date = .now, duration: Int, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.note = note
    }
}
