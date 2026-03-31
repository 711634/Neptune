import Foundation

struct Task: Identifiable, Codable, Equatable {
    let id: String
    let description: String
    let roleRequired: AgentRole
    var status: TaskStatus = .pending
    var prompt: String
    var acceptanceCriteria: [String] = []
    var dependencies: [String] = []  // Task IDs that must complete first
    var blockedBy: [String] = []  // Computed: dependencies not yet complete
    var output: String?
    var error: String?
    var artifacts: [String] = []  // Files created by this task
    var retryCount: Int = 0
    var maxRetries: Int = 3
    var timeout: TimeInterval = 3600  // 1 hour
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?

    var isReadyToRun: Bool {
        status == .pending && blockedBy.isEmpty
    }

    var duration: TimeInterval {
        guard let started = startedAt, let completed = completedAt else {
            return 0
        }
        return completed.timeIntervalSince(started)
    }

    var isBlocked: Bool {
        status == .blocked || !blockedBy.isEmpty
    }

    func formattedDuration() -> String {
        let interval = duration
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable, Equatable {
    case pending
    case queued
    case running
    case completed
    case failed
    case blocked
    case timedOut
    case skipped

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .queued: return "Queued"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .blocked: return "Blocked"
        case .timedOut: return "Timed Out"
        case .skipped: return "Skipped"
        }
    }

    var color: String {
        switch self {
        case .pending: return "6B7280"
        case .queued: return "F59E0B"
        case .running: return "3B82F6"
        case .completed: return "10B981"
        case .failed: return "EF4444"
        case .blocked: return "8B5CF6"
        case .timedOut: return "EF4444"
        case .skipped: return "9CA3AF"
        }
    }
}

struct TaskGraph: Codable, Equatable {
    private(set) var tasks: [String: Task] = [:]
    private(set) var taskOrder: [String] = []

    mutating func addTask(_ task: Task) throws {
        // Validate no circular dependencies
        if detectCircularDependency(task.id, dependencies: task.dependencies) {
            throw TaskGraphError.circularDependency(task.id)
        }

        tasks[task.id] = task
        if !taskOrder.contains(task.id) {
            taskOrder.append(task.id)
        }
    }

    mutating func markCompleted(taskId: String, output: String) throws {
        guard var task = tasks[taskId] else {
            throw TaskGraphError.taskNotFound(taskId)
        }

        task.status = .completed
        task.output = output
        task.completedAt = Date()
        tasks[taskId] = task

        // Update blocked tasks
        unblockDependents(of: taskId)
    }

    mutating func markFailed(taskId: String, error: String) throws {
        guard var task = tasks[taskId] else {
            throw TaskGraphError.taskNotFound(taskId)
        }

        task.error = error
        task.retryCount += 1

        if task.retryCount >= task.maxRetries {
            task.status = .failed
            task.completedAt = Date()
        } else {
            task.status = .pending  // Retry
        }

        tasks[taskId] = task
    }

    func getReadyTasks() -> [Task] {
        tasks.values
            .filter { $0.isReadyToRun }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func getTasksByRole(_ role: AgentRole) -> [Task] {
        tasks.values
            .filter { $0.roleRequired == role }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func getTask(_ id: String) -> Task? {
        tasks[id]
    }

    func detectDeadlock() -> (blockedTasks: [String], hasCircular: Bool)? {
        let blockedTasks = tasks.values.filter { $0.isBlocked && $0.status != .completed }.map { $0.id }

        if blockedTasks.isEmpty {
            return nil
        }

        let hasCircular = blockedTasks.contains { taskId in
            detectCircularDependency(taskId, dependencies: tasks[taskId]?.dependencies ?? [])
        }

        return (blockedTasks, hasCircular)
    }

    // MARK: - Private Helpers

    private func detectCircularDependency(_ taskId: String, dependencies: [String], visited: Set<String> = []) -> Bool {
        var visited = visited
        visited.insert(taskId)

        for depId in dependencies {
            if visited.contains(depId) {
                return true  // Circular dependency found
            }

            let depTask = tasks[depId]
            if let depTask = depTask, detectCircularDependency(depId, dependencies: depTask.dependencies, visited: visited) {
                return true
            }
        }

        return false
    }

    private mutating func unblockDependents(of completedTaskId: String) {
        let dependents = tasks.values.filter { $0.dependencies.contains(completedTaskId) }

        for dependent in dependents {
            var updated = dependent
            updated.blockedBy.removeAll { $0 == completedTaskId }

            if updated.blockedBy.isEmpty && updated.status == .blocked {
                updated.status = .pending
            }

            tasks[dependent.id] = updated
        }
    }
}

enum TaskGraphError: LocalizedError {
    case circularDependency(String)
    case taskNotFound(String)
    case invalidState

    var errorDescription: String? {
        switch self {
        case .circularDependency(let taskId):
            return "Circular dependency detected in task \(taskId)"
        case .taskNotFound(let taskId):
            return "Task not found: \(taskId)"
        case .invalidState:
            return "Task graph is in an invalid state"
        }
    }
}
