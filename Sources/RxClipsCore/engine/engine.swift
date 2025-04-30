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

    public init(repository: Repository) {
        self.repository = repository
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
}
