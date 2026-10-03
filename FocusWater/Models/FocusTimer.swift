import Foundation

struct FocusTimerSnapshot: Codable, Equatable {
    let accumulatedSeconds: Int
    let startedAt: Date?
    let isRunning: Bool
    var entryID: UUID? = nil
}

struct FocusClock {
    var now: () -> Date
    var elapsedTime: () -> TimeInterval

    static var live: FocusClock {
        let origin = ContinuousClock.now
        return FocusClock(
            now: { Date() },
            elapsedTime: {
                let value = origin.duration(to: .now).components
                return Double(value.seconds) + Double(value.attoseconds) / 1e18
            })
    }
}

struct FocusTimerPersistence {
    static let defaultKey = "com.hanzibo.FocusWater.focusTimer.v1"

    let userDefaults: UserDefaults
    let key: String
    private let isEnabled: Bool

    init(userDefaults: UserDefaults = .standard, key: String = Self.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
        #if DEBUG
            self.isEnabled = ProcessInfo.processInfo.environment["FOCUSWATER_SCREENSHOT_MODE"] != "1"
        #else
            self.isEnabled = true
        #endif
    }

    func load() -> FocusTimerSnapshot? {
        guard isEnabled else { return nil }
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FocusTimerSnapshot.self, from: data)
    }

    func save(_ snapshot: FocusTimerSnapshot) {
        guard isEnabled else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }

    func clear() {
        guard isEnabled else { return }
        userDefaults.removeObject(forKey: key)
    }
}
