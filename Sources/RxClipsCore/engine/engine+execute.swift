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
                updateRunningStatusForLifecycle(index: index, in: &node.job, with: result)
                return true
            }
        }

        for index in 0..<node.job.steps.count {
            let lifeCycle = node.job.steps[index].lifecycle
            for lifeCycleIndex in 0..<(node.job.steps[index].lifecycle?.count ?? 0) {
                if node.job.steps[index].lifecycle?[lifeCycleIndex].id == id {
                    node.job.steps[index].lifecycle?[lifeCycleIndex].results.append(result)
                    if node.job.steps[index].lifecycle?[lifeCycleIndex] != nil {
                        updateRunningStatusForStepLifecycle(
                            stepIndex: index, lifecycleIndex: lifeCycleIndex, in: &node.job,
                            with: result)
                    }
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
                updateRunningStatusForStep(index: index, in: &node.job, with: result)
                return true
            }
        }
        return false
    }

    private func updateRunningStatusForLifecycle(
        index: Int, in job: inout Job, with result: ExecuteResult
    ) {
        let now = Date()
        var status: Status = .running(percentage: nil)

        switch result {
        case .bash:
            status = .running(percentage: nil)
        case .template(let templateResult):
            status = .running(percentage: templateResult.percentage)
        case .nextStep:
            status = .success(finishedAt: now)
        case .formRequest:
            status = .running(percentage: nil)
        }

        job.lifecycle[index].runningStatus = RunningStatus(
            status: status,
            startedAt: job.lifecycle[index].runningStatus.startedAt,
            updatedAt: now
        )
    }

    private func updateRunningStatusForStepLifecycle(
        stepIndex: Int, lifecycleIndex: Int, in job: inout Job, with result: ExecuteResult
    ) {
        let now = Date()
        var status: Status = .running(percentage: nil)

        switch result {
        case .bash:
            status = .running(percentage: nil)
        case .template(let templateResult):
            status = .running(percentage: templateResult.percentage)
        case .nextStep:
            status = .success(finishedAt: now)
        case .formRequest:
            status = .running(percentage: nil)
        }

        // Store startedAt in local variable to avoid overlapping access
        let startedAt =
            job.steps[stepIndex].lifecycle?[lifecycleIndex].runningStatus.startedAt ?? now

        job.steps[stepIndex].lifecycle?[lifecycleIndex].runningStatus = RunningStatus(
            status: status,
            startedAt: startedAt,
            updatedAt: now
        )
    }

    private func updateRunningStatusForStep(
        index: Int, in job: inout Job, with result: ExecuteResult
    ) {
        let now = Date()
        var status: Status = .running(percentage: nil)

        switch result {
        case .bash:
            status = .running(percentage: nil)
        case .template(let templateResult):
            status = .running(percentage: templateResult.percentage)
        case .nextStep:
            status = .success(finishedAt: now)
        case .formRequest:
            status = .running(percentage: nil)
        }

        job.steps[index].runningStatus = RunningStatus(
            status: status,
            startedAt: job.steps[index].runningStatus.startedAt,
            updatedAt: now
        )
    }

    internal func initializeRunningStatus(scriptId: String, in job: inout Job, startedAt: Date)
        async
    {
        for index in 0..<job.lifecycle.count {
            if job.lifecycle[index].script.id == scriptId {
                job.lifecycle[index].runningStatus = RunningStatus(
                    status: .running(percentage: nil),
                    startedAt: startedAt,
                    updatedAt: startedAt
                )
                return
            }
        }

        for index in 0..<job.steps.count {
            if job.steps[index].script.id == scriptId {
                job.steps[index].runningStatus = RunningStatus(
                    status: .running(percentage: nil),
                    startedAt: startedAt,
                    updatedAt: startedAt
                )
                return
            }

            for lifeCycleIndex in 0..<(job.steps[index].lifecycle?.count ?? 0) {
                if job.steps[index].lifecycle?[lifeCycleIndex].script.id == scriptId {
                    job.steps[index].lifecycle?[lifeCycleIndex].runningStatus = RunningStatus(
                        status: .running(percentage: nil),
                        startedAt: startedAt,
                        updatedAt: startedAt
                    )
                    return
                }
            }
        }
    }
}
