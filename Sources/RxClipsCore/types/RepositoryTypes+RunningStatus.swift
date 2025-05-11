import Foundation

extension Job {
    /**
     Calculates the running status of the job based on the statuses of its steps and lifecycle events.
     - Logic:
        - If any step or lifecycle event is `.running`, the job is `.running` (average percentage if available).
        - If any step or lifecycle event is `.failure`, the job is `.failure` (with the latest finishedAt).
        - If all steps and lifecycle events are `.success`, the job is `.success` (with the latest finishedAt).
        - If all steps and lifecycle events are `.skipped`, the job is `.skipped`.
        - If all steps and lifecycle events are `.notStarted`, the job is `.notStarted`.
        - If steps and lifecycle events are a mix of `.notStarted` and `.skipped`, the job is `.notStarted`.
        - Otherwise, the job is `.unknown`.
     - Returns: The calculated `RunningStatus` for the job.
     */
    public var runningStatus: RunningStatus {
        let stepStatuses = steps.map { $0.runningStatus.status }
        let lifecycleStatuses = lifecycle.map { $0.runningStatus.status }
        let allStatuses = stepStatuses + lifecycleStatuses

        let stepStartedAts = steps.map { $0.runningStatus.startedAt }
        let lifecycleStartedAts = lifecycle.map { $0.runningStatus.startedAt }
        let allStartedAts = stepStartedAts + lifecycleStartedAts

        let stepUpdatedAts = steps.map { $0.runningStatus.updatedAt }
        let lifecycleUpdatedAts = lifecycle.map { $0.runningStatus.updatedAt }
        let allUpdatedAts = stepUpdatedAts + lifecycleUpdatedAts

        // Helper to get latest finishedAt among steps and lifecycle events
        func latestFinishedAt(for statusCase: (Status) -> Date?) -> Date? {
            let stepDates = steps.compactMap { statusCase($0.runningStatus.status) }
            let lifecycleDates = lifecycle.compactMap { statusCase($0.runningStatus.status) }
            return (stepDates + lifecycleDates).max()
        }

        // If there are no steps or lifecycle events, treat as notStarted
        guard !steps.isEmpty || !lifecycle.isEmpty else {
            return RunningStatus(status: .notStarted, startedAt: Date(), updatedAt: Date())
        }

        // If any step or lifecycle event is running
        let runningSteps = steps.filter {
            if case .running = $0.runningStatus.status { return true } else { return false }
        }
        let runningLifecycle = lifecycle.filter {
            if case .running = $0.runningStatus.status { return true } else { return false }
        }

        if !runningSteps.isEmpty || !runningLifecycle.isEmpty {
            // Average percentage for running items (ignore nils)
            let stepPercentages = runningSteps.compactMap {
                if case let .running(percentage) = $0.runningStatus.status {
                    return percentage
                } else {
                    return nil
                }
            }
            let lifecyclePercentages = runningLifecycle.compactMap {
                if case let .running(percentage) = $0.runningStatus.status {
                    return percentage
                } else {
                    return nil
                }
            }
            let allPercentages = stepPercentages + lifecyclePercentages
            let avgPercentage =
                allPercentages.isEmpty
                ? nil : (allPercentages.reduce(0, +) / Double(allPercentages.count))
            let startedAt = allStartedAts.min() ?? Date()
            let updatedAt = allUpdatedAts.max() ?? Date()
            return RunningStatus(
                status: .running(percentage: avgPercentage), startedAt: startedAt,
                updatedAt: updatedAt)
        }

        // If any step or lifecycle event is failure
        let failedStep = steps.first {
            if case .failure = $0.runningStatus.status { return true } else { return false }
        }
        let failedLifecycle = lifecycle.first {
            if case .failure = $0.runningStatus.status { return true } else { return false }
        }

        if let failedItem = failedStep {
            if case let .failure(finishedAt) = failedItem.runningStatus.status {
                let startedAt = allStartedAts.min() ?? Date()
                let updatedAt = allUpdatedAts.max() ?? finishedAt
                return RunningStatus(
                    status: .failure(finishedAt: finishedAt), startedAt: startedAt,
                    updatedAt: updatedAt)
            }
        } else if let failedItem = failedLifecycle {
            if case let .failure(finishedAt) = failedItem.runningStatus.status {
                let startedAt = allStartedAts.min() ?? Date()
                let updatedAt = allUpdatedAts.max() ?? finishedAt
                return RunningStatus(
                    status: .failure(finishedAt: finishedAt), startedAt: startedAt,
                    updatedAt: updatedAt)
            }
        }

        // If all steps and lifecycle events are success
        if allStatuses.allSatisfy({
            if case .success = $0 { return true } else { return false }
        }) {
            let latest =
                latestFinishedAt { status in
                    if case let .success(finishedAt) = status {
                        return finishedAt
                    } else {
                        return nil
                    }
                } ?? Date()
            let startedAt = allStartedAts.min() ?? Date()
            let updatedAt = allUpdatedAts.max() ?? latest
            return RunningStatus(
                status: .success(finishedAt: latest), startedAt: startedAt, updatedAt: updatedAt)
        }

        // If all steps and lifecycle events are skipped
        if allStatuses.allSatisfy({
            if case .skipped = $0 { return true } else { return false }
        }) {
            let startedAt = allStartedAts.min() ?? Date()
            let updatedAt = allUpdatedAts.max() ?? Date()
            return RunningStatus(status: .skipped, startedAt: startedAt, updatedAt: updatedAt)
        }

        // If all steps and lifecycle events are notStarted
        if allStatuses.allSatisfy({
            if case .notStarted = $0 { return true } else { return false }
        }) {
            let startedAt = allStartedAts.min() ?? Date()
            let updatedAt = allUpdatedAts.max() ?? Date()
            return RunningStatus(status: .notStarted, startedAt: startedAt, updatedAt: updatedAt)
        }

        // If all steps and lifecycle events are either notStarted or skipped, treat as notStarted
        if allStatuses.allSatisfy({
            if case .notStarted = $0 { return true }
            if case .skipped = $0 { return true }
            return false
        }) {
            let startedAt = allStartedAts.min() ?? Date()
            let updatedAt = allUpdatedAts.max() ?? Date()
            return RunningStatus(status: .notStarted, startedAt: startedAt, updatedAt: updatedAt)
        }

        // Otherwise, unknown
        let startedAt = allStartedAts.min() ?? Date()
        let updatedAt = allUpdatedAts.max() ?? Date()
        return RunningStatus(status: .unknown, startedAt: startedAt, updatedAt: updatedAt)
    }
}

extension Repository {
    /**
     Calculates the running status of the repository based on the statuses of its jobs.
     - Logic:
        - If any job is `.running`, the repository is `.running` (with averaged percentage if available).
        - If any job is `.failure`, the repository is `.failure` (with the latest finishedAt).
        - If all jobs are `.success`, the repository is `.success` (with the latest finishedAt).
        - If all jobs are `.skipped`, the repository is `.skipped`.
        - If all jobs are `.notStarted`, the repository is `.notStarted`.
        - If jobs are a mix of `.notStarted` and `.skipped`, the repository is `.notStarted`.
        - If repository has no jobs, it is treated as `.notStarted`.
        - Otherwise, the repository is `.unknown`.
     - Returns: The calculated `RunningStatus` for the repository.
     */
    public var runningStatus: RunningStatus {
        let statuses = jobs.map { $0.runningStatus.status }
        let startedAts = jobs.map { $0.runningStatus.startedAt }
        let updatedAts = jobs.map { $0.runningStatus.updatedAt }

        // Helper to get latest finishedAt among jobs
        func latestFinishedAt(for statusCase: (Status) -> Date?) -> Date? {
            return jobs.compactMap { statusCase($0.runningStatus.status) }.max()
        }

        // If there are no jobs, treat as notStarted
        guard !jobs.isEmpty else {
            return RunningStatus(status: .notStarted, startedAt: Date(), updatedAt: Date())
        }

        // If any job is running
        let runningJobs = jobs.filter {
            if case .running = $0.runningStatus.status { return true } else { return false }
        }
        if !runningJobs.isEmpty {
            // Average percentage for running jobs (ignore nils)
            let percentages = runningJobs.compactMap {
                if case let .running(percentage) = $0.runningStatus.status {
                    return percentage
                } else {
                    return nil
                }
            }
            let avgPercentage =
                percentages.isEmpty ? nil : (percentages.reduce(0, +) / Double(percentages.count))
            let startedAt = startedAts.min() ?? Date()
            let updatedAt = updatedAts.max() ?? Date()
            return RunningStatus(
                status: .running(percentage: avgPercentage), startedAt: startedAt,
                updatedAt: updatedAt)
        }

        // If any job is failure
        if let failedJob = jobs.first(where: {
            if case .failure = $0.runningStatus.status { return true } else { return false }
        }) {
            if case let .failure(finishedAt) = failedJob.runningStatus.status {
                let startedAt = startedAts.min() ?? Date()
                let updatedAt = updatedAts.max() ?? finishedAt
                return RunningStatus(
                    status: .failure(finishedAt: finishedAt), startedAt: startedAt,
                    updatedAt: updatedAt)
            }
        }

        // If all jobs are success
        if statuses.allSatisfy({
            if case .success = $0 { return true } else { return false }
        }) {
            let latest =
                latestFinishedAt { status in
                    if case let .success(finishedAt) = status {
                        return finishedAt
                    } else {
                        return nil
                    }
                } ?? Date()
            let startedAt = startedAts.min() ?? Date()
            let updatedAt = updatedAts.max() ?? latest
            return RunningStatus(
                status: .success(finishedAt: latest), startedAt: startedAt, updatedAt: updatedAt)
        }

        // If all jobs are skipped
        if statuses.allSatisfy({
            if case .skipped = $0 { return true } else { return false }
        }) {
            let startedAt = startedAts.min() ?? Date()
            let updatedAt = updatedAts.max() ?? Date()
            return RunningStatus(status: .skipped, startedAt: startedAt, updatedAt: updatedAt)
        }

        // If all jobs are notStarted
        if statuses.allSatisfy({
            if case .notStarted = $0 { return true } else { return false }
        }) {
            let startedAt = startedAts.min() ?? Date()
            let updatedAt = updatedAts.max() ?? Date()
            return RunningStatus(status: .notStarted, startedAt: startedAt, updatedAt: updatedAt)
        }

        // If all jobs are either notStarted or skipped, treat as notStarted
        if statuses.allSatisfy({
            if case .notStarted = $0 { return true }
            if case .skipped = $0 { return true }
            return false
        }) {
            let startedAt = startedAts.min() ?? Date()
            let updatedAt = updatedAts.max() ?? Date()
            return RunningStatus(status: .notStarted, startedAt: startedAt, updatedAt: updatedAt)
        }

        // Otherwise, unknown
        let startedAt = startedAts.min() ?? Date()
        let updatedAt = updatedAts.max() ?? Date()
        return RunningStatus(status: .unknown, startedAt: startedAt, updatedAt: updatedAt)
    }
}
