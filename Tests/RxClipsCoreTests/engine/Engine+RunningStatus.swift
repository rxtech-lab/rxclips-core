import XCTest

@testable import RxClipsCore

class EngineRunningStatusTests: XCTestCase {
    func testStepRunningStatusTrackingDuringExecution() async throws {
        // Create repository with a simple bash step to test status tracking
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "job1",
                    name: "Test Job",
                    steps: [
                        .init(
                            id: "step1",
                            name: "Test Step",
                            script: .bash(.init(command: "echo \"Hello World\""))
                        )
                    ],
                    needs: [],
                    environment: [:],
                    lifecycle: [],
                    form: nil
                )
            ]
        )

        // Initialize engine
        let engine = Engine(repository: repository, baseURL: URL(string: "https://example.com")!)

        // Get the execution stream
        let executeStream = try await engine.execute()

        // Process all results from the stream, capturing each repository state
        var repositories: [Repository] = []

        for try await (updatedRepository, _) in executeStream {
            repositories.append(updatedRepository)
        }

        // We should have at least 2 repositories:
        // - Initial state with running
        // - Final state with success
        XCTAssertGreaterThanOrEqual(repositories.count, 2)

        // Check running status transitions
        if repositories.count >= 2 {
            // Get first job's step in first repository state
            let firstJobStep = repositories.first?.jobs.first?.steps.first
            XCTAssertNotNil(firstJobStep)

            if let step = firstJobStep {
                // At some point, the step should be running
                guard case .running = step.runningStatus.status else {
                    XCTFail("Step should be in running state during execution")
                    return
                }
            }

            // Get first job's step in final repository state
            let finalJobStep = repositories.last?.jobs.first?.steps.first
            XCTAssertNotNil(finalJobStep)

            if let step = finalJobStep {
                // Final state should be success
                guard case .success = step.runningStatus.status else {
                    XCTFail("Step should be in success state after execution")
                    return
                }
            }
        }
    }

    func testTemplateScriptProgressTracking() async throws {
        // Create a temporary template file
        let tempDir = FileManager.default.temporaryDirectory
        let templatePath = tempDir.appendingPathComponent("template.txt")
        let outputPath = tempDir.appendingPathComponent("output.txt")

        try "Hello {{name}}".write(to: templatePath, atomically: true, encoding: .utf8)

        // Create repository with a template step to test percentage progress
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "job1",
                    name: "Template Job",
                    steps: [
                        .init(
                            id: "step1",
                            name: "Template Step",
                            script: .template(
                                .init(files: [
                                    TemplateFile(
                                        file: templatePath.path,
                                        output: outputPath.path
                                    )
                                ]))
                        )
                    ],
                    needs: [],
                    environment: [:],
                    lifecycle: [],
                    form: nil
                )
            ]
        )

        // Initialize engine
        let engine = Engine(repository: repository, baseURL: URL(string: "https://example.com")!)

        // Get the execution stream
        let executeStream = try await engine.execute()

        // Process all results, capturing the repository at each step
        var repositories: [Repository] = []

        for try await (updatedRepository, result) in executeStream {
            repositories.append(updatedRepository)

            // For template results, check that percentage is tracked
            if case .template(let templateResult) = result {
                let step = updatedRepository.jobs.first?.steps.first
                XCTAssertNotNil(step)

                if let step = step, case .running(let percentage) = step.runningStatus.status {
                    // Percentage should match the one in the template result
                    XCTAssertEqual(percentage, templateResult.percentage)
                }
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: templatePath)
        try? FileManager.default.removeItem(at: outputPath)
    }

    func testStepLifecycleRunningStatus() async throws {
        // Create repository with a step that has lifecycle events
        let repository = Repository(
            globalConfig: .init(templatePath: "./"),
            permissions: [],
            lifecycle: [],
            jobs: [
                .init(
                    id: "job1",
                    name: "Test Job",
                    steps: [
                        .init(
                            id: "step1",
                            name: "Step with Lifecycle",
                            script: .bash(.init(command: "echo \"Main Step\"")),
                            lifecycle: [
                                .init(
                                    id: "before",
                                    script: .bash(.init(command: "echo \"Before Step\"")),
                                    on: .beforeStep
                                ),
                                .init(
                                    id: "after",
                                    script: .bash(.init(command: "echo \"After Step\"")),
                                    on: .afterStep
                                ),
                            ]
                        )
                    ],
                    needs: [],
                    environment: [:],
                    lifecycle: [],
                    form: nil
                )
            ]
        )

        // Initialize engine
        let engine = Engine(repository: repository, baseURL: URL(string: "https://example.com")!)

        // Get the execution stream
        let executeStream = try await engine.execute()

        // Process all results, capturing each repository state
        var finalRepository: Repository? = nil

        for try await (updatedRepository, _) in executeStream {
            finalRepository = updatedRepository
        }

        // Verify the final repository
        XCTAssertNotNil(finalRepository)

        if let repo = finalRepository, let step = repo.jobs.first?.steps.first {
            // Check main step status
            guard case .success = step.runningStatus.status else {
                XCTFail("Main step should be in success state")
                return
            }

            // Check lifecycle events status
            XCTAssertEqual(step.lifecycle?.count, 2)

            for lifecycle in step.lifecycle ?? [] {
                guard case .success = lifecycle.runningStatus.status else {
                    XCTFail("Lifecycle event should be in success state")
                    return
                }
            }
        }
    }
}
