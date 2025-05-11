import XCTest

@testable import RxClipsCore

class RepositoryRunningStatusTests: XCTestCase {
    func testJobRunningStatus() throws {
        // Table test cases
        let testCases:
            [(name: String, steps: [Step], lifecycle: [LifecycleEvent], expectedStatus: Status)] = [
                // Case 1: All steps notStarted
                (
                    "all steps notStarted",
                    [makeStep(status: .notStarted)],
                    [],
                    .notStarted
                ),
                // Case 2: One step running
                (
                    "one step running",
                    [
                        makeStep(status: .running(percentage: 50)),
                        makeStep(status: .notStarted),
                    ],
                    [],
                    .running(percentage: 50)
                ),
                // Case 3: Multiple steps running (average percentage)
                (
                    "multiple steps running",
                    [
                        makeStep(status: .running(percentage: 75)),
                        makeStep(status: .running(percentage: 25)),
                    ],
                    [],
                    .running(percentage: 50)
                ),
                // Case 4: One step failed
                (
                    "one step failed",
                    [
                        makeStep(status: .failure(finishedAt: Date())),
                        makeStep(status: .notStarted),
                    ],
                    [],
                    .failure(finishedAt: Date())
                ),
                // Case 5: All steps success
                (
                    "all steps success",
                    [
                        makeStep(status: .success(finishedAt: Date())),
                        makeStep(status: .success(finishedAt: Date())),
                    ],
                    [],
                    .success(finishedAt: Date())
                ),
                // Case 6: All steps skipped
                (
                    "all steps skipped",
                    [
                        makeStep(status: .skipped),
                        makeStep(status: .skipped),
                    ],
                    [],
                    .skipped
                ),
                // Case 7: Mixed notStarted and skipped
                (
                    "mixed notStarted and skipped",
                    [
                        makeStep(status: .notStarted),
                        makeStep(status: .skipped),
                    ],
                    [],
                    .notStarted
                ),
                // Case 8: With lifecycle events
                (
                    "with lifecycle running",
                    [makeStep(status: .notStarted)],
                    [makeLifecycleEvent(status: .running(percentage: 60))],
                    .running(percentage: 60)
                ),
                // Case 9: Mixed success and failure (failure takes precedence)
                (
                    "mixed success and failure",
                    [
                        makeStep(status: .success(finishedAt: Date())),
                        makeStep(status: .failure(finishedAt: Date())),
                    ],
                    [],
                    .failure(finishedAt: Date())
                ),
            ]

        // Run the tests
        for testCase in testCases {
            let job = Job(name: testCase.name, steps: testCase.steps, lifecycle: testCase.lifecycle)

            // For status comparison, we need to match the case but not exact Date values
            let resultStatus = job.runningStatus.status

            switch (resultStatus, testCase.expectedStatus) {
            case (.notStarted, .notStarted), (.skipped, .skipped), (.unknown, .unknown):
                XCTAssertTrue(true, "Test case: \(testCase.name)")

            case (.running(let resultPercentage), .running(let expectedPercentage)):
                if let resultPercentage = resultPercentage,
                    let expectedPercentage = expectedPercentage
                {
                    XCTAssertEqual(
                        resultPercentage, expectedPercentage, accuracy: 0.01,
                        "Test case: \(testCase.name)")
                }

            case (.success, .success), (.failure, .failure):
                XCTAssertTrue(true, "Test case: \(testCase.name)")

            default:
                XCTFail(
                    "Status mismatch for test case: \(testCase.name). Expected \(testCase.expectedStatus), got \(resultStatus)"
                )
            }
        }
    }

    func testRepositoryRunningStatus() throws {
        // Table test cases
        let testCases: [(name: String, jobs: [Job], expectedStatus: Status)] = [
            // Case 1: Empty repository
            (
                "empty repository",
                [],
                .notStarted
            ),
            // Case 2: One job running
            (
                "one job running",
                [
                    makeJob(status: .running(percentage: 40)),
                    makeJob(status: .notStarted),
                ],
                .running(percentage: 40)
            ),
            // Case 3: Multiple jobs running (average percentage)
            (
                "multiple jobs running",
                [
                    makeJob(status: .running(percentage: 80)),
                    makeJob(status: .running(percentage: 20)),
                ],
                .running(percentage: 50)
            ),
            // Case 4: One job failed
            (
                "one job failed",
                [
                    makeJob(status: .failure(finishedAt: Date())),
                    makeJob(status: .notStarted),
                ],
                .failure(finishedAt: Date())
            ),
            // Case 5: All jobs success
            (
                "all jobs success",
                [
                    makeJob(status: .success(finishedAt: Date())),
                    makeJob(status: .success(finishedAt: Date())),
                ],
                .success(finishedAt: Date())
            ),
            // Case 6: All jobs skipped
            (
                "all jobs skipped",
                [
                    makeJob(status: .skipped),
                    makeJob(status: .skipped),
                ],
                .skipped
            ),
            // Case 7: Mixed notStarted and skipped
            (
                "mixed notStarted and skipped",
                [
                    makeJob(status: .notStarted),
                    makeJob(status: .skipped),
                ],
                .notStarted
            ),
            // Case 8: Mixed success and failure (failure takes precedence)
            (
                "mixed success and failure",
                [
                    makeJob(status: .success(finishedAt: Date())),
                    makeJob(status: .failure(finishedAt: Date())),
                ],
                .failure(finishedAt: Date())
            ),
        ]

        // Run the tests
        for testCase in testCases {
            let repository = Repository(jobs: testCase.jobs)

            // For status comparison, we need to match the case but not exact Date values
            let resultStatus = repository.runningStatus.status

            switch (resultStatus, testCase.expectedStatus) {
            case (.notStarted, .notStarted), (.skipped, .skipped), (.unknown, .unknown):
                XCTAssertTrue(true, "Test case: \(testCase.name)")

            case (.running(let resultPercentage), .running(let expectedPercentage)):
                if let resultPercentage = resultPercentage,
                    let expectedPercentage = expectedPercentage
                {
                    XCTAssertEqual(
                        resultPercentage, expectedPercentage, accuracy: 0.01,
                        "Test case: \(testCase.name)")
                }

            case (.success, .success), (.failure, .failure):
                XCTAssertTrue(true, "Test case: \(testCase.name)")

            default:
                XCTFail(
                    "Status mismatch for test case: \(testCase.name). Expected \(testCase.expectedStatus), got \(resultStatus)"
                )
            }
        }
    }

    // MARK: - Helper methods

    private func makeStep(status: Status) -> Step {
        let startedAt = Date().addingTimeInterval(-3600)  // 1 hour ago
        let updatedAt = Date()

        // Create a basic script
        let bashScript = Script.BashScript(command: "echo test")
        let script = Script.bash(bashScript)

        // Create a Step with the script
        var step = Step(script: script)

        // Trigger execution result to update runningStatus
        // This is the most straightforward way to test the computed property
        // behavior that depends on the results state
        let result = ExecuteResult.bash(
            ExecuteResult.BashExecuteResult(scriptId: script.id, output: "test")
        )
        step.results = [result]

        // Add a dummy success result if needed
        switch status {
        case .success(let finishedAt):
            let successResult = ExecuteResult.bash(
                ExecuteResult.BashExecuteResult(scriptId: script.id, output: "success")
            )
            step.results.append(successResult)
            // We need to set the runningStatus directly for tests
            step.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: finishedAt)

        case .failure(let finishedAt):
            let failureResult = ExecuteResult.bash(
                ExecuteResult.BashExecuteResult(scriptId: script.id, output: "failure")
            )
            step.results.append(failureResult)
            // We need to set the runningStatus directly for tests
            step.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: finishedAt)

        case .running(let percentage):
            if let percentage = percentage {
                let progressResult = ExecuteResult.template(
                    ExecuteResult.TemplateExecuteResult(
                        scriptId: script.id, filePath: "test", percentage: percentage)
                )
                step.results.append(progressResult)
            }
            // We need to set the runningStatus directly for tests
            step.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: updatedAt)

        case .skipped, .notStarted, .unknown:
            // We need to set the runningStatus directly for tests
            step.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: updatedAt)
        }

        return step
    }

    private func makeLifecycleEvent(status: Status) -> LifecycleEvent {
        let startedAt = Date().addingTimeInterval(-3600)  // 1 hour ago
        let updatedAt = Date()

        // Create a basic script
        let bashScript = Script.BashScript(command: "echo test")
        let script = Script.bash(bashScript)

        // Create a LifecycleEvent with the script
        var lifecycleEvent = LifecycleEvent(script: script, on: .afterStep)

        // Add a dummy result
        let result = ExecuteResult.bash(
            ExecuteResult.BashExecuteResult(scriptId: script.id, output: "test")
        )
        lifecycleEvent.results = [result]

        // Update status based on test case
        switch status {
        case .success(let finishedAt):
            let successResult = ExecuteResult.bash(
                ExecuteResult.BashExecuteResult(scriptId: script.id, output: "success")
            )
            lifecycleEvent.results.append(successResult)
            // We need to set the runningStatus directly for tests
            lifecycleEvent.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: finishedAt)

        case .failure(let finishedAt):
            let failureResult = ExecuteResult.bash(
                ExecuteResult.BashExecuteResult(scriptId: script.id, output: "failure")
            )
            lifecycleEvent.results.append(failureResult)
            // We need to set the runningStatus directly for tests
            lifecycleEvent.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: finishedAt)

        case .running(let percentage):
            if let percentage = percentage {
                let progressResult = ExecuteResult.template(
                    ExecuteResult.TemplateExecuteResult(
                        scriptId: script.id, filePath: "test", percentage: percentage)
                )
                lifecycleEvent.results.append(progressResult)
            }
            // We need to set the runningStatus directly for tests
            lifecycleEvent.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: updatedAt)

        case .skipped, .notStarted, .unknown:
            // We need to set the runningStatus directly for tests
            lifecycleEvent.runningStatus = RunningStatus(
                status: status, startedAt: startedAt, updatedAt: updatedAt)
        }

        return lifecycleEvent
    }

    private func makeJob(status: Status) -> Job {
        // For simplicity, create a job with a step that has the desired status
        let step = makeStep(status: status)
        return Job(name: "Test Job", steps: [step])
    }
}
