import Foundation
import JSONSchema

extension Step {
    func toExecutionStep() -> [Script] {
        var executionSteps: [Script] = []
        // find the lifecycle event for the step
        if let lifecycleEvent = self.lifecycle {
            let sortedLifecycleEvents = lifecycleEvent.filter { $0.on == .beforeStep }.sorted()
            executionSteps.append(
                contentsOf: sortedLifecycleEvents.map { $0.script.updateId(id: $0.id) })
        }

        executionSteps.append(self.script)

        if let lifecycleEvent = self.lifecycle {
            let sortedLifecycleEvents = lifecycleEvent.filter { $0.on == .afterStep }.sorted()
            executionSteps.append(
                contentsOf: sortedLifecycleEvents.map { $0.script.updateId(id: $0.id) })
        }
        return executionSteps
    }
}

extension Job {
    func toExecutionStep() -> [Script] {
        var steps: [Script] = []
        let scriptSteps = self.steps.flatMap { $0.toExecutionStep() }
        if let setup = self.lifecycle.first(where: { $0.on == .beforeJob }) {
            // set script id to the lifecycle id
            steps.append(setup.script.updateId(id: setup.id))
        }
        steps.append(contentsOf: scriptSteps)
        if let teardown = self.lifecycle.first(where: { $0.on == .afterJob }) {
            steps.append(teardown.script.updateId(id: teardown.id))
        }
        return steps
    }
}

extension GraphNode {

    // Convert a graph into the repository object
    // Root node and tail node's job will be converted to the global lifecycle method inside the repository object.
    // Root node's children will be converted to the jobs inside the repository object.
    func toRepository(oldRepository: Repository) throws(ExecuteError) -> Repository {
        // check if the node is root
        guard self.isRoot else {
            throw ExecuteError.notRootNode
        }

        // Create a new repository using the old one as a template
        var repository = oldRepository

        // Extract all nodes except root and tail
        var jobNodes: [GraphNode] = []
        var lifecycleEvents: [LifecycleEvent] = []

        // Traverse the graph to collect all nodes
        _ = self.traverse { node in
            if !node.isRoot && !node.isTail {
                jobNodes.append(node)
            } else {
                // Extract lifecycle events from root and tail nodes
                if node.isRoot {
                    for step in node.job.steps {
                        let lifecycleEvent = LifecycleEvent(
                            script: step.script,
                            on: .setup,
                            results: step.results
                        )
                        lifecycleEvents.append(lifecycleEvent)
                    }

                } else if node.isTail {
                    for step in node.job.steps {
                        let lifecycleEvent = LifecycleEvent(
                            script: step.script,
                            on: .teardown,
                            results: step.results
                        )
                        lifecycleEvents.append(lifecycleEvent)
                    }
                }
            }
        }

        // Update repository with new jobs and lifecycle events
        repository.jobs = jobNodes.map { $0.job }
        repository.lifecycle = lifecycleEvents

        return repository
    }

    /// Looks up data within the graph structure using a human-readable path
    /// - Parameter path: A string path in format "jobs[index].steps[index].property" or "jobs.id.steps.id.property"
    /// - Returns: The value at the specified path
    /// - Throws: An error if the path is invalid or the requested data doesn't exist
    func lookup(path: String) throws -> Any {
        // Split the path into components
        let components = path.split(separator: ".")

        // Start with this node as the current context
        var currentContext: Any = self

        for component in components {
            // Check if we're accessing an array with index: jobs[0]
            if let rangeStart = component.firstIndex(of: "["),
                let rangeEnd = component.firstIndex(of: "]"),
                rangeStart < rangeEnd
            {

                let name = component[..<rangeStart]
                let indexString = component[component.index(after: rangeStart)..<rangeEnd]

                guard let index = Int(indexString) else {
                    throw ExecuteError.invalidPath("Invalid index in path: \(path)")
                }

                // Handle different array lookups
                if name == "jobs" {
                    if let graphNode = currentContext as? GraphNode {
                        // For root node, we need to get its children (excluding root/tail)
                        var jobNodes: [GraphNode] = []

                        _ = graphNode.traverse { node in
                            if !node.isRoot && !node.isTail {
                                jobNodes.append(node)
                            }
                        }

                        guard index < jobNodes.count else {
                            throw ExecuteError.invalidPath("Job index out of bounds: \(index)")
                        }

                        currentContext = jobNodes[index]
                    } else {
                        throw ExecuteError.invalidPath("Cannot access jobs from this context")
                    }
                } else if name == "steps" {
                    if let node = currentContext as? GraphNode {
                        guard index < node.job.steps.count else {
                            throw ExecuteError.invalidPath("Step index out of bounds: \(index)")
                        }
                        currentContext = node.job.steps[index]
                    } else {
                        throw ExecuteError.invalidPath("Cannot access steps from this context")
                    }
                } else {
                    throw ExecuteError.invalidPath("Unknown array accessor: \(name)")
                }
            }
            // Handle ID-based lookups like jobs.job1.steps.step1
            else if component == "jobs" {
                if let graphNode = currentContext as? GraphNode {
                    // Next component should be the job ID
                    guard components.count > 1 else {
                        throw ExecuteError.invalidPath("Job ID missing in path")
                    }

                    // Store all jobs for ID-based lookup
                    var jobNodes: [GraphNode] = []

                    _ = graphNode.traverse { node in
                        if !node.isRoot && !node.isTail {
                            jobNodes.append(node)
                        }
                    }

                    currentContext = jobNodes
                }
            } else if component == "steps" {
                if let node = currentContext as? GraphNode {
                    // Next component should be the step ID
                    guard components.count > 1 else {
                        throw ExecuteError.invalidPath("Step ID missing in path")
                    }

                    currentContext = node.job.steps
                }
            }
            // Handle property access
            else if component == "formData" {
                if let step = currentContext as? Step {
                    return [:]  // Return empty dictionary - formData represents user input, not the schema
                } else if let node = currentContext as? GraphNode {
                    return [:]  // Return empty dictionary - formData represents user input, not the schema
                } else {
                    throw ExecuteError.invalidPath("Cannot access formData from this context")
                }
            } else if component == "results" {
                if let step = currentContext as? Step {
                    return step.results ?? []
                } else if let node = currentContext as? GraphNode {
                    // Collect results from all steps in the job
                    return node.job.steps.flatMap { $0.results ?? [] }
                } else {
                    throw ExecuteError.invalidPath("Cannot access results from this context")
                }
            } else if component.description.isEmpty == false {
                let idString = component.description
                // Handle ID-based lookup from an array of objects
                if let jobNodes = currentContext as? [GraphNode] {
                    // Find the job with matching ID
                    if let matchingJob = jobNodes.first(where: { $0.job.id == idString }) {
                        currentContext = matchingJob
                    } else {
                        throw ExecuteError.invalidPath("Job with ID '\(idString)' not found")
                    }
                } else if let steps = currentContext as? [Step] {
                    // Find the step with matching ID
                    if let matchingStep = steps.first(where: { $0.id == idString }) {
                        currentContext = matchingStep
                    } else {
                        throw ExecuteError.invalidPath("Step with ID '\(idString)' not found")
                    }
                } else {
                    // For cases where we're not in an array context, treat as unknown path component
                    throw ExecuteError.invalidPath("Unknown path component: \(component)")
                }
            } else {
                throw ExecuteError.invalidPath("Unknown path component: \(component)")
            }
        }

        return currentContext
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
    internal let repository: Repository
    internal let cwd: URL
    internal let baseURL: URL
    internal var eventListeners:
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
                                //TODO: Emit ask for form data event and wait for response
                                var formData: [String: Any] = [:]

                                for step in steps {
                                    // Initialize running status for the step that's about to execute
                                    let now = Date()

                                    // Update the running status in the appropriate step or lifecycle event
                                    await initializeRunningStatus(
                                        scriptId: step.id, in: &nodeToExecute.job,
                                        startedAt: now)

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
    public func execute() throws -> AsyncThrowingStream<(Repository, ExecuteResult), Error> {
        // Parse the repository to prepare execution steps
        try self.parseRepository()
        guard var rootNode = self.rootNode else {
            throw ExecuteError.parsingFailed
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await result in try self.executeGraph(node: rootNode) {
                        rootNode = rootNode.traverse { GraphNode in
                            addExecutionResult(
                                id: result.scriptId, for: &GraphNode, with: result)
                        }
                        let newRepository = try rootNode.toRepository(
                            oldRepository: self.repository)
                        continuation.yield((newRepository, result))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
