import Foundation

struct Client: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
}

struct WorkProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID
    var name: String
    var defaultTask: String = "Montage"
    var hourlyRate: Double = 0
    var isArchived: Bool = false
}

struct TimeEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID
    var task: String
    var start: Date
    var end: Date

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

enum TimerSource: String, Codable, Hashable {
    case manual
    case focus
}

struct RunningTimer: Codable, Hashable {
    var projectID: UUID
    var task: String
    var startedAt: Date
    var source: TimerSource = .manual
}

struct AppActivity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var appName: String
    var bundleIdentifier: String
    var start: Date
    var end: Date

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

enum FocusPhase: String, Codable, Hashable {
    case focus
    case breakTime
}

struct ActiveFocus: Codable, Hashable {
    var phase: FocusPhase
    var startedAt: Date
    var endsAt: Date
    var plannedMinutes: Int
    var projectID: UUID?
    var task: String
    var startedProjectTimer: Bool = false
}

struct FocusSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var phase: FocusPhase
    var start: Date
    var end: Date
    var plannedMinutes: Int
    var projectID: UUID?
    var task: String
    var completed: Bool
}

struct ParkingNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = Date()
    var isDone: Bool = false
}

struct DayItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var targetDate: Date
    var plannedMinutes: Int? = nil
    var isDone: Bool = false
    var completedAt: Date? = nil
    var createdAt: Date = Date()
}

struct DayCapacity: Codable, Hashable {
    var date: Date
    var availableWorkMinutes: Int?
}

struct PersistedState: Codable {
    var clients: [Client]
    var projects: [WorkProject]
    var entries: [TimeEntry]
    var runningTimer: RunningTimer?
    var appActivities: [AppActivity]
    var automaticAppTrackingEnabled: Bool
    var activeFocus: ActiveFocus?
    var focusSessions: [FocusSession]
    var parkingNotes: [ParkingNote]
    var dayItems: [DayItem]
    var dayCapacities: [DayCapacity]

    init(
        clients: [Client] = [],
        projects: [WorkProject] = [],
        entries: [TimeEntry] = [],
        runningTimer: RunningTimer? = nil,
        appActivities: [AppActivity] = [],
        automaticAppTrackingEnabled: Bool = true,
        activeFocus: ActiveFocus? = nil,
        focusSessions: [FocusSession] = [],
        parkingNotes: [ParkingNote] = [],
        dayItems: [DayItem] = [],
        dayCapacities: [DayCapacity] = []
    ) {
        self.clients = clients
        self.projects = projects
        self.entries = entries
        self.runningTimer = runningTimer
        self.appActivities = appActivities
        self.automaticAppTrackingEnabled = automaticAppTrackingEnabled
        self.activeFocus = activeFocus
        self.focusSessions = focusSessions
        self.parkingNotes = parkingNotes
        self.dayItems = dayItems
        self.dayCapacities = dayCapacities
    }

    enum CodingKeys: String, CodingKey {
        case clients, projects, entries, runningTimer
        case appActivities, automaticAppTrackingEnabled
        case activeFocus, focusSessions, parkingNotes
        case dayItems, dayCapacities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clients = try c.decodeIfPresent([Client].self, forKey: .clients) ?? []
        projects = try c.decodeIfPresent([WorkProject].self, forKey: .projects) ?? []
        entries = try c.decodeIfPresent([TimeEntry].self, forKey: .entries) ?? []
        runningTimer = try c.decodeIfPresent(RunningTimer.self, forKey: .runningTimer)
        appActivities = try c.decodeIfPresent([AppActivity].self, forKey: .appActivities) ?? []
        automaticAppTrackingEnabled = try c.decodeIfPresent(Bool.self, forKey: .automaticAppTrackingEnabled) ?? true
        activeFocus = try c.decodeIfPresent(ActiveFocus.self, forKey: .activeFocus)
        focusSessions = try c.decodeIfPresent([FocusSession].self, forKey: .focusSessions) ?? []
        parkingNotes = try c.decodeIfPresent([ParkingNote].self, forKey: .parkingNotes) ?? []
        dayItems = try c.decodeIfPresent([DayItem].self, forKey: .dayItems) ?? []
        dayCapacities = try c.decodeIfPresent([DayCapacity].self, forKey: .dayCapacities) ?? []
    }
}
