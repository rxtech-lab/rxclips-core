import XCTest

@testable import RxClipsCore

class EngineParseRepositoryTests: XCTestCase {
    @MainActor
    func testParseRepository() async {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"), permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo 'before global step'")), on: .setup),
                .init(script: .bash(.init(command: "echo 'after global step'")), on: .teardown),
            ],
            steps: [
                .init(
                    name: "Test Step",
                    script: .bash(.init(command: "ls")),
                    lifecycle: [
                        .init(script: .bash(.init(command: "echo 'after step'")), on: .afterStep),
                        .init(script: .bash(.init(command: "echo 'before step'")), on: .beforeStep),
                    ]
                )
            ])
        let engine = Engine(repository: repository)
        await engine.parseRepository()
        let scriptExecutionSteps = await engine.scriptExecutionSteps
        XCTAssertEqual(scriptExecutionSteps.count, 5)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'before global step'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'before step'")
        XCTAssertEqual(scriptExecutionSteps[2].bashScript?.command, "ls")
        XCTAssertEqual(scriptExecutionSteps[3].bashScript?.command, "echo 'after step'")
        XCTAssertEqual(scriptExecutionSteps[4].bashScript?.command, "echo 'after global step'")
    }

    @MainActor
    func testParseRepositoryWithOnlyGlobalLifecycle() async {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo 'setup'")), on: .setup),
                .init(script: .bash(.init(command: "echo 'teardown'")), on: .teardown),
            ],
            steps: []
        )

        let engine = Engine(repository: repository)
        await engine.parseRepository()
        let scriptExecutionSteps = await engine.scriptExecutionSteps

        XCTAssertEqual(scriptExecutionSteps.count, 2)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'setup'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'teardown'")
    }

    @MainActor
    func testParseRepositoryWithOnlySteps() async {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: nil,
            steps: [
                .init(
                    name: "Step 1",
                    script: .bash(.init(command: "echo 'step 1'"))
                ),
                .init(
                    name: "Step 2",
                    script: .bash(.init(command: "echo 'step 2'"))
                ),
            ]
        )

        let engine = Engine(repository: repository)
        await engine.parseRepository()
        let scriptExecutionSteps = await engine.scriptExecutionSteps

        XCTAssertEqual(scriptExecutionSteps.count, 2)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'step 1'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'step 2'")
    }

    @MainActor
    func testParseRepositoryWithStepLifecycle() async {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: nil,
            steps: [
                .init(
                    name: "Step With Lifecycle",
                    script: .bash(.init(command: "echo 'main step'")),
                    lifecycle: [
                        .init(script: .bash(.init(command: "echo 'before step'")), on: .beforeStep),
                        .init(script: .bash(.init(command: "echo 'after step'")), on: .afterStep),
                    ]
                )
            ]
        )

        let engine = Engine(repository: repository)
        await engine.parseRepository()
        let scriptExecutionSteps = await engine.scriptExecutionSteps

        XCTAssertEqual(scriptExecutionSteps.count, 3)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'before step'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'main step'")
        XCTAssertEqual(scriptExecutionSteps[2].bashScript?.command, "echo 'after step'")
    }

    @MainActor
    func testParseRepositoryWithEmptyRepository() async {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: nil,
            steps: nil
        )

        let engine = Engine(repository: repository)
        await engine.parseRepository()
        let scriptExecutionSteps = await engine.scriptExecutionSteps

        XCTAssertEqual(scriptExecutionSteps.count, 0)
    }

    @MainActor
    func testParseRepositoryWithMultipleStepsAndMixedLifecycles() async {
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo 'global setup'")), on: .setup)
            ],
            steps: [
                .init(
                    name: "Step 1",
                    script: .bash(.init(command: "echo 'step 1'")),
                    lifecycle: [
                        .init(
                            script: .bash(.init(command: "echo 'before step 1'")), on: .beforeStep)
                    ]
                ),
                .init(
                    name: "Step 2",
                    script: .bash(.init(command: "echo 'step 2'")),
                    lifecycle: nil
                ),
                .init(
                    name: "Step 3",
                    script: .bash(.init(command: "echo 'step 3'")),
                    lifecycle: [
                        .init(script: .bash(.init(command: "echo 'after step 3'")), on: .afterStep)
                    ]
                ),
            ]
        )

        let engine = Engine(repository: repository)
        await engine.parseRepository()
        let scriptExecutionSteps = await engine.scriptExecutionSteps

        XCTAssertEqual(scriptExecutionSteps.count, 6)
        XCTAssertEqual(scriptExecutionSteps[0].bashScript?.command, "echo 'global setup'")
        XCTAssertEqual(scriptExecutionSteps[1].bashScript?.command, "echo 'before step 1'")
        XCTAssertEqual(scriptExecutionSteps[2].bashScript?.command, "echo 'step 1'")
        XCTAssertEqual(scriptExecutionSteps[3].bashScript?.command, "echo 'step 2'")
        XCTAssertEqual(scriptExecutionSteps[4].bashScript?.command, "echo 'step 3'")
        XCTAssertEqual(scriptExecutionSteps[5].bashScript?.command, "echo 'after step 3'")
    }
}

class EngineExecuteTests: XCTestCase {
    @MainActor
    func testExecuteEngineWithLifecycleAndSteps() async throws {
        // Create repository with numbered echo commands for easy testing
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(script: .bash(.init(command: "echo \"1\"")), on: .setup),
                .init(script: .bash(.init(command: "echo \"5\"")), on: .teardown),
            ],
            steps: [
                .init(
                    name: "Main Step",
                    script: .bash(.init(command: "echo \"3\"")),
                    lifecycle: [
                        .init(script: .bash(.init(command: "echo \"2\"")), on: .beforeStep),
                        .init(script: .bash(.init(command: "echo \"4\"")), on: .afterStep),
                    ]
                )
            ]
        )

        // Initialize and parse repository
        let engine = Engine(repository: repository)
        await engine.parseRepository()

        // Execute and collect results
        let executeStream = try await engine.execute()

        var resultOutputs: [String] = []
        var nextStepCount = 0

        for try await result in executeStream {
            switch result {
            case .bash(let bashResult):
                resultOutputs.append(
                    bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            case .nextStep:
                nextStepCount += 1
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
}
