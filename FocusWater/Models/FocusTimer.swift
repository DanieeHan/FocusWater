import Foundation

struct FocusTimerSnapshot: Codable, Equatable {
    let accumulatedSeconds: Int
    let startedAt: Date?
    let isRunning: Bool
    var entryID: UUID? = nil
    // Optional so timers saved by older versions still decode.
    var intervals: [FocusTimerInterval]? = nil
}

/// Only active time is stored; pauses never become part of a focus interval.
struct FocusTimerInterval: Codable, Equatable {
    let startedAt: Date
    let durationSeconds: TimeInterval
}

struct FocusDatedMinutes {
    let date: Date
    let minutes: Int
}

struct FocusTimerSavePlan {
    let records: [FocusDatedMinutes]
    let remainingIntervals: [FocusTimerInterval]
}

enum FocusTimerAccounting {
    static let maximumSeconds: TimeInterval = 604_800

    static func duration(of intervals: [FocusTimerInterval]) -> TimeInterval {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }

    static func normalized(_ intervals: [FocusTimerInterval]) -> [FocusTimerInterval] {
        var remaining = maximumSeconds
        return intervals.compactMap { interval in
            guard interval.startedAt.timeIntervalSinceReferenceDate.isFinite,
                interval.durationSeconds.isFinite, interval.durationSeconds > 0, remaining > 0
            else { return nil }
            let seconds = min(interval.durationSeconds, remaining)
            remaining -= seconds
            return FocusTimerInterval(startedAt: interval.startedAt, durationSeconds: seconds)
        }
    }

    /// Consume chronologically, including across pauses, while retaining the dates of the tail.
    static func remaining(after seconds: TimeInterval, in intervals: [FocusTimerInterval]) -> [FocusTimerInterval] {
        partition(intervals, taking: seconds).remaining
    }

    static func savePlan(for intervals: [FocusTimerInterval], calendar: Calendar = .current) -> FocusTimerSavePlan {
        let minutes = Int(duration(of: intervals)) / 60
        let portions = partition(intervals, taking: Double(minutes * 60))
        var byDay: [Date: (date: Date, seconds: TimeInterval)] = [:]
        for interval in portions.taken {
            var cursor = interval.startedAt
            var remaining = interval.durationSeconds
            while remaining > 0 {
                guard let day = calendar.dateInterval(of: .day, for: cursor), day.end > cursor else { break }
                let seconds = min(remaining, day.end.timeIntervalSince(cursor))
                let existing = byDay[day.start]
                byDay[day.start] = (min(existing?.date ?? cursor, cursor), (existing?.seconds ?? 0) + seconds)
                remaining -= seconds
                cursor = day.end
            }
        }

        // Records have minute precision. Largest remainders preserve the saved total
        // without stranding a 30 s + 30 s session on opposite sides of midnight.
        // Equal remainders go to the later day.
        var allocated = byDay.mapValues { Int($0.seconds / 60) }
        let extra = minutes - allocated.values.reduce(0, +)
        let ranked = byDay.keys.sorted { left, right in
            let leftRemainder = byDay[left]!.seconds.truncatingRemainder(dividingBy: 60)
            let rightRemainder = byDay[right]!.seconds.truncatingRemainder(dividingBy: 60)
            if abs(leftRemainder - rightRemainder) < 0.000_001 { return left > right }
            return leftRemainder > rightRemainder
        }
        for day in ranked.prefix(max(0, extra)) { allocated[day, default: 0] += 1 }
        let records = byDay.keys.sorted().compactMap { day -> FocusDatedMinutes? in
            guard let count = allocated[day], count > 0 else { return nil }
            return FocusDatedMinutes(date: byDay[day]!.date, minutes: count)
        }
        return FocusTimerSavePlan(records: records, remainingIntervals: portions.remaining)
    }

    private static func partition(_ intervals: [FocusTimerInterval], taking seconds: TimeInterval)
        -> (taken: [FocusTimerInterval], remaining: [FocusTimerInterval])
    {
        var toTake = max(0, seconds)
        var taken: [FocusTimerInterval] = []
        var remaining: [FocusTimerInterval] = []
        for interval in intervals {
            let consumed = min(toTake, interval.durationSeconds)
            if consumed > 0 {
                taken.append(FocusTimerInterval(startedAt: interval.startedAt, durationSeconds: consumed))
                toTake -= consumed
            }
            let tail = interval.durationSeconds - consumed
            if tail > 0 {
                remaining.append(
                    FocusTimerInterval(startedAt: interval.startedAt.addingTimeInterval(consumed), durationSeconds: tail))
            }
        }
        return (taken, remaining)
    }
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
