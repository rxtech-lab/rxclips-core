import Foundation

// MARK: - Execute
extension Engine {

    internal func addExecutionResult(
        id: String, for node: inout GraphNode, with result: ExecuteResult
    ) {
        if addExecutionResultToLifecycle(id: id, for: &node, with: result) {
            return
        }

        if addExecutionResultToStep(id: id, for: &node, with: result) {
            return
        }

    }

    internal func addExecutionResultToLifecycle(
        id: String, for node: inout GraphNode, with result: ExecuteResult
    ) -> Bool {
        for index in 0..<node.job.lifecycle.count {
            if node.job.lifecycle[index].script.id == id {
                node.job.lifecycle[index].results.append(result)
                return true
            }
        }

        for index in 0..<node.job.steps.count {
            for lifeCycleIndex in 0..<(node.job.steps[index].lifecycle?.count ?? 0) {
                if node.job.steps[index].lifecycle?[lifeCycleIndex].script.id == id {
                    node.job.steps[index].lifecycle?[lifeCycleIndex].results.append(result)
                    return true
                }
            }
        }
        return false
    }

    internal func addExecutionResultToStep(
        id: String, for node: inout GraphNode, with result: ExecuteResult
    ) -> Bool {
        for index in 0..<node.job.steps.count {
            if node.job.steps[index].script.id == id {
                node.job.steps[index].results.append(result)
                return true
            }
        }
        return false
    }

}
