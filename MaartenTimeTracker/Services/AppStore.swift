import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppStore: ObservableObject {
    @Published var clients: [Client] = []
    @Published var projects: [WorkProject] = []
    @Published var dailyTasks: [DailyTask] = []
    @Published var workBlocks: [WorkBlock] = []
    @Published var activeBlock: ActiveWorkBlock?
    @Published var activeDistraction: ActiveDistraction?
    @Published var distractionPeriods: [DistractionPeriod] = []
    @Published var lastRewardMessage: String?

    init() {
        let state = PersistenceController.shared.load()
        clients = state.clients
        projects = state.projects
        dailyTasks = state.dailyTasks
        workBlocks = state.workBlocks
        activeBlock = state.activeBlock
        activeDistraction = state.activeDistraction
        distractionPeriods = state.distractionPeriods
    }

    var isDistracted: Bool { activeDistraction != nil }

    var activeClient: Client? {
        guard let id = activeBlock?.clientID else { return nil }
        return clients.first(where: { $0.id == id })
    }

    var activeProject: WorkProject? {
        guard let id = activeBlock?.projectID else { return nil }
        return projects.first(where: { $0.id == id })
    }

    var todayTasks: [DailyTask] {
        dailyTasks
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    var openTodayTasks: [DailyTask] { todayTasks.filter { !$0.isDone } }
    var doneTodayTasks: [DailyTask] { todayTasks.filter { $0.isDone } }

    var todayBlocks: [WorkBlock] {
        workBlocks.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var todayDistractions: [DistractionPeriod] {
        distractionPeriods.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var distractionSecondsToday: TimeInterval {
        todayDistractions.reduce(0) { $0 + $1.duration } + currentDistractionSeconds
    }

    var recoverySecondsToday: TimeInterval {
        todayBlocks.filter { $0.isRecovery }.reduce(0) { $0 + $1.focusedSeconds }
    }

    var recoveryBalanceSeconds: TimeInterval {
        max(0, distractionSecondsToday - recoverySecondsToday)
    }

    var currentDistractionSeconds: TimeInterval {
        guard let activeDistraction else { return 0 }
        return max(0, Date().timeIntervalSince(activeDistraction.startedAt))
    }

    var uninvoicedByClient: [(client: Client, blocks: [WorkBlock], billableMinutes: Int)] {
        clients.compactMap { client in
            let blocks = workBlocks.filter {
                $0.clientID == client.id && !$0.invoiced && $0.billableMinutes > 0
            }
            guard !blocks.isEmpty else { return nil }
            return (client, blocks, blocks.reduce(0) { $0 + $1.billableMinutes })
        }
        .sorted { $0.client.name.localizedCaseInsensitiveCompare($1.client.name) == .orderedAscending }
    }

    func addClient(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        clients.append(Client(name: cleaned))
        save()
    }

    func deleteClient(_ client: Client) {
        guard activeBlock?.clientID != client.id else { return }
        let projectIDs = Set(projects.filter { $0.clientID == client.id }.map(\.id))
        guard !dailyTasks.contains(where: { task in
            if let id = task.projectID { return projectIDs.contains(id) && !task.isDone }
            return false
        }) else { return }

        clients.removeAll { $0.id == client.id }
        projects.removeAll { $0.clientID == client.id }
        save()
    }

    func addProject(clientID: UUID, name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        projects.append(WorkProject(clientID: clientID, name: cleaned))
        save()
    }

    func deleteProject(_ project: WorkProject) {
        guard activeBlock?.projectID != project.id else { return }
        guard !dailyTasks.contains(where: { $0.projectID == project.id && !$0.isDone }) else { return }
        projects.removeAll { $0.id == project.id }
        save()
    }

    func projectName(for id: UUID?) -> String {
        guard let id else { return "Algemeen" }
        return projects.first(where: { $0.id == id })?.name ?? "Onbekend project"
    }

    func clientForProject(_ projectID: UUID?) -> Client? {
        guard let projectID,
              let project = projects.first(where: { $0.id == projectID }) else { return nil }
        return clients.first(where: { $0.id == project.clientID })
    }

    func addDailyTask(projectID: UUID?, title: String, plannedMinutes: Int) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        dailyTasks.append(
            DailyTask(
                projectID: projectID,
                title: cleaned,
                date: Calendar.current.startOfDay(for: Date()),
                plannedMinutes: plannedMinutes
            )
        )
        save()
    }

    func recordDoneToday(projectID: UUID?, title: String, plannedMinutes: Int) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        dailyTasks.append(
            DailyTask(
                projectID: projectID,
                title: cleaned,
                date: Calendar.current.startOfDay(for: Date()),
                plannedMinutes: plannedMinutes,
                isDone: true,
                completedAt: Date()
            )
        )
        lastRewardMessage = "Mooi. Dit heb je vandaag al gedaan."
        playRewardSound()
        save()
    }

    func deleteDailyTask(_ task: DailyTask) {
        guard activeBlock?.dailyTaskID != task.id else { return }
        dailyTasks.removeAll { $0.id == task.id }
        save()
    }

    func startDailyTask(_ task: DailyTask, isRecovery: Bool = false) {
        let project = task.projectID.flatMap { id in projects.first(where: { $0.id == id }) }
        startBlock(
            clientID: project?.clientID,
            projectID: task.projectID,
            dailyTaskID: task.id,
            task: task.title,
            plannedMinutes: task.plannedMinutes,
            isRecovery: isRecovery
        )
    }

    func startBlock(
        clientID: UUID?,
        projectID: UUID? = nil,
        dailyTaskID: UUID? = nil,
        task: String,
        plannedMinutes: Int? = nil,
        isRecovery: Bool = false
    ) {
        guard activeBlock == nil else { return }
        let cleaned = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        activeBlock = ActiveWorkBlock(
            clientID: clientID,
            projectID: projectID,
            dailyTaskID: dailyTaskID,
            task: cleaned,
            plannedMinutes: plannedMinutes,
            startedAt: Date(),
            distractionSeconds: 0,
            isRecovery: isRecovery
        )
        activeDistraction = nil
        lastRewardMessage = nil
        save()
    }

    func startDistraction() {
        guard activeBlock != nil, activeDistraction == nil else { return }
        activeDistraction = ActiveDistraction(startedAt: Date())
        save()
    }

    func endDistraction() {
        guard var block = activeBlock,
              let distraction = activeDistraction else { return }

        let now = Date()
        let duration = max(0, now.timeIntervalSince(distraction.startedAt))
        block.distractionSeconds += duration
        activeBlock = block

        distractionPeriods.insert(
            DistractionPeriod(
                startedAt: distraction.startedAt,
                endedAt: now,
                task: block.task
            ),
            at: 0
        )

        activeDistraction = nil
        save()
    }

    func finishBlock(done: Bool) {
        guard var block = activeBlock else { return }

        if activeDistraction != nil {
            endDistraction()
            guard let refreshed = activeBlock else { return }
            block = refreshed
        }

        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(block.startedAt))
        let focused = max(0, elapsed - block.distractionSeconds)
        let billable = block.clientID == nil ? 0 : billableMinutes(for: focused)

        workBlocks.insert(
            WorkBlock(
                id: block.id,
                clientID: block.clientID,
                projectID: block.projectID,
                task: block.task,
                plannedMinutes: block.plannedMinutes,
                startedAt: block.startedAt,
                endedAt: now,
                distractionSeconds: block.distractionSeconds,
                focusedSeconds: focused,
                billableMinutes: billable,
                result: done ? .done : .stopped,
                invoiced: false,
                isRecovery: block.isRecovery
            ),
            at: 0
        )

        if done, let dailyTaskID = block.dailyTaskID,
           let index = dailyTasks.firstIndex(where: { $0.id == dailyTaskID }) {
            dailyTasks[index].isDone = true
            dailyTasks[index].completedAt = now
        }

        activeBlock = nil
        activeDistraction = nil

        if done {
            lastRewardMessage = "Klaar. Mooi gedaan."
            playRewardSound()
        } else if focused >= 25 * 60 {
            lastRewardMessage = "Goed blok gewerkt. Ook zonder afronden telt dat."
            playRewardSound()
        }

        save()
    }

    func markClientInvoiced(_ client: Client) {
        for index in workBlocks.indices
        where workBlocks[index].clientID == client.id && !workBlocks[index].invoiced {
            workBlocks[index].invoiced = true
        }
        lastRewardMessage = "Gefactureerd. Uit je hoofd."
        playRewardSound()
        save()
    }

    func deleteBlock(_ block: WorkBlock) {
        workBlocks.removeAll { $0.id == block.id }
        save()
    }

    func clientName(for id: UUID?) -> String {
        guard let id else { return "Niet facturabel" }
        return clients.first(where: { $0.id == id })?.name ?? "Onbekende klant"
    }

    func billableMinutes(for focusedSeconds: TimeInterval) -> Int {
        let minutes = focusedSeconds / 60
        let rounded = Int(ceil(minutes / 15.0)) * 15
        return max(15, rounded)
    }

    private func playRewardSound() {
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func save() {
        PersistenceController.shared.save(
            PersistedState(
                clients: clients,
                projects: projects,
                dailyTasks: dailyTasks,
                workBlocks: workBlocks,
                activeBlock: activeBlock,
                activeDistraction: activeDistraction,
                distractionPeriods: distractionPeriods
            )
        )
    }
}
