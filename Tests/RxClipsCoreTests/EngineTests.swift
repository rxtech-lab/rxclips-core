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
        let executeStream = try await engine.executeSteps()

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

    @MainActor
    func testExecuteMethodUpdatesRepositoryWithResults() async throws {
        // Create repository with simple echo commands and specific IDs
        let globalSetupId = "global-setup"
        let globalTeardownId = "global-teardown"
        let mainStepId = "main-step"
        let beforeStepId = "before-step"
        let afterStepId = "after-step"

        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [
                .init(
                    script: .bash(.init(id: globalSetupId, command: "echo \"global setup\"")),
                    on: .setup),
                .init(
                    script: .bash(.init(id: globalTeardownId, command: "echo \"global teardown\"")),
                    on: .teardown),
            ],
            steps: [
                .init(
                    name: "Test Step",
                    script: .bash(.init(id: mainStepId, command: "echo \"main step\"")),
                    lifecycle: [
                        .init(
                            script: .bash(.init(id: beforeStepId, command: "echo \"before step\"")),
                            on: .beforeStep),
                        .init(
                            script: .bash(.init(id: afterStepId, command: "echo \"after step\"")),
                            on: .afterStep),
                    ]
                )
            ]
        )

        // Initialize engine and execute
        let engine = Engine(repository: repository)
        let executeStream = try await engine.execute()

        // Get the final repository state
        var finalRepository: Repository? = nil
        for try await updatedRepository in executeStream {
            finalRepository = updatedRepository
        }

        // Verify repository was emitted
        XCTAssertNotNil(finalRepository, "No repository was emitted")
        guard let finalRepo = finalRepository else { return }

        // Check global lifecycle events received results
        var allScriptIds = Set<String>()
        if let lifecycle = finalRepo.lifecycle {
            for event in lifecycle {
                for result in event.results {
                    switch result {
                    case .bash(let bashResult):
                        allScriptIds.insert(bashResult.scriptId)
                    case .nextStep(let nextStep):
                        allScriptIds.insert(nextStep.scriptId)
                    default:
                        continue
                    }
                }
            }
        }

        // Check step scripts received results
        if let steps = finalRepo.steps {
            for step in steps {
                for result in step.results {
                    switch result {
                    case .bash(let bashResult):
                        allScriptIds.insert(bashResult.scriptId)
                    case .nextStep(let nextStep):
                        allScriptIds.insert(nextStep.scriptId)
                    default:
                        continue
                    }
                }

                // Check step lifecycle events
                if let lifecycle = step.lifecycle {
                    for event in lifecycle {
                        for result in event.results {
                            switch result {
                            case .bash(let bashResult):
                                allScriptIds.insert(bashResult.scriptId)
                            case .nextStep(let nextStep):
                                allScriptIds.insert(nextStep.scriptId)
                            default:
                                continue
                            }
                        }
                    }
                }
            }
        }

        // Verify all script IDs were found in results
        XCTAssertTrue(allScriptIds.contains(globalSetupId), "Global setup script results missing")
        XCTAssertTrue(
            allScriptIds.contains(globalTeardownId), "Global teardown script results missing")
        XCTAssertTrue(allScriptIds.contains(mainStepId), "Main step script results missing")
        XCTAssertTrue(allScriptIds.contains(beforeStepId), "Before step script results missing")
        XCTAssertTrue(allScriptIds.contains(afterStepId), "After step script results missing")
    }
}

/// Tests for the current working directory functionality in Engine
class EngineCwdTests: XCTestCase {
    @MainActor
    func testEngineUsesProvidedCwd() async throws {
        // Use system's /bin directory
        let systemDir = URL(fileURLWithPath: "/bin")

        // Create a repository with a script that checks the current directory
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: nil,
            steps: [
                .init(
                    name: "Check CWD",
                    script: .bash(.init(command: "pwd")),
                    lifecycle: nil
                )
            ]
        )

        // Initialize engine with the system directory
        let engine = Engine(repository: repository, cwd: systemDir)
        await engine.parseRepository()

        // Execute and collect results
        let executeStream = try await engine.executeSteps()

        // Collect all bash output results
        var outputPaths: [String] = []
        for try await result in executeStream {
            if case .bash(let bashResult) = result {
                outputPaths.append(
                    bashResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // We should have exactly one output path
        XCTAssertEqual(outputPaths.count, 1, "Expected exactly one bash command output")

        // The output path should match our system directory
        let normalizedOutputPath =
            outputPaths.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        XCTAssertEqual(
            normalizedOutputPath,
            "/bin",
            "Expected output path to be /bin, got \(normalizedOutputPath)"
        )
    }
}
