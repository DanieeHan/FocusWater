import Foundation
import XCTest

@main
struct ModelTestMain {
    @MainActor
    static func main() {
        let suite = XCTestSuite(forTestCaseClass: FocusViewModelTests.self)
        suite.run()
        guard let run = suite.testRun else { fatalError("No XCTest run was created") }
        print("Standalone macOS XCTest: \(run.executionCount) executed; \(run.totalFailureCount) failures.")
        exit(run.hasSucceeded && run.executionCount > 0 ? 0 : 1)
    }
}
