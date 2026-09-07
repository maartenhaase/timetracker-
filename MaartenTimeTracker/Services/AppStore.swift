import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var clients: [Client] = [] { didSet { save() } }
    @Published var projects: [WorkProject] = [] { didSet { save() } }
    @Published var entries: [TimeEntry] = [] { didSet { save() } }
    @Published var runningTimer: RunningTimer? { didSet { save() } }
    @Published var finalCutMappings: [FinalCutMapping] = [] { didSet { save() } }
    @Published var finalCutActivities: [FinalCutActivity] = [] { didSet { save() } }
    @Published var autoSwitchFinalCut = false { didSet { save() } }
    @Published var pendingFinalCutLabel: String = ""

    let finalCutMonitor = FinalCutMonitor()
    private var isLoading = true

    init() {
        let state = PersistenceController.shared.load()
        clients = state.clients
        projects = state.projects
        entries = state.entries
        runningTimer = state.runningTimer
        finalCutMappings = state.finalCutMappings
        finalCutActivities = state.finalCutActivities
        autoSwitchFinalCut = state.autoSwitchFinalCut
        isLoading = false

        finalCutMonitor.onActivityEnded = { [weak self] label, start, end in
            self?.recordFinalCutActivity(label: label, start: start, end: end)
        }
        finalCutMonitor.onDetectedLabelChanged = { [weak self] label in
            self?.handleDetectedFinalCutLabel(label)
        }
        finalCutMonitor.onFrontmostChanged = { [weak self] isFrontmost in
            guard let self else { return }
            if !isFrontmost,
               self.autoSwitchFinalCut,
               self.runningTimer?.source == .finalCut {
                self.stopTimer()
            }
        }
        finalCutMonitor.start()
    }

    var activeProject: WorkProject? {
        guard let id = runningTimer?.projectID else { return nil }
        return projects.first(where: { $0.id == id })
    }

    func clientName(for project: WorkProject) -> String {
        clients.first(where: { $0.id == project.clientID })?.name ?? "Onbekende klant"
    }

    func projectName(_ id: UUID) -> String {
        projects.first(where: { $0.id == id })?.name ?? "Verwijderd project"
    }

    func startTimer(projectID: UUID, task: String, source: TimerSource = .manual) {
        if let current = runningTimer,
           current.projectID == projectID,
           current.task == normalizedTask(task),
           current.source == source {
            return
        }

        if runningTimer != nil { stopTimer() }
        runningTimer = RunningTimer(projectID: projectID,
                                    task: normalizedTask(task),
                                    startedAt: Date(),
                                    source: source)
    }

    func stopTimer() {
        guard let timer = runningTimer else { return }
        let end = Date()
        if end > timer.startedAt {
            entries.insert(TimeEntry(projectID: timer.projectID,
                                     task: timer.task,
                                     start: timer.startedAt,
                                     end: end), at: 0)
        }
        runningTimer = nil
    }

    @discardableResult
    func addClient(name: String) -> Client? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let client = Client(name: cleaned)
        clients.append(client)
        return client
    }

    @discardableResult
    func addProject(clientID: UUID, name: String, defaultTask: String = "Montage") -> WorkProject? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let project = WorkProject(clientID: clientID,
                                  name: cleaned,
                                  defaultTask: normalizedTask(defaultTask))
        projects.append(project)
        return project
    }

    func archiveProject(_ project: WorkProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        if runningTimer?.projectID == project.id { stopTimer() }
        projects[index].isArchived = true
    }

    func deleteClient(_ client: Client) {
        let projectIDs = Set(projects.filter { $0.clientID == client.id }.map(\.id))
        if let current = runningTimer, projectIDs.contains(current.projectID) { stopTimer() }
        clients.removeAll { $0.id == client.id }
        projects.removeAll { $0.clientID == client.id }
        finalCutMappings.removeAll { projectIDs.contains($0.projectID) }
    }

    func deleteEntry(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func addManualEntry(projectID: UUID, task: String, start: Date, end: Date) {
        guard end > start else { return }
        entries.insert(TimeEntry(projectID: projectID,
                                 task: normalizedTask(task),
                                 start: start,
                                 end: end), at: 0)
    }

    func addMapping(label: String, projectID: UUID, task: String) {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        finalCutMappings.removeAll { $0.detectedLabel.caseInsensitiveCompare(cleaned) == .orderedSame }
        finalCutMappings.append(FinalCutMapping(detectedLabel: cleaned,
                                                projectID: projectID,
                                                task: normalizedTask(task)))
        pendingFinalCutLabel = ""
        if autoSwitchFinalCut && finalCutMonitor.isFinalCutFrontmost {
            startTimer(projectID: projectID, task: task, source: .finalCut)
        }
    }

    func importActivity(_ activity: FinalCutActivity, using mapping: FinalCutMapping) {
        guard let index = finalCutActivities.firstIndex(where: { $0.id == activity.id }),
              !finalCutActivities[index].imported else { return }
        entries.insert(TimeEntry(projectID: mapping.projectID,
                                 task: mapping.task,
                                 start: activity.start,
                                 end: activity.end), at: 0)
        finalCutActivities[index].imported = true
    }

    func mapping(for label: String) -> FinalCutMapping? {
        finalCutMappings.first { $0.detectedLabel.caseInsensitiveCompare(label) == .orderedSame }
    }

    private func handleDetectedFinalCutLabel(_ label: String) {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            pendingFinalCutLabel = ""
            if autoSwitchFinalCut && runningTimer?.source == .finalCut {
                stopTimer()
            }
            return
        }

        if let mapping = mapping(for: cleaned) {
            pendingFinalCutLabel = ""
            if autoSwitchFinalCut {
                if runningTimer?.projectID != mapping.projectID ||
                    runningTimer?.task != mapping.task ||
                    runningTimer?.source != .finalCut {
                    startTimer(projectID: mapping.projectID,
                               task: mapping.task,
                               source: .finalCut)
                }
            }
        } else {
            pendingFinalCutLabel = cleaned
            if autoSwitchFinalCut && runningTimer?.source == .finalCut {
                stopTimer()
            }
        }
    }

    private func recordFinalCutActivity(label: String, start: Date, end: Date) {
        guard end > start else { return }
        finalCutActivities.insert(FinalCutActivity(detectedLabel: label,
                                                   start: start,
                                                   end: end), at: 0)
        if finalCutActivities.count > 500 {
            finalCutActivities.removeLast(finalCutActivities.count - 500)
        }
    }

    private func normalizedTask(_ task: String) -> String {
        let value = task.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Werk" : value
    }

    private func save() {
        guard !isLoading else { return }
        let state = PersistedState(clients: clients,
                                   projects: projects,
                                   entries: entries,
                                   runningTimer: runningTimer,
                                   finalCutMappings: finalCutMappings,
                                   finalCutActivities: finalCutActivities,
                                   autoSwitchFinalCut: autoSwitchFinalCut)
        PersistenceController.shared.save(state)
    }
}
