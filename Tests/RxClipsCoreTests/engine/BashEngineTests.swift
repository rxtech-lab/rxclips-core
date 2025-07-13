import XCTest

@testable import RxClipsCore

class BashCommandExecutorTests: XCTestCase {

    func testRunCommand() async throws {
        let executor = BashCommandExecutor()
        let outputStream = executor.runCommand(command: "echo 'test output'")

        var output = ""
        for try await line in outputStream {
            output += line
        }
        XCTAssertTrue(output.contains("test output"))
    }

    func testRunCommandWithFailure() async {
        let executor = BashCommandExecutor()
        let outputStream = executor.runCommand(command: "nonexistentcommand")

        do {
            for try await _ in outputStream {}
            XCTFail("Command should have failed but didn't")
        } catch {
            XCTAssertTrue(error is CommandError)
            if case CommandError.commandFailed(let reason) = error {
                XCTAssertTrue(reason.contains("Command failed with exit code"))
            } else {
                XCTFail("Expected CommandError.commandFailed but got \(error)")
            }
        }
    }

    func testCancelCommand() async {
        let executor = BashCommandExecutor()
        let taskId = UUID()

        let outputStream = executor.runCommand(
            command: "sleep 5 && echo 'This should not complete'",
            taskId: taskId
        )

        // Start the task in background
        Task {
            do {
                for try await _ in outputStream {}
            } catch {
                // Expect a cancellation error
            }
        }

        // Wait a bit to ensure the process starts
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Cancel the command
        let result = executor.cancelCommand(taskId: taskId)
        XCTAssertTrue(result, "Command cancellation should return true")
    }
}

class BashEngineTests: XCTestCase {

    func testBashEngineRun() async throws {
        let commandExecutor = BashCommandExecutor()
        let bashEngine = BashEngine(commandExecutor: commandExecutor)

        let bashScript = Script.BashScript(
            id: UUID().uuidString, command: "echo 'test bash engine'")

        let outputSequence = try await bashEngine.run(
            script: bashScript, cwd: URL(fileURLWithPath: "/tmp"),
            repositorySource: nil, repositoryPath: nil, formData: [:])

        var outputs: [ExecuteResult] = []
        for try await result in outputSequence {
            outputs.append(result)
        }

        XCTAssertFalse(outputs.isEmpty, "Should have received output")

        for output in outputs {
            if case .bash(let bashResult) = output {
                XCTAssertEqual(bashResult.scriptId, bashScript.id)
                XCTAssertTrue(
                    bashResult.output.contains("test bash engine"),
                    "Output should contain the echo content")
            } else {
                XCTFail("Expected bash result but got something else")
            }
        }
    }

    func testBashEngineFailure() async {
        let commandExecutor = BashCommandExecutor()
        let bashEngine = BashEngine(commandExecutor: commandExecutor)

        let bashScript = Script.BashScript(id: UUID().uuidString, command: "nonexistentcommand")

        do {
            let outputSequence = try await bashEngine.run(
                script: bashScript, cwd: URL(fileURLWithPath: "/tmp"),
                repositorySource: nil, repositoryPath: nil, formData: [:])
            for try await _ in outputSequence {}
            XCTFail("Command should have failed but didn't")
        } catch {
            XCTAssertTrue(error is CommandError, "Error should be a CommandError")
        }
    }
}
