import Foundation
import SwiftData

@Model
final class FocusSettings {
    var id: UUID = UUID()
    var dailyGoalMinutes: Int = WaterBottle.legacyDefaultCapacityMinutes
    var languageCode: String = AppLanguage.defaultValue.rawValue
    var appearanceMode: String = AppAppearanceMode.system.rawValue
    var createdAt: Date = Date()

    init(
        dailyGoalMinutes: Int,
        languageCode: String = AppLanguage.defaultValue.rawValue,
        appearanceMode: String = AppAppearanceMode.system.rawValue
    ) {
        self.id = UUID()
        self.dailyGoalMinutes = dailyGoalMinutes
        self.languageCode = languageCode
        self.appearanceMode = appearanceMode
        self.createdAt = .now
    }
}
