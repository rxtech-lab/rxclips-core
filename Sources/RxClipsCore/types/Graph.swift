public class GraphNode: Identifiable {
    public var id: String
    public var job: Job

    private var needJobs: [Job]
    internal var parents: [GraphNode]
    internal var children: [GraphNode]

    static var rootId: String {
        return "root"
    }

    static var tailId: String {
        return "tail"
    }

    public var isRoot: Bool {
        return self.id == GraphNode.rootId
    }

    public var isTail: Bool {
        return self.id == GraphNode.tailId
    }

    public var isEmpty: Bool {
        return self.children.isEmpty
    }

    public var needs: [Job] {
        return self.parents.map { $0.job }
    }

    public var executionScripts: [Script] {
        return self.job.toExecutionStep()
    }

    public init(id: String, job: Job, needs: [Job]) {
        self.id = id
        self.job = job
        self.needJobs = needs
        self.parents = []
        self.children = []
    }

    func addChild(_ child: GraphNode) {
        self.children.append(child)
        child.parents.append(self)
    }

    /// Build a graph of job dependencies
    /// - Parameter jobs: Array of jobs to build the graph from
    /// - Returns: A tuple containing the root and tail nodes
    /// - Throws: An error if any job has a dependency that doesn't exist or if there's a cycle
    public static func buildGraph(root: GraphNode? = nil, tail: GraphNode? = nil, jobs: [Job])
        throws(GraphError) -> (root: GraphNode, tail: GraphNode)
    {
        let rootNode: GraphNode
        if let root = root {
            rootNode = root
        } else {
            rootNode = try GraphNode.buildRootNode()
        }

        let tailNode: GraphNode
        if let tail = tail {
            tailNode = tail
        } else {
            tailNode = try GraphNode.buildTailNode()
        }

        var nodeMap: [String: GraphNode] = [:]

        // First, create nodes for all jobs with empty needs
        for job in jobs {
            let node = GraphNode(id: job.id, job: job, needs: [])
            nodeMap[job.id] = node
        }

        // Check for missing dependencies and collect needed jobs
        for job in jobs {
            for needId in job.needs {
                guard nodeMap[needId] != nil else {
                    throw GraphError.missingNode(jobId: job.id, dependencyId: needId)
                }
            }
        }

        // Connect nodes based on dependencies
        for job in jobs {
            let currentNode = nodeMap[job.id]!

            // If job has no dependencies, connect to root
            if job.needs.isEmpty {
                rootNode.addChild(currentNode)
            } else {
                // Connect to all its dependencies
                for needId in job.needs {
                    let needNode = nodeMap[needId]!
                    needNode.addChild(currentNode)
                }
            }
        }

        // find all nodes without children and connect them to tail
        for (_, node) in nodeMap {
            if node.children.isEmpty {
                node.addChild(tailNode)
            }
        }

        // Check for cycles - using DFS
        if let cycle = detectCycle(nodeMap: nodeMap) {
            throw GraphError.cyclicDependency(cycle)
        }

        // check if root is empty
        if rootNode.children.isEmpty {
            // connect root to tail
            rootNode.addChild(tailNode)
        }
        return (root: rootNode, tail: tailNode)
    }

    /// Detects cycles in the graph using DFS
    /// - Parameter nodeMap: Map of nodes by ID
    /// - Returns: A cycle path if found, nil otherwise
    private static func detectCycle(nodeMap: [String: GraphNode]) -> [String]? {
        var visited = Set<String>()
        var recursionStack = Set<String>()
        var path = [String]()

        // Helper function for DFS
        func dfs(node: GraphNode, path: inout [String]) -> [String]? {
            let nodeId = node.id

            // Skip root and tail nodes in cycle detection
            if node.isRoot || node.isTail {
                return nil
            }

            // If node is in recursion stack, we found a cycle
            if recursionStack.contains(nodeId) {
                // Find starting point of cycle
                if let startIndex = path.firstIndex(of: nodeId) {
                    return Array(path[startIndex...]) + [nodeId]
                }
                return path + [nodeId]
            }

            // If node already visited and not in recursion stack, no cycle here
            if visited.contains(nodeId) {
                return nil
            }

            // Mark node as visited and add to recursion stack
            visited.insert(nodeId)
            recursionStack.insert(nodeId)
            path.append(nodeId)

            // Explore all children
            for child in node.children {
                if let cycle = dfs(node: child, path: &path) {
                    return cycle
                }
            }

            // Backtrack
            path.removeLast()
            recursionStack.remove(nodeId)

            return nil
        }

        // Check each node that hasn't been visited
        for (id, node) in nodeMap {
            if !visited.contains(id) {
                if let cycle = dfs(node: node, path: &path) {
                    return cycle
                }
            }
        }

        return nil
    }
}

// MARK: - Hashable & Equatable
extension GraphNode: Hashable {
    public static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Root and Tail Nodes

extension GraphNode {
    /// Creates a single root node for the graph and checks for cycles
    /// - Parameter jobs: Array of jobs to build the graph from
    /// - Returns: A root node that contains all other nodes
    /// - Throws: An error if the graph contains a cycle or if there are missing nodes
    public static func buildRootNode() throws(GraphError) -> GraphNode {
        return GraphNode(
            id: GraphNode.rootId,
            job: Job(
                id: GraphNode.rootId, name: "root", steps: [], needs: [], environment: [:],
                lifecycle: [], form: nil), needs: [])
    }

    /// Creates a single tail node for the graph
    /// - Parameter jobs: Array of jobs to build the graph from
    /// - Returns: A tail node that is dependent on all terminal nodes
    /// - Throws: An error if the graph contains a cycle or if there are missing nodes
    public static func buildTailNode() throws(GraphError) -> GraphNode {
        return GraphNode(
            id: GraphNode.tailId,
            job: Job(
                id: GraphNode.tailId, name: "tail", steps: [], needs: [], environment: [:],
                lifecycle: [], form: nil), needs: [])
    }
}

/// Errors that can occur when working with graphs
public enum GraphError: Error, CustomStringConvertible {
    case cyclicDependency([String])
    case missingNode(jobId: String, dependencyId: String)

    public var description: String {
        switch self {
        case .cyclicDependency(let cycle):
            return "Cyclic dependency detected: \(cycle.joined(separator: " → "))"
        case .missingNode(let jobId, let dependencyId):
            return
                "Job '\(jobId)' depends on '\(dependencyId)' which does not exist in the job list"
        }
    }
}
