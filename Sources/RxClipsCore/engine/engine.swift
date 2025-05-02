import Foundation

extension Step {
    func toExecutionStep() -> [Script] {
        var executionSteps: [Script] = []
        // find the lifecycle event for the step
        if let lifecycleEvent = self.lifecycle {
            let sortedLifecycleEvents = lifecycleEvent.filter { $0.on == .beforeStep }.sorted()
            executionSteps.append(contentsOf: sortedLifecycleEvents.map { $0.script })
        }

        executionSteps.append(self.script)

        if let lifecycleEvent = self.lifecycle {
            let sortedLifecycleEvents = lifecycleEvent.filter { $0.on == .afterStep }.sorted()
            executionSteps.append(contentsOf: sortedLifecycleEvents.map { $0.script })
        }
        return executionSteps
    }
}

public actor Engine {
    internal var scriptExecutionSteps: [Script] = []
    private let repository: Repository
    private let cwd: URL

    /// Initialize the engine with a repository
    /// @param repository The repository to execute
    /// @param cwd The current working directory
    /// @param engines List of script engines to use for execution
    public init(
        repository: Repository,
        cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) {
        self.repository = repository
        self.cwd = cwd
    }

    /// Parse the repository spec into a list of executable steps
    internal func parseRepository() {
        self.scriptExecutionSteps = []
        // sort global setup lifecycle events
        if let lifeCycles = repository.lifecycle {
            let sortedSteps = lifeCycles.filter { $0.on == .setup }.sorted()
            self.scriptExecutionSteps.append(contentsOf: sortedSteps.map { $0.script })
        }

        // sort step setUpStep
        if let steps = repository.steps {
            for step in steps {
                self.scriptExecutionSteps.append(contentsOf: step.toExecutionStep())
            }
        }

        // sort global teardown lifecycle events
        if let lifeCycles = repository.lifecycle {
            let sortedSteps = lifeCycles.filter { $0.on == .teardown }.sorted()
            self.scriptExecutionSteps.append(contentsOf: sortedSteps.map { $0.script })
        }
    }

    internal func executeScript(script: Script, formData: [String: Any]) async throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
    {
        switch script {
        case .bash(let bashScript):
            return try await BashEngine(commandExecutor: BashCommandExecutor()).run(
                script: bashScript, cwd: self.cwd, formData: formData)

        case .template(let templateScript):
            return try await TemplateEngine().run(
                script: templateScript, cwd: self.cwd, formData: formData)

        default:
            throw ExecuteError.unsupportedScriptType(script.type)
        }
    }

    /// Execute the scriptExecutionSteps in order
    /// @return AsyncThrowingStream<ExecuteResult, Error>
    /// @note This function is internal and is used to execute the scriptExecutionSteps in order
    internal func executeSteps() throws -> AsyncThrowingStream<ExecuteResult, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for script in self.scriptExecutionSteps {
                        for try await result in try await self.executeScript(
                            script: script, formData: [:])
                        {
                            continuation.yield(result)
                        }
                        continuation.yield(.nextStep(.init(scriptId: script.id)))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Execute the repository by running all the steps and lifecycle events
    /// Returns a stream of Repository objects with updated execution results
    public func execute() throws -> AsyncThrowingStream<Repository, Error> {
        // Parse the repository to prepare execution steps
        self.parseRepository()

        return AsyncThrowingStream { continuation in
            Task {
                // Create a mutable copy of the repository to update with results
                var updatedRepository = self.repository

                do {
                    // Execute all steps and collect results
                    for try await result in try self.executeSteps() {
                        // Find the corresponding step or lifecycle event and append the result
                        switch result {
                        case .bash(let bashResult):
                            // Update steps with results
                            if let steps = updatedRepository.steps {
                                for i in 0..<steps.count {
                                    if steps[i].script.id == bashResult.scriptId {
                                        updatedRepository.steps?[i].results.append(result)
                                    }

                                    // Check step lifecycle events
                                    if let lifecycle = steps[i].lifecycle {
                                        for j in 0..<lifecycle.count {
                                            if lifecycle[j].script.id == bashResult.scriptId {
                                                updatedRepository.steps?[i].lifecycle?[j].results
                                                    .append(result)
                                            }
                                        }
                                    }
                                }
                            }

                            // Update global lifecycle events with results
                            if let lifecycle = updatedRepository.lifecycle {
                                for i in 0..<lifecycle.count {
                                    if lifecycle[i].script.id == bashResult.scriptId {
                                        updatedRepository.lifecycle?[i].results.append(result)
                                    }
                                }
                            }

                        case .template(let templateResult):
                            // Update steps with results
                            if let steps = updatedRepository.steps {
                                for i in 0..<steps.count {
                                    if let templateScript = steps[i].script.templateScript,
                                        templateScript.files?.contains(where: {
                                            $0.output == templateResult.filePath
                                        }) ?? false
                                    {
                                        updatedRepository.steps?[i].results.append(result)
                                    }

                                    // Check step lifecycle events
                                    if let lifecycle = steps[i].lifecycle {
                                        for j in 0..<lifecycle.count {
                                            if let templateScript = lifecycle[j].script
                                                .templateScript,
                                                templateScript.files?.contains(where: {
                                                    $0.output == templateResult.filePath
                                                }) ?? false
                                            {
                                                updatedRepository.steps?[i].lifecycle?[j].results
                                                    .append(result)
                                            }
                                        }
                                    }
                                }
                            }

                            // Update global lifecycle events with results
                            if let lifecycle = updatedRepository.lifecycle {
                                for i in 0..<lifecycle.count {
                                    if let templateScript = lifecycle[i].script.templateScript,
                                        templateScript.files?.contains(where: {
                                            $0.output == templateResult.filePath
                                        }) ?? false
                                    {
                                        updatedRepository.lifecycle?[i].results.append(result)
                                    }
                                }
                            }

                        case .nextStep(let nextStepResult):
                            // Add nextStep result to the corresponding script
                            // Update steps with results
                            if let steps = updatedRepository.steps {
                                for i in 0..<steps.count {
                                    if steps[i].script.id == nextStepResult.scriptId {
                                        updatedRepository.steps?[i].results.append(result)
                                    }

                                    // Check step lifecycle events
                                    if let lifecycle = steps[i].lifecycle {
                                        for j in 0..<lifecycle.count {
                                            if lifecycle[j].script.id == nextStepResult.scriptId {
                                                updatedRepository.steps?[i].lifecycle?[j].results
                                                    .append(result)
                                            }
                                        }
                                    }
                                }
                            }

                            // Update global lifecycle events with results
                            if let lifecycle = updatedRepository.lifecycle {
                                for i in 0..<lifecycle.count {
                                    if lifecycle[i].script.id == nextStepResult.scriptId {
                                        updatedRepository.lifecycle?[i].results.append(result)
                                    }
                                }
                            }

                            // Yield the current state
                            continuation.yield(updatedRepository)
                        }
                    }

                    // Yield final state
                    continuation.yield(updatedRepository)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

}
