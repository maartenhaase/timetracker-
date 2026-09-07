import Foundation

struct Client: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
}

struct WorkProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID
    var name: String
    var isArchived: Bool = false
}

struct DailyTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var title: String
    var date: Date
    var plannedMinutes: Int
    var isDone: Bool = false
    var completedAt: Date? = nil
}

enum WorkBlockResult: String, Codable, Hashable {
    case done
    case stopped
}

struct ActiveWorkBlock: Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID? = nil
    var dailyTaskID: UUID? = nil
    var task: String
    var plannedMinutes: Int? = nil
    var startedAt: Date
    var distractionSeconds: TimeInterval = 0
    var isRecovery: Bool = false
}

struct WorkBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID? = nil
    var task: String
    var plannedMinutes: Int? = nil
    var startedAt: Date
    var endedAt: Date
    var distractionSeconds: TimeInterval
    var focusedSeconds: TimeInterval
    var billableMinutes: Int
    var result: WorkBlockResult
    var invoiced: Bool = false
    var isRecovery: Bool = false
}

struct ActiveDistraction: Codable, Hashable {
    var startedAt: Date
}

struct DistractionPeriod: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date
    var task: String

    var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

struct PersistedState: Codable {
    var clients: [Client]
    var projects: [WorkProject]
    var dailyTasks: [DailyTask]
    var workBlocks: [WorkBlock]
    var activeBlock: ActiveWorkBlock?
    var activeDistraction: ActiveDistraction?
    var distractionPeriods: [DistractionPeriod]

    init(
        clients: [Client] = [],
        projects: [WorkProject] = [],
        dailyTasks: [DailyTask] = [],
        workBlocks: [WorkBlock] = [],
        activeBlock: ActiveWorkBlock? = nil,
        activeDistraction: ActiveDistraction? = nil,
        distractionPeriods: [DistractionPeriod] = []
    ) {
        self.clients = clients
        self.projects = projects
        self.dailyTasks = dailyTasks
        self.workBlocks = workBlocks
        self.activeBlock = activeBlock
        self.activeDistraction = activeDistraction
        self.distractionPeriods = distractionPeriods
    }

    enum CodingKeys: String, CodingKey {
        case clients, projects, dailyTasks, workBlocks
        case activeBlock, activeDistraction, distractionPeriods
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clients = try c.decodeIfPresent([Client].self, forKey: .clients) ?? []
        projects = try c.decodeIfPresent([WorkProject].self, forKey: .projects) ?? []
        dailyTasks = try c.decodeIfPresent([DailyTask].self, forKey: .dailyTasks) ?? []
        workBlocks = try c.decodeIfPresent([WorkBlock].self, forKey: .workBlocks) ?? []
        activeBlock = try c.decodeIfPresent(ActiveWorkBlock.self, forKey: .activeBlock)
        activeDistraction = try c.decodeIfPresent(ActiveDistraction.self, forKey: .activeDistraction)
        distractionPeriods = try c.decodeIfPresent([DistractionPeriod].self, forKey: .distractionPeriods) ?? []
    }
}
