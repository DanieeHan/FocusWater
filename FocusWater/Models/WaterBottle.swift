import Foundation
import SwiftData

@Model
final class WaterBottle {
    static let legacyDefaultCapacityMinutes = 480

    var id: UUID = UUID()
    var serialNumber: Int = 1
    var totalMinutes: Int = 0
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    @Relationship(deleteRule: .nullify) var sessions: [FocusSession]?
    var capacityMinutes: Int = WaterBottle.legacyDefaultCapacityMinutes

    var progress: Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(Double(totalMinutes) / Double(capacityMinutes), 1.0)
    }

    var remainingMinutes: Int {
        max(capacityMinutes - totalMinutes, 0)
    }

    init(serialNumber: Int, capacityMinutes: Int) {
        self.id = UUID()
        self.serialNumber = serialNumber
        self.totalMinutes = 0
        self.isCompleted = false
        self.createdAt = .now
        self.capacityMinutes = max(capacityMinutes, 1)
        self.sessions = []
    }
}
