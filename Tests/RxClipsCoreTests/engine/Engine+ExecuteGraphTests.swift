import XCTest

@testable import RxClipsCore

class EngineExecuteGraphTests: XCTestCase {
    func testExecuteGraphWithoutDependencies() async throws {
        // Create repository with numbered echo commands for easy testing
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo \"1\"")), on: .setup),
                .init(script: .bash(.init(command: "echo \"5\"")), on: .teardown),
            ],
            jobs: [
                .init(
                    id: "job1", name: "Test Job",
                    steps: [
                        .init(
                            name: "Main Step",
                            script: .bash(.init(command: "echo \"3\"")),
                            lifecycle: [
                                .init(script: .bash(.init(command: "echo \"2\"")), on: .beforeStep),
                                .init(script: .bash(.init(command: "echo \"4\"")), on: .afterStep),
                            ]
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                )
            ]
        )

        // Initialize and parse repository
        let engine = Engine(repository: repository, baseURL: URL(string: "https://example.com")!)
        try await engine.parseRepository()

        // Execute and collect results
        let executeStream = try await engine.executeGraph(node: engine.rootNode!)

        var resultOutputs: [String] = []
        var nextStepCount = 0

        for try await result in executeStream {
            switch result {
            case .bash(let bashResult):
                resultOutputs.append(
                    bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            case .nextStep:
                nextStepCount += 1
            default:
                continue
            }
        }

        // Verify results
        XCTAssertEqual(nextStepCount, 5)  // Should have 5 step events
        XCTAssertEqual(resultOutputs.count, 5)  // Should have 5 outputs

        // Verify the output order
        XCTAssertTrue(resultOutputs.contains("1"))
        XCTAssertTrue(resultOutputs.contains("2"))
        XCTAssertTrue(resultOutputs.contains("3"))
        XCTAssertTrue(resultOutputs.contains("4"))
        XCTAssertTrue(resultOutputs.contains("5"))
    }

    func testExecuteGraphWithDependencies() async throws {
        // Create repository with numbered echo commands for easy testing
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                Job(
                    id: "job1", name: "Test Job",
                    steps: [
                        .init(
                            name: "Main Step",
                            script: .bash(.init(command: "echo \"1\""))
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
                Job(
                    id: "job2", name: "Test Job 2",
                    steps: [
                        .init(
                            name: "Main Step",
                            script: .bash(.init(command: "echo \"2\""))
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
                Job(
                    id: "job3", name: "Test Job 3",
                    steps: [
                        .init(
                            name: "Main Step",
                            script: .bash(.init(command: "echo \"3\""))
                        )
                    ],
                    needs: ["job1", "job2"], environment: [:], lifecycle: [], form: nil
                ),
            ]
        )

        // Initialize and parse repository
        let engine = Engine(repository: repository, baseURL: URL(string: "https://example.com")!)
        try await engine.parseRepository()

        // Execute and collect results
        let executeStream = try await engine.executeGraph(node: engine.rootNode!)

        var resultOutputs: [String] = []
        var nextStepCount = 0

        for try await result in executeStream {
            switch result {
            case .bash(let bashResult):
                resultOutputs.append(
                    bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            case .nextStep:
                nextStepCount += 1
            default:
                continue
            }
        }

        // Verify results
        XCTAssertEqual(nextStepCount, 3)  // Should have 3 step events
        XCTAssertEqual(resultOutputs.count, 3)  // Should have 3 outputs

        // Verify the output order
        XCTAssertTrue(resultOutputs.contains("1"))
        XCTAssertTrue(resultOutputs.contains("2"))
        XCTAssertTrue(resultOutputs.contains("3"))
    }

    func testExecuteGraphWithSlowerDependency() async throws {
        // Create repository with jobs where job1 is slower than job2
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                Job(
                    id: "job1", name: "Slower Job",
                    steps: [
                        .init(
                            name: "Slow Step",
                            script: .bash(.init(command: "sleep 1 && echo \"1\""))
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
                Job(
                    id: "job2", name: "Faster Job",
                    steps: [
                        .init(
                            name: "Fast Step",
                            script: .bash(.init(command: "echo \"2\""))
                        )
                    ],
                    needs: [], environment: [:], lifecycle: [], form: nil
                ),
                Job(
                    id: "job3", name: "Dependent Job",
                    steps: [
                        .init(
                            name: "Final Step",
                            script: .bash(.init(command: "echo \"3\""))
                        )
                    ],
                    needs: ["job1", "job2"], environment: [:], lifecycle: [], form: nil
                ),
            ]
        )

        // Initialize and parse repository
        let engine = Engine(repository: repository, baseURL: URL(string: "https://example.com")!)
        try await engine.parseRepository()

        // Execute and collect results
        let executeStream = try await engine.executeGraph(node: engine.rootNode!)

        var resultOutputs: [String] = []
        var nextStepCount = 0

        for try await result in executeStream {
            switch result {
            case .bash(let bashResult):
                resultOutputs.append(
                    bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            case .nextStep:
                nextStepCount += 1
            default:
                continue
            }
        }

        // Verify results
        XCTAssertEqual(nextStepCount, 3)  // Should have 3 step events
        XCTAssertEqual(resultOutputs.count, 3)  // Should have 3 outputs

        // Verify the output order - job2 should complete before job1 due to the sleep
        XCTAssertEqual(resultOutputs[0], "2")
        XCTAssertEqual(resultOutputs[1], "1")
        XCTAssertEqual(resultOutputs[2], "3")
    }
}
