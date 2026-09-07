import Foundation

struct Client: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
}

struct WorkProject: Identifiable, Codable, Hashable {
    static let standardTaskNames = [
        "Concepting / voorwerk",
        "Opnames",
        "Ruwe montage",
        "Afronden / strak maken",
        "Klantcontact",
        "Opleveren / export",
        "Extra's"
    ]

    var id: UUID = UUID()
    var clientID: UUID
    var name: String
    var isArchived: Bool = false
    var taskNames: [String] = WorkProject.standardTaskNames

    init(
        id: UUID = UUID(),
        clientID: UUID,
        name: String,
        isArchived: Bool = false,
        taskNames: [String] = WorkProject.standardTaskNames
    ) {
        self.id = id
        self.clientID = clientID
        self.name = name
        self.isArchived = isArchived
        self.taskNames = taskNames.isEmpty ? WorkProject.standardTaskNames : taskNames
    }

    enum CodingKeys: String, CodingKey {
        case id, clientID, name, isArchived, taskNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        clientID = try c.decode(UUID.self, forKey: .clientID)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Project"
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        let decoded = try c.decodeIfPresent([String].self, forKey: .taskNames) ?? []
        taskNames = decoded.isEmpty ? WorkProject.standardTaskNames : decoded
    }
}

struct DailyTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var title: String
    var category: String
    var date: Date
    var plannedMinutes: Int
    var isDone: Bool = false
    var completedAt: Date? = nil
    var billingUnitID: UUID

    init(
        id: UUID = UUID(),
        projectID: UUID?,
        title: String,
        category: String,
        date: Date,
        plannedMinutes: Int,
        isDone: Bool = false,
        completedAt: Date? = nil,
        billingUnitID: UUID? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.category = category
        self.date = date
        self.plannedMinutes = plannedMinutes
        self.isDone = isDone
        self.completedAt = completedAt
        self.billingUnitID = billingUnitID ?? id
    }

    enum CodingKeys: String, CodingKey {
        case id, projectID, title, category, date, plannedMinutes
        case isDone, completedAt, billingUnitID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        projectID = try c.decodeIfPresent(UUID.self, forKey: .projectID)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Werk"
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "Extra's"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        plannedMinutes = try c.decodeIfPresent(Int.self, forKey: .plannedMinutes) ?? 30
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        billingUnitID = try c.decodeIfPresent(UUID.self, forKey: .billingUnitID) ?? id
    }
}

enum WorkBlockResult: String, Codable, Hashable {
    case done
    case stopped
    case parked
}

struct ActiveWorkBlock: Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID?
    var dailyTaskID: UUID?
    var billingUnitID: UUID
    var category: String
    var task: String
    var plannedMinutes: Int
    var startedAt: Date
    var distractionSeconds: TimeInterval = 0
    var isRecovery: Bool = false

    init(
        id: UUID = UUID(),
        clientID: UUID?,
        projectID: UUID?,
        dailyTaskID: UUID?,
        billingUnitID: UUID,
        category: String,
        task: String,
        plannedMinutes: Int,
        startedAt: Date = Date(),
        distractionSeconds: TimeInterval = 0,
        isRecovery: Bool = false
    ) {
        self.id = id
        self.clientID = clientID
        self.projectID = projectID
        self.dailyTaskID = dailyTaskID
        self.billingUnitID = billingUnitID
        self.category = category
        self.task = task
        self.plannedMinutes = plannedMinutes
        self.startedAt = startedAt
        self.distractionSeconds = distractionSeconds
        self.isRecovery = isRecovery
    }

    enum CodingKeys: String, CodingKey {
        case id, clientID, projectID, dailyTaskID, billingUnitID
        case category, task, plannedMinutes, startedAt, distractionSeconds, isRecovery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        clientID = try c.decodeIfPresent(UUID.self, forKey: .clientID)
        projectID = try c.decodeIfPresent(UUID.self, forKey: .projectID)
        dailyTaskID = try c.decodeIfPresent(UUID.self, forKey: .dailyTaskID)
        billingUnitID = try c.decodeIfPresent(UUID.self, forKey: .billingUnitID) ?? dailyTaskID ?? id
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "Extra's"
        task = try c.decodeIfPresent(String.self, forKey: .task) ?? category
        plannedMinutes = try c.decodeIfPresent(Int.self, forKey: .plannedMinutes) ?? 30
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        distractionSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .distractionSeconds) ?? 0
        isRecovery = try c.decodeIfPresent(Bool.self, forKey: .isRecovery) ?? false
    }
}

struct WorkBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID?
    var dailyTaskID: UUID?
    var billingUnitID: UUID
    var category: String
    var task: String
    var plannedMinutes: Int
    var startedAt: Date
    var endedAt: Date
    var distractionSeconds: TimeInterval
    var focusedSeconds: TimeInterval
    var billableMinutes: Int
    var result: WorkBlockResult
    var invoiced: Bool = false
    var isRecovery: Bool = false

    init(
        id: UUID = UUID(),
        clientID: UUID?,
        projectID: UUID?,
        dailyTaskID: UUID?,
        billingUnitID: UUID,
        category: String,
        task: String,
        plannedMinutes: Int,
        startedAt: Date,
        endedAt: Date,
        distractionSeconds: TimeInterval,
        focusedSeconds: TimeInterval,
        billableMinutes: Int,
        result: WorkBlockResult,
        invoiced: Bool = false,
        isRecovery: Bool = false
    ) {
        self.id = id
        self.clientID = clientID
        self.projectID = projectID
        self.dailyTaskID = dailyTaskID
        self.billingUnitID = billingUnitID
        self.category = category
        self.task = task
        self.plannedMinutes = plannedMinutes
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distractionSeconds = distractionSeconds
        self.focusedSeconds = focusedSeconds
        self.billableMinutes = billableMinutes
        self.result = result
        self.invoiced = invoiced
        self.isRecovery = isRecovery
    }

    enum CodingKeys: String, CodingKey {
        case id, clientID, projectID, dailyTaskID, billingUnitID
        case category, task, plannedMinutes, startedAt, endedAt
        case distractionSeconds, focusedSeconds, billableMinutes
        case result, invoiced, isRecovery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        clientID = try c.decodeIfPresent(UUID.self, forKey: .clientID)
        projectID = try c.decodeIfPresent(UUID.self, forKey: .projectID)
        dailyTaskID = try c.decodeIfPresent(UUID.self, forKey: .dailyTaskID)
        billingUnitID = try c.decodeIfPresent(UUID.self, forKey: .billingUnitID) ?? dailyTaskID ?? id
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "Extra's"
        task = try c.decodeIfPresent(String.self, forKey: .task) ?? category
        plannedMinutes = try c.decodeIfPresent(Int.self, forKey: .plannedMinutes) ?? 30
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt) ?? startedAt
        distractionSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .distractionSeconds) ?? 0
        focusedSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .focusedSeconds) ?? 0
        billableMinutes = try c.decodeIfPresent(Int.self, forKey: .billableMinutes) ?? 0
        result = try c.decodeIfPresent(WorkBlockResult.self, forKey: .result) ?? .stopped
        invoiced = try c.decodeIfPresent(Bool.self, forKey: .invoiced) ?? false
        isRecovery = try c.decodeIfPresent(Bool.self, forKey: .isRecovery) ?? false
    }
}

struct ParkedWorkItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID?
    var dailyTaskID: UUID?
    var billingUnitID: UUID
    var category: String
    var task: String
    var plannedMinutes: Int
    var resumeNote: String
    var parkedAt: Date
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

enum BalanceKind: String, CaseIterable, Identifiable {
    case together
    case family
    case selfCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .together: return "Samen"
        case .family: return "Gezin"
        case .selfCare: return "Zelf"
        }
    }

    var icon: String {
        switch self {
        case .together: return "heart"
        case .family: return "house"
        case .selfCare: return "leaf"
        }
    }
}

struct BalanceDay: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var togetherText: String = ""
    var familyText: String = ""
    var selfText: String = ""
    var togetherDone: Bool = false
    var familyDone: Bool = false
    var selfDone: Bool = false
}

struct ClosedWorkday: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var closedAt: Date
}

struct BillingUnitSummary: Identifiable, Hashable {
    var id: UUID
    var clientID: UUID
    var projectID: UUID
    var category: String
    var task: String
    var firstDate: Date
    var focusedSeconds: TimeInterval
    var billableMinutes: Int
}

struct BillingProjectSummary: Identifiable, Hashable {
    var id: UUID { projectID }
    var clientID: UUID
    var projectID: UUID
    var units: [BillingUnitSummary]
    var totalBillableMinutes: Int
}

struct PersistedState: Codable {
    var clients: [Client]
    var projects: [WorkProject]
    var dailyTasks: [DailyTask]
    var workBlocks: [WorkBlock]
    var activeBlock: ActiveWorkBlock?
    var parkedItems: [ParkedWorkItem]
    var activeDistraction: ActiveDistraction?
    var distractionPeriods: [DistractionPeriod]
    var balanceDays: [BalanceDay]
    var closedWorkdays: [ClosedWorkday]

    init(
        clients: [Client] = [],
        projects: [WorkProject] = [],
        dailyTasks: [DailyTask] = [],
        workBlocks: [WorkBlock] = [],
        activeBlock: ActiveWorkBlock? = nil,
        parkedItems: [ParkedWorkItem] = [],
        activeDistraction: ActiveDistraction? = nil,
        distractionPeriods: [DistractionPeriod] = [],
        balanceDays: [BalanceDay] = [],
        closedWorkdays: [ClosedWorkday] = []
    ) {
        self.clients = clients
        self.projects = projects
        self.dailyTasks = dailyTasks
        self.workBlocks = workBlocks
        self.activeBlock = activeBlock
        self.parkedItems = parkedItems
        self.activeDistraction = activeDistraction
        self.distractionPeriods = distractionPeriods
        self.balanceDays = balanceDays
        self.closedWorkdays = closedWorkdays
    }

    enum CodingKeys: String, CodingKey {
        case clients, projects, dailyTasks, workBlocks, activeBlock
        case parkedItems, activeDistraction, distractionPeriods
        case balanceDays, closedWorkdays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clients = try c.decodeIfPresent([Client].self, forKey: .clients) ?? []
        projects = try c.decodeIfPresent([WorkProject].self, forKey: .projects) ?? []
        dailyTasks = try c.decodeIfPresent([DailyTask].self, forKey: .dailyTasks) ?? []
        workBlocks = try c.decodeIfPresent([WorkBlock].self, forKey: .workBlocks) ?? []
        activeBlock = try c.decodeIfPresent(ActiveWorkBlock.self, forKey: .activeBlock)
        parkedItems = try c.decodeIfPresent([ParkedWorkItem].self, forKey: .parkedItems) ?? []
        activeDistraction = try c.decodeIfPresent(ActiveDistraction.self, forKey: .activeDistraction)
        distractionPeriods = try c.decodeIfPresent([DistractionPeriod].self, forKey: .distractionPeriods) ?? []
        balanceDays = try c.decodeIfPresent([BalanceDay].self, forKey: .balanceDays) ?? []
        closedWorkdays = try c.decodeIfPresent([ClosedWorkday].self, forKey: .closedWorkdays) ?? []
    }
}
