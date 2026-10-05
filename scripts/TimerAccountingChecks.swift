import Foundation

@main
struct TimerAccountingChecks {
    static func main() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
            utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
        }
        func interval(_ start: Date, _ seconds: TimeInterval) -> FocusTimerInterval {
            FocusTimerInterval(startedAt: start, durationSeconds: seconds)
        }
        func plan(_ intervals: [FocusTimerInterval]) -> FocusTimerSavePlan {
            FocusTimerAccounting.savePlan(for: intervals, calendar: utc)
        }
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }

        let midnight = plan([interval(date(1, 23, 30), 3_600)])
        expect(midnight.records.map(\.minutes) == [30, 30], "Hour crossing midnight must split 30 / 30")
        expect(midnight.records.map { utc.component(.day, from: $0.date) } == [1, 2], "Both days must be present")

        let tied = plan([interval(date(1, 23, 59, 30), 60)])
        expect(tied.records.map(\.minutes) == [1], "30 + 30 seconds must remain savable")
        expect(utc.component(.day, from: tied.records[0].date) == 2, "Equal remainders go to the later day")

        let earlier = plan([interval(date(1, 23, 59, 20), 60)])
        expect(utc.component(.day, from: earlier.records[0].date) == 1, "Larger remainder must win")

        let paused = plan([interval(date(1, 23, 58, 58), 62), interval(date(2, 0, 5), 63)])
        expect(paused.records.map(\.minutes) == [1, 1], "Paused time must not fill the gap")
        expect(FocusTimerAccounting.duration(of: paused.remainingIntervals) == 5, "Five-second tail must survive")
        expect(paused.remainingIntervals[0].startedAt == date(2, 0, 5, 58), "Tail must keep its actual start")

        let delayed = plan([interval(date(1, 10), 125)])
        expect(delayed.records[0].date == date(1, 10), "Saving later must preserve the focus date")
        expect(delayed.remainingIntervals[0].startedAt == date(1, 10, 2), "Remainder keeps its date")

        let fractional = plan([interval(date(1, 10), 30.25), interval(date(1, 11), 30.25)])
        expect(fractional.records.map(\.minutes) == [1], "Fractional pauses must add correctly")
        expect(abs(FocusTimerAccounting.duration(of: fractional.remainingIntervals) - 0.5) < 0.000_001,
               "Subsecond tail must survive")

        let recovered = FocusTimerAccounting.remaining(after: 120, in: [interval(date(1, 23, 58, 58), 62), interval(date(2, 0, 5), 63)])
        expect(recovered == paused.remainingIntervals, "Commit recovery must consume the same prefix as saving")

        let legacy = try JSONDecoder().decode(FocusTimerSnapshot.self,
            from: Data("{\"accumulatedSeconds\":40,\"isRunning\":false}".utf8))
        expect(legacy.intervals == nil && legacy.accumulatedSeconds == 40, "Legacy snapshots must decode")
        let snapshot = FocusTimerSnapshot(accumulatedSeconds: 125, startedAt: nil, isRunning: false,
                                         entryID: UUID(), intervals: [interval(date(1, 10), 125.25)])
        let decoded = try JSONDecoder().decode(FocusTimerSnapshot.self, from: JSONEncoder().encode(snapshot))
        expect(snapshot == decoded, "Interval snapshots must round-trip exactly")

        let bounded = FocusTimerAccounting.normalized([
            interval(date(1), -.infinity), interval(date(1), .nan), interval(date(1), 700_000), interval(date(2), 5)])
        expect(FocusTimerAccounting.duration(of: bounded) == 604_800, "Restored intervals must respect the seven-day cap")

        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        for (month, day, expected) in [(3, 8, 23 * 60), (11, 1, 25 * 60)] {
            let start = newYork.date(from: DateComponents(year: 2026, month: month, day: day))!
            let end = newYork.date(byAdding: .day, value: 1, to: start)!
            let result = FocusTimerAccounting.savePlan(for: [interval(start, end.timeIntervalSince(start))], calendar: newYork)
            expect(result.records.map(\.minutes) == [expected], "Calendar-day split must respect daylight saving transitions")
        }

        // Varied pauses, dates and fractional durations check conservation, not implementation details.
        for seed in 0..<1_000 {
            var intervals: [FocusTimerInterval] = []
            for index in 0..<(1 + seed % 7) {
                let offset = Double((seed * 113 + index * 83_777) % 500_000)
                let wholeSeconds = Double((seed * 71 + index * 137) % 7_200)
                let seconds = wholeSeconds + Double(index % 4) * 0.25
                if seconds > 0 { intervals.append(interval(date(1).addingTimeInterval(offset), seconds)) }
            }
            let result = plan(intervals)
            let total = FocusTimerAccounting.duration(of: intervals)
            let saved = result.records.reduce(0) { $0 + $1.minutes }
            let tail = FocusTimerAccounting.duration(of: result.remainingIntervals)
            expect(saved == Int(total) / 60, "Every savable minute must be conserved")
            expect(abs(total - Double(saved * 60) - tail) < 0.000_001, "Saved plus remaining seconds must equal elapsed time")
            expect(tail >= 0 && tail < 60, "Only the global subminute tail may remain")
            expect(result.records.allSatisfy { $0.minutes > 0 }, "Records must stay compatible with minute-based backups")
        }
        print("Timer accounting: 12 regression scenarios and 1,000 conservation cases passed.")
    }
}
