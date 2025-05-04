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

extension Job {
    func toExecutionStep() -> [Script] {
        var steps: [Script] = []
        let scriptSteps = self.steps.flatMap { $0.toExecutionStep() }
        if let setup = self.lifecycle.first(where: { $0.on == .beforeJob }) {
            steps.append(setup.script)
        }
        steps.append(contentsOf: scriptSteps)
        if let teardown = self.lifecycle.first(where: { $0.on == .afterJob }) {
            steps.append(teardown.script)
        }
        return steps
    }
}

/// Engine is responsible for executing a repository workflow.
///
/// The engine operates on a directed acyclic graph (DAG) of jobs, where:
/// - The `root` and `tail` nodes handle global setup and teardown scripts respectively
/// - Regular nodes execute their job definitions based on dependency order
/// - Nodes without dependencies run in parallel for maximum efficiency
/// - Nodes with dependencies wait for their upstream dependencies to complete before execution
///
/// This execution model ensures proper workflow orchestration while maximizing parallelism.
public actor Engine {
    internal var rootNode: GraphNode?
    internal var tailNode: GraphNode?
    private let repository: Repository
    private let cwd: URL
    private let baseURL: URL
    private var eventListeners:
        [String: [(id: UUID, continuation: CheckedContinuation<[String: Any], Never>)]] = [:]

    /// Initialize the engine with a repository
    /// @param repository The repository to execute
    /// @param cwd The current working directory
    /// @param engines List of script engines to use for execution
    public init(
        repository: Repository,
        cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        baseURL: URL
    ) {
        self.repository = repository
        self.cwd = cwd
        self.baseURL = baseURL
    }

    /// Parse the repository spec into a list of executable steps
    internal func parseRepository() throws {
        let (rootNode, tailNode) = try GraphNode.buildGraph(jobs: repository.jobs)
        if let globalSetup = repository.lifecycle?.first(where: { $0.on == .setup }) {
            rootNode.job.steps.append(
                .init(
                    id: "setup", name: "Setup", form: nil, ifCondition: nil,
                    script: globalSetup.script, lifecycle: nil)
            )
        }

        if let globalTeardown = repository.lifecycle?.first(where: { $0.on == .teardown }) {
            tailNode.job.steps.append(
                .init(
                    id: "teardown", name: "Teardown", form: nil, ifCondition: nil,
                    script: globalTeardown.script, lifecycle: nil)
            )
        }

        self.rootNode = rootNode
        self.tailNode = tailNode
    }

    /// Execute a script
    /// @param script The script to execute
    /// @param formData The form data to pass to the script
    /// @return AsyncThrowingStream<ExecuteResult, Error>
    internal func executeScript(script: Script, formData: [String: Any]) async throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
    {
        switch script {
        case .bash(let bashScript):
            return try await BashEngine(commandExecutor: BashCommandExecutor()).run(
                script: bashScript, cwd: self.cwd, baseURL: self.baseURL, formData: formData)

        case .template(let templateScript):
            return try await TemplateEngine().run(
                script: templateScript, cwd: self.cwd, baseURL: self.baseURL, formData: formData)

        default:
            throw ExecuteError.unsupportedScriptType(script.type)
        }
    }

    /// Execute the scriptExecutionSteps in order
    /// @return AsyncThrowingStream<ExecuteResult, Error>
    internal func executeGraph(node: GraphNode) throws -> AsyncThrowingStream<ExecuteResult, Error>
    {
        return AsyncThrowingStream { continuation in
            Task {
                var completedNodes = Set<GraphNode>()
                var readyNodes = [GraphNode]()
                var inProgressNodes = Set<GraphNode>()
                var nodeTasks = [GraphNode: Task<Void, Never>]()

                // Helper function to add nodes that are ready to execute
                func addReadyNodes(from node: GraphNode) {
                    if !completedNodes.contains(node) && !readyNodes.contains(node)
                        && !inProgressNodes.contains(node)
                    {
                        let allDependenciesMet = node.parents.allSatisfy {
                            completedNodes.contains($0)
                        }
                        if allDependenciesMet {
                            readyNodes.append(node)
                        }
                    }

                    // Recursively check all descendants
                    for child in node.children {
                        addReadyNodes(from: child)
                    }
                }

                // Start with root node and its descendants
                addReadyNodes(from: node)

                // Process until all nodes are completed
                while !readyNodes.isEmpty || !inProgressNodes.isEmpty {
                    // Launch tasks for all ready nodes
                    while !readyNodes.isEmpty {
                        let nodeToExecute = readyNodes.removeFirst()
                        inProgressNodes.insert(nodeToExecute)

                        // Create a task to execute this node
                        let task = Task {
                            do {
                                // Execute each step in the job
                                let steps = nodeToExecute.job.toExecutionStep()
                                var formData: [String: Any] = [:]

                                for step in steps {
                                    let stream = try await self.executeScript(
                                        script: step, formData: formData)

                                    for try await result in stream {
                                        continuation.yield(result)
                                    }
                                    continuation.yield(.nextStep(.init(scriptId: step.id)))
                                }

                                // Mark this node as completed
                                completedNodes.insert(nodeToExecute)
                                inProgressNodes.remove(nodeToExecute)

                                // Check if any children are now ready to execute
                                for child in nodeToExecute.children {
                                    let dependenciesMet = child.parents.allSatisfy {
                                        completedNodes.contains($0)
                                    }
                                    if dependenciesMet && !completedNodes.contains(child)
                                        && !inProgressNodes.contains(child)
                                        && !readyNodes.contains(child)
                                    {
                                        readyNodes.append(child)
                                    }
                                }
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        }

                        nodeTasks[nodeToExecute] = task
                    }

                    // If no nodes are ready but some are still in progress, wait a bit
                    if readyNodes.isEmpty && !inProgressNodes.isEmpty {
                        try? await Task.sleep(nanoseconds: 10_000_000)  // Wait 10ms
                    }
                }

                continuation.finish()
            }
        }
    }

    /// Execute the repository by running all the steps and lifecycle events
    /// Returns a stream of Repository objects with updated execution results
    public func execute() throws -> AsyncThrowingStream<Repository, Error> {
        // Parse the repository to prepare execution steps
        try self.parseRepository()

        return AsyncThrowingStream { continuation in

        }
    }
}

// MARK: - Signal
extension Engine {
    /// Emits an event to all registered listeners for the specified event name
    /// - Parameters:
    ///   - eventName: The name of the event to emit
    ///   - data: Optional dictionary of data to pass to the listeners
    /// - Note: If there are listeners registered for this event, the first listener will be triggered and then removed
    func emit(_ eventName: String, data: [String: Any] = [:]) {
        guard let listeners = eventListeners[eventName], !listeners.isEmpty else {
            return
        }

        // Get the first listener for 'once' behavior
        let listener = listeners[0]

        // Remove this listener since 'once' only triggers once
        eventListeners[eventName]?.removeAll { $0.id == listener.id }

        // Resume the continuation with the data
        listener.continuation.resume(returning: data)
    }

    /// Waits for an event to occur once and returns the associated data
    /// - Parameter eventName: The name of the event to listen for
    /// - Returns: Dictionary containing data passed when the event is emitted
    /// - Note: This function registers a one-time listener that will be automatically removed after the event occurs
    func once(_ eventName: String) async -> [String: Any] {
        return await withCheckedContinuation { continuation in
            let listenerId = UUID()

            if eventListeners[eventName] == nil {
                eventListeners[eventName] = []
            }

            eventListeners[eventName]?.append((id: listenerId, continuation: continuation))
        }
    }
}
