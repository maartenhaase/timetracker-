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
    case finalCut
}

struct RunningTimer: Codable, Hashable {
    var projectID: UUID
    var task: String
    var startedAt: Date
    var source: TimerSource = .manual
}

struct FinalCutMapping: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var detectedLabel: String
    var projectID: UUID
    var task: String = "Montage"
}

struct FinalCutActivity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var detectedLabel: String
    var start: Date
    var end: Date
    var imported: Bool = false

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct PersistedState: Codable {
    var clients: [Client] = []
    var projects: [WorkProject] = []
    var entries: [TimeEntry] = []
    var runningTimer: RunningTimer? = nil
    var finalCutMappings: [FinalCutMapping] = []
    var finalCutActivities: [FinalCutActivity] = []
    var autoSwitchFinalCut: Bool = false
}
