import XCTest

@testable import RxClipsCore

class EngineSignalTests: XCTestCase {
    @MainActor
    func testEmitAndOnce() async {
        // Create a basic repository
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: []
        )

        // Initialize engine
        let engine = Engine(repository: repository)

        // Test data
        let testEventName = "test-event"
        let testData: [String: Any] = ["key": "value", "number": 42]

        // Create a task to wait for the event
        let onceTask = Task {
            return await engine.once(testEventName)
        }

        // Give the once task time to register
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Emit the event
        await engine.emit(testEventName, data: testData)

        // Get the data from the once task
        let receivedData = await onceTask.value

        // Verify the data
        XCTAssertEqual(receivedData["key"] as? String, "value")
        XCTAssertEqual(receivedData["number"] as? Int, 42)
    }

    @MainActor
    func testOnceIsTriggeredOnlyOnce() async {
        // Create a basic repository
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: []
        )

        // Initialize engine
        let engine = Engine(repository: repository)

        // Test event name
        let testEventName = "single-trigger-event"

        // Create two tasks that will wait for the same event
        let firstOnceTask = Task {
            return await engine.once(testEventName)
        }

        let secondOnceTask = Task {
            return await engine.once(testEventName)
        }

        // Give both tasks time to register
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Emit the event once with first data
        let firstData: [String: Any] = ["id": 1]
        await engine.emit(testEventName, data: firstData)

        // Emit the event again with different data
        let secondData: [String: Any] = ["id": 2]
        await engine.emit(testEventName, data: secondData)

        // Get the data from both tasks
        let firstReceivedData = await firstOnceTask.value
        let secondReceivedData = await secondOnceTask.value

        // First task should get the first data
        XCTAssertEqual(firstReceivedData["id"] as? Int, 1)

        // Second task should get the second data
        XCTAssertEqual(secondReceivedData["id"] as? Int, 2)
    }

    @MainActor
    func testEmitWithNoListeners() async {
        // Create a basic repository
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: []
        )

        // Initialize engine
        let engine = Engine(repository: repository)

        // This should not throw any errors even though there are no listeners
        await engine.emit("no-listeners-event", data: ["test": true])

        // If we get here, the test passed (no errors were thrown)
        XCTAssertTrue(true)
    }
}
