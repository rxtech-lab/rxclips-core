//
//  CommandService.swift
//  trading-analyzer
//
//  Created by Qiwei Li on 3/17/25.
//
import Foundation

enum CommandError: LocalizedError {
    case commandFailed(reason: String)
    case processFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let reason):
            return "Command failed: \(reason)"
        case .processFailed(let reason):
            return "Process failed: \(reason)"
        }
    }
}

enum CommandStatus: Equatable {
    case notRunning
    case running(output: String?)
    case success
    case failure(error: Error)
    case canceled

    var isRunning: Bool {
        switch self {
        case .running:
            return true
        default:
            return false
        }
    }

    static func == (lhs: CommandStatus, rhs: CommandStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notRunning, .notRunning):
            return true
        case (.running(let output1), .running(let output2)):
            return output1 == output2
        case (.success, .success):
            return true
        case (.failure, .failure):
            return true
        case (.canceled, .canceled):
            return true
        default:
            return false
        }
    }
}

public class BashCommandExecutor {
    private(set) var speedupStatus: CommandStatus = .notRunning
    private(set) var runBacktestStatus: CommandStatus = .notRunning

    private var currentProcesses: [UUID: Process] = [:]

    private var speedupTaskId: UUID?
    private var backtestTaskId: UUID?

    /**
     Run a shell command as an async sequence that yields output as it becomes available.

     - Parameters:
        - command: The shell command to execute
        - workingDirectory: The directory to run the command in (optional)
        - environment: Environment variables to set for the command (optional)
        - taskId: A unique identifier for this task (optional)
        - bashPath: The path to the bash executable (optional)
     - Returns: An AsyncThrowingStream that yields command output and throws CommandError on failure
     */
    func runCommand(
        command: String,
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        taskId: UUID = UUID(),
        bashPath: String = "/bin/zsh"
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            // Create a process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: bashPath)
            process.arguments = ["-l", "-c", command]

            // Store the process for potential cancellation
            self.currentProcesses[taskId] = process

            // Track if the process was canceled
            let cancelToken = CancelToken()
            process.terminationHandler = { proc in
                if proc.terminationReason == .uncaughtSignal {
                    cancelToken.canceled = true
                }
            }

            // Set working directory if provided
            if let workingDirectory = workingDirectory {
                process.currentDirectoryPath = workingDirectory.path
                print("Working directory: \(workingDirectory.path)")
            }

            // Set environment variables if provided
            if let environment = environment {
                var processEnvironment = ProcessInfo.processInfo.environment
                for (key, value) in environment {
                    processEnvironment[key] = value
                }
                process.environment = processEnvironment
            } else {
                // Always use the current process environment
                process.environment = ProcessInfo.processInfo.environment
            }

            // Set up pipes to capture output and errors
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe

            let handler = pipe.fileHandleForReading

            // Buffer for accumulated error output
            var errorOutput = ""

            handler.readabilityHandler = { handle in
                let data = handle.availableData
                if data.count > 0 {
                    if let output = String(data: data, encoding: .utf8) {
                        continuation.yield(output)
                        errorOutput += output
                    }
                }
            }

            // Start the process
            do {
                try process.run()

                // Handle process completion in a background queue
                DispatchQueue.global().async {
                    process.waitUntilExit()

                    // Clean up readability handlers
                    handler.readabilityHandler = nil

                    // Remove process from tracking
                    DispatchQueue.main.async {
                        self.currentProcesses.removeValue(forKey: taskId)
                    }

                    // Check if the process was canceled
                    if cancelToken.canceled {
                        continuation.finish()
                        return
                    }

                    // Check the exit status
                    if process.terminationStatus != 0 {
                        if !errorOutput.isEmpty {
                            continuation.finish(
                                throwing: CommandError.commandFailed(
                                    reason:
                                        "Command failed with exit code \(process.terminationStatus): \(errorOutput)"
                                ))
                        } else {
                            continuation.finish(
                                throwing: CommandError.commandFailed(
                                    reason:
                                        "Command failed with exit code \(process.terminationStatus)"
                                ))
                        }
                    } else {
                        continuation.finish()
                    }
                }
            } catch {
                handler.readabilityHandler = nil

                // Remove process from tracking on error
                DispatchQueue.main.async {
                    self.currentProcesses.removeValue(forKey: taskId)
                }

                continuation.finish(
                    throwing: CommandError.processFailed(reason: error.localizedDescription))
            }
        }
    }

    /**
     Cancel a running command

     - Parameter taskId: The ID of the task to cancel
     - Returns: True if a process was found and terminated, false otherwise
     */
    func cancelCommand(taskId: UUID) -> Bool {
        guard let process = currentProcesses[taskId] else {
            return false
        }

        process.terminate()
        currentProcesses.removeValue(forKey: taskId)
        return true
    }

    /**
     Cancel the currently running speedup data generation process
     */
    func cancelSpeedupDataGeneration() {
        if let taskId = speedupTaskId {
            if cancelCommand(taskId: taskId) {
                speedupStatus = .canceled
                speedupTaskId = nil
            }
        }
    }
}

// Helper class to track cancellation
private class CancelToken {
    var canceled = false
}
