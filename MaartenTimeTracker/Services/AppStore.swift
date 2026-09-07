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
    @Published var parkedItems: [ParkedWorkItem] = []
    @Published var activeDistraction: ActiveDistraction?
    @Published var distractionPeriods: [DistractionPeriod] = []
    @Published var balanceDays: [BalanceDay] = []
    @Published var closedWorkdays: [ClosedWorkday] = []
    @Published var lastRewardMessage: String?

    init() {
        let state = PersistenceController.shared.load()
        clients = state.clients
        projects = state.projects
        dailyTasks = state.dailyTasks
        workBlocks = state.workBlocks
        activeBlock = state.activeBlock
        parkedItems = state.parkedItems
        activeDistraction = state.activeDistraction
        distractionPeriods = state.distractionPeriods
        balanceDays = state.balanceDays
        closedWorkdays = state.closedWorkdays

        migrateProjects()
        safelyParkOvernightBlock()
        save()
    }

    var isDistracted: Bool {
        activeDistraction != nil
    }

    var activeClient: Client? {
        guard let id = activeBlock?.clientID else { return nil }
        return clients.first(where: { $0.id == id })
    }

    var activeProject: WorkProject? {
        guard let id = activeBlock?.projectID else { return nil }
        return projects.first(where: { $0.id == id })
    }

    var isTodayClosed: Bool {
        closedWorkdays.contains { Calendar.current.isDateInToday($0.date) }
    }

    var todayTasks: [DailyTask] {
        dailyTasks.filter { Calendar.current.isDateInToday($0.date) }
    }

    var doneTodayTasks: [DailyTask] {
        todayTasks
            .filter { $0.isDone }
            .sorted { ($0.completedAt ?? $0.date) > ($1.completedAt ?? $1.date) }
    }

    var openTodayTasks: [DailyTask] {
        todayTasks.filter { !$0.isDone }
    }

    var startableTodayTasks: [DailyTask] {
        let parkedTaskIDs = Set(parkedItems.compactMap(\.dailyTaskID))
        return openTodayTasks
            .filter { !parkedTaskIDs.contains($0.id) }
            .sorted { $0.plannedMinutes < $1.plannedMinutes }
    }

    var todayDistractions: [DistractionPeriod] {
        distractionPeriods.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var distractionSecondsToday: TimeInterval {
        todayDistractions.reduce(0) { $0 + $1.duration } + currentDistractionSeconds
    }

    var recoverySecondsToday: TimeInterval {
        workBlocks
            .filter { Calendar.current.isDateInToday($0.startedAt) && $0.isRecovery }
            .reduce(0) { $0 + $1.focusedSeconds }
    }

    var recoveryOpenSeconds: TimeInterval {
        max(0, distractionSecondsToday - recoverySecondsToday)
    }

    var recoverySuggestionMinutes: Int {
        guard recoveryOpenSeconds >= 5 * 60 else { return 0 }
        return recoveryOpenSeconds <= 15 * 60 ? 15 : 30
    }

    var currentDistractionSeconds: TimeInterval {
        guard let activeDistraction else { return 0 }
        return max(0, Date().timeIntervalSince(activeDistraction.startedAt))
    }

    var focusMessage: String {
        let wins = workBlocks.filter {
            Calendar.current.isDateInToday($0.startedAt) && isStrongFocus($0)
        }.count

        switch wins {
        case 0:
            return "Eén goed blok is vandaag al winst."
        case 1:
            return "Je hebt vandaag al een sterk focusblok neergezet."
        default:
            return "Je hebt vandaag meerdere sterke focusblokken neergezet."
        }
    }

    var billingProjectSummaries: [BillingProjectSummary] {
        let openSessions = workBlocks.filter {
            !$0.invoiced && $0.projectID != nil && $0.clientID != nil && $0.focusedSeconds > 0
        }

        let unitGroups = Dictionary(grouping: openSessions, by: \.billingUnitID)

        let units: [BillingUnitSummary] = unitGroups.compactMap { unitID, sessions in
            guard let first = sessions.first,
                  let clientID = first.clientID,
                  let projectID = first.projectID else { return nil }

            let focused = sessions.reduce(0) { $0 + $1.focusedSeconds }
            guard focused > 0 else { return nil }

            return BillingUnitSummary(
                id: unitID,
                clientID: clientID,
                projectID: projectID,
                category: first.category,
                task: first.task,
                firstDate: sessions.map(\.startedAt).min() ?? first.startedAt,
                focusedSeconds: focused,
                billableMinutes: billableMinutes(for: focused)
            )
        }

        let byProject = Dictionary(grouping: units, by: \.projectID)

        return byProject.compactMap { projectID, projectUnits in
            guard let first = projectUnits.first else { return nil }
            return BillingProjectSummary(
                clientID: first.clientID,
                projectID: projectID,
                units: projectUnits.sorted { $0.firstDate > $1.firstDate },
                totalBillableMinutes: projectUnits.reduce(0) { $0 + $1.billableMinutes }
            )
        }
        .sorted {
            let leftClient = clientName(for: $0.clientID)
            let rightClient = clientName(for: $1.clientID)
            if leftClient == rightClient {
                return projectName(for: $0.projectID) < projectName(for: $1.projectID)
            }
            return leftClient < rightClient
        }
    }

    var doneTasksByDay: [(date: Date, tasks: [DailyTask])] {
        let done = dailyTasks.filter { $0.isDone }
        let grouped = Dictionary(grouping: done) {
            Calendar.current.startOfDay(for: $0.completedAt ?? $0.date)
        }

        return grouped
            .map { (date: $0.key, tasks: $0.value.sorted {
                ($0.completedAt ?? $0.date) > ($1.completedAt ?? $1.date)
            }) }
            .sorted { $0.date > $1.date }
    }

    func addClient(_ name: String) {
        let cleaned = clean(name)
        guard !cleaned.isEmpty else { return }
        clients.append(Client(name: cleaned))
        save()
    }

    func addProject(clientID: UUID, name: String) {
        let cleaned = clean(name)
        guard !cleaned.isEmpty else { return }
        projects.append(WorkProject(clientID: clientID, name: cleaned))
        save()
    }

    func addCustomTask(projectID: UUID, name: String) {
        let cleaned = clean(name)
        guard !cleaned.isEmpty,
              let index = projects.firstIndex(where: { $0.id == projectID }) else { return }

        if !projects[index].taskNames.contains(where: {
            $0.caseInsensitiveCompare(cleaned) == .orderedSame
        }) {
            projects[index].taskNames.append(cleaned)
            save()
        }
    }

    func deleteCustomTask(projectID: UUID, taskName: String) {
        guard !WorkProject.standardTaskNames.contains(taskName),
              let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].taskNames.removeAll { $0 == taskName }
        save()
    }

    func deleteProject(_ project: WorkProject) {
        guard activeBlock?.projectID != project.id,
              !parkedItems.contains(where: { $0.projectID == project.id }),
              !dailyTasks.contains(where: { $0.projectID == project.id && !$0.isDone }) else { return }
        projects.removeAll { $0.id == project.id }
        save()
    }

    func deleteClient(_ client: Client) {
        let projectIDs = Set(projects.filter { $0.clientID == client.id }.map(\.id))
        guard activeBlock?.clientID != client.id,
              !parkedItems.contains(where: { $0.clientID == client.id }),
              !dailyTasks.contains(where: {
                  guard let projectID = $0.projectID else { return false }
                  return projectIDs.contains(projectID) && !$0.isDone
              }) else { return }

        clients.removeAll { $0.id == client.id }
        projects.removeAll { $0.clientID == client.id }
        save()
    }

    @discardableResult
    func addDailyTask(
        projectID: UUID?,
        category: String,
        title: String,
        plannedMinutes: Int
    ) -> DailyTask? {
        let cleanedCategory = clean(category)
        let cleanedTitle = clean(title)
        let effectiveTitle = cleanedTitle.isEmpty ? cleanedCategory : cleanedTitle
        guard !effectiveTitle.isEmpty else { return nil }

        let task = DailyTask(
            projectID: projectID,
            title: effectiveTitle,
            category: cleanedCategory.isEmpty ? "Werk" : cleanedCategory,
            date: Calendar.current.startOfDay(for: Date()),
            plannedMinutes: plannedMinutes
        )
        dailyTasks.append(task)
        save()
        return task
    }

    func recordDoneToday(
        projectID: UUID?,
        category: String,
        title: String,
        minutes: Int
    ) {
        let cleanedCategory = clean(category)
        let cleanedTitle = clean(title)
        let effectiveTitle = cleanedTitle.isEmpty ? cleanedCategory : cleanedTitle
        guard !effectiveTitle.isEmpty else { return }

        let now = Date()
        let task = DailyTask(
            projectID: projectID,
            title: effectiveTitle,
            category: cleanedCategory.isEmpty ? "Werk" : cleanedCategory,
            date: Calendar.current.startOfDay(for: now),
            plannedMinutes: minutes,
            isDone: true,
            completedAt: now
        )
        dailyTasks.append(task)

        let project = projectID.flatMap { id in projects.first(where: { $0.id == id }) }
        let focused = TimeInterval(minutes * 60)

        workBlocks.insert(
            WorkBlock(
                clientID: project?.clientID,
                projectID: projectID,
                dailyTaskID: task.id,
                billingUnitID: task.billingUnitID,
                category: task.category,
                task: task.title,
                plannedMinutes: minutes,
                startedAt: now.addingTimeInterval(-focused),
                endedAt: now,
                distractionSeconds: 0,
                focusedSeconds: focused,
                billableMinutes: projectID == nil ? 0 : billableMinutes(for: focused),
                result: .done
            ),
            at: 0
        )

        lastRewardMessage = "Mooi. Dit heb je vandaag al gedaan."
        playRewardSound()
        save()
    }

    func moveTaskToTomorrow(_ task: DailyTask) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == task.id }),
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        dailyTasks[index].date = Calendar.current.startOfDay(for: tomorrow)
        dailyTasks[index].isDone = false
        dailyTasks[index].completedAt = nil
        save()
    }

    func deleteDailyTask(_ task: DailyTask) {
        guard activeBlock?.dailyTaskID != task.id,
              !parkedItems.contains(where: { $0.dailyTaskID == task.id }) else { return }
        dailyTasks.removeAll { $0.id == task.id }
        save()
    }

    func startDailyTask(_ task: DailyTask, asRecovery: Bool = false) {
        guard activeBlock == nil else { return }
        let project = task.projectID.flatMap { id in projects.first(where: { $0.id == id }) }

        activeBlock = ActiveWorkBlock(
            clientID: project?.clientID,
            projectID: task.projectID,
            dailyTaskID: task.id,
            billingUnitID: task.billingUnitID,
            category: task.category,
            task: task.title,
            plannedMinutes: task.plannedMinutes,
            isRecovery: asRecovery
        )

        activeDistraction = nil
        lastRewardMessage = nil
        reopenWorkdayIfNeeded()
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
        lastRewardMessage = "Goed gezien. Je bent terug bij je blok."
        save()
    }

    func finishActiveBlock(done: Bool) {
        guard var block = activeBlock else { return }

        if activeDistraction != nil {
            endDistraction()
            guard let refreshed = activeBlock else { return }
            block = refreshed
        }

        let session = makeSession(from: block, result: done ? .done : .stopped)
        workBlocks.insert(session, at: 0)

        if done,
           let taskID = block.dailyTaskID,
           let index = dailyTasks.firstIndex(where: { $0.id == taskID }) {
            dailyTasks[index].isDone = true
            dailyTasks[index].completedAt = session.endedAt
        }

        activeBlock = nil
        activeDistraction = nil

        if done {
            lastRewardMessage = "Klaar. Dit telt."
            playRewardSound()
        } else if isStrongFocus(session) {
            lastRewardMessage = "Goed blok gewerkt. Het hoefde niet af om te tellen."
            playRewardSound()
        } else {
            lastRewardMessage = "Blok gestopt. De taak blijft beschikbaar."
        }

        save()
    }

    func parkActiveBlock(resumeNote: String) {
        guard var block = activeBlock else { return }

        if activeDistraction != nil {
            endDistraction()
            guard let refreshed = activeBlock else { return }
            block = refreshed
        }

        let session = makeSession(from: block, result: .parked)
        workBlocks.insert(session, at: 0)

        parkedItems.removeAll { $0.billingUnitID == block.billingUnitID }
        parkedItems.insert(
            ParkedWorkItem(
                clientID: block.clientID,
                projectID: block.projectID,
                dailyTaskID: block.dailyTaskID,
                billingUnitID: block.billingUnitID,
                category: block.category,
                task: block.task,
                plannedMinutes: block.plannedMinutes,
                resumeNote: clean(resumeNote).isEmpty ? "Ga verder waar je gebleven was." : clean(resumeNote),
                parkedAt: Date()
            ),
            at: 0
        )

        activeBlock = nil
        activeDistraction = nil
        lastRewardMessage = "Veilig geparkeerd. Je hoeft dit nu niet in je hoofd te houden."
        if isStrongFocus(session) {
            playRewardSound()
        }
        save()
    }

    func resumeParked(_ item: ParkedWorkItem, asRecovery: Bool = false) {
        guard activeBlock == nil else { return }

        activeBlock = ActiveWorkBlock(
            clientID: item.clientID,
            projectID: item.projectID,
            dailyTaskID: item.dailyTaskID,
            billingUnitID: item.billingUnitID,
            category: item.category,
            task: item.task,
            plannedMinutes: item.plannedMinutes,
            isRecovery: asRecovery
        )

        parkedItems.removeAll { $0.id == item.id }
        lastRewardMessage = "Je blok staat weer klaar. Begin bij: \(item.resumeNote)"
        reopenWorkdayIfNeeded()
        save()
    }

    func removeParked(_ item: ParkedWorkItem) {
        parkedItems.removeAll { $0.id == item.id }
        save()
    }

    func markBillingUnitInvoiced(_ unitID: UUID) {
        for index in workBlocks.indices where
            workBlocks[index].billingUnitID == unitID &&
            !workBlocks[index].invoiced {
            workBlocks[index].invoiced = true
        }
        lastRewardMessage = "Gefactureerd. Uit je hoofd."
        playRewardSound()
        save()
    }

    func markProjectInvoiced(_ projectID: UUID) {
        for index in workBlocks.indices where
            workBlocks[index].projectID == projectID &&
            !workBlocks[index].invoiced {
            workBlocks[index].invoiced = true
        }
        lastRewardMessage = "Projecttijd gefactureerd. Klaar."
        playRewardSound()
        save()
    }

    func balanceForToday() -> BalanceDay {
        balanceDays.first(where: { Calendar.current.isDateInToday($0.date) })
            ?? BalanceDay(date: Calendar.current.startOfDay(for: Date()))
    }

    func updateBalanceText(kind: BalanceKind, text: String) {
        let index = ensureTodayBalance()
        switch kind {
        case .together: balanceDays[index].togetherText = text
        case .family: balanceDays[index].familyText = text
        case .selfCare: balanceDays[index].selfText = text
        }
        save()
    }

    func toggleBalance(kind: BalanceKind) {
        let index = ensureTodayBalance()
        switch kind {
        case .together: balanceDays[index].togetherDone.toggle()
        case .family: balanceDays[index].familyDone.toggle()
        case .selfCare: balanceDays[index].selfDone.toggle()
        }

        lastRewardMessage = "Mooi. Ook dit hoort bij een goede dag."
        playRewardSound()
        save()
    }

    func closeWorkday() {
        guard activeBlock == nil else { return }
        closedWorkdays.removeAll { Calendar.current.isDateInToday($0.date) }
        closedWorkdays.append(
            ClosedWorkday(
                date: Calendar.current.startOfDay(for: Date()),
                closedAt: Date()
            )
        )
        lastRewardMessage = "Werkdag gesloten. De rest mag wachten."
        playRewardSound()
        save()
    }

    func reopenWorkday() {
        closedWorkdays.removeAll { Calendar.current.isDateInToday($0.date) }
        lastRewardMessage = nil
        save()
    }

    func projectName(for id: UUID?) -> String {
        guard let id else { return "Algemeen / intern" }
        return projects.first(where: { $0.id == id })?.name ?? "Onbekend project"
    }

    func clientName(for id: UUID?) -> String {
        guard let id else { return "Niet facturabel" }
        return clients.first(where: { $0.id == id })?.name ?? "Onbekende klant"
    }

    func clientName(forProjectID projectID: UUID?) -> String {
        guard let projectID,
              let project = projects.first(where: { $0.id == projectID }) else {
            return "Intern"
        }
        return clientName(for: project.clientID)
    }

    func taskNames(for projectID: UUID?) -> [String] {
        guard let projectID,
              let project = projects.first(where: { $0.id == projectID }) else {
            return WorkProject.standardTaskNames
        }
        return project.taskNames
    }

    func billableMinutes(for focusedSeconds: TimeInterval) -> Int {
        guard focusedSeconds > 0 else { return 0 }
        let minutes = focusedSeconds / 60
        return max(15, Int(ceil(minutes / 15.0)) * 15)
    }

    private func makeSession(from block: ActiveWorkBlock, result: WorkBlockResult) -> WorkBlock {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(block.startedAt))
        let focused = max(0, elapsed - block.distractionSeconds)

        return WorkBlock(
            clientID: block.clientID,
            projectID: block.projectID,
            dailyTaskID: block.dailyTaskID,
            billingUnitID: block.billingUnitID,
            category: block.category,
            task: block.task,
            plannedMinutes: block.plannedMinutes,
            startedAt: block.startedAt,
            endedAt: now,
            distractionSeconds: block.distractionSeconds,
            focusedSeconds: focused,
            billableMinutes: block.projectID == nil ? 0 : billableMinutes(for: focused),
            result: result,
            isRecovery: block.isRecovery
        )
    }

    private func isStrongFocus(_ block: WorkBlock) -> Bool {
        let target = TimeInterval(max(15, block.plannedMinutes) * 60)
        let threshold = min(30 * 60, max(12 * 60, target * 0.75))
        return block.focusedSeconds >= threshold
    }

    private func ensureTodayBalance() -> Int {
        if let index = balanceDays.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            return index
        }

        balanceDays.append(BalanceDay(date: Calendar.current.startOfDay(for: Date())))
        return balanceDays.count - 1
    }

    private func reopenWorkdayIfNeeded() {
        if isTodayClosed {
            closedWorkdays.removeAll { Calendar.current.isDateInToday($0.date) }
        }
    }

    private func migrateProjects() {
        for index in projects.indices {
            if projects[index].taskNames.isEmpty {
                projects[index].taskNames = WorkProject.standardTaskNames
            } else {
                for standard in WorkProject.standardTaskNames where
                    !projects[index].taskNames.contains(standard) {
                    projects[index].taskNames.append(standard)
                }
            }
        }
    }

    private func safelyParkOvernightBlock() {
        guard let block = activeBlock,
              !Calendar.current.isDateInToday(block.startedAt) else { return }

        parkedItems.removeAll { $0.billingUnitID == block.billingUnitID }
        parkedItems.insert(
            ParkedWorkItem(
                clientID: block.clientID,
                projectID: block.projectID,
                dailyTaskID: block.dailyTaskID,
                billingUnitID: block.billingUnitID,
                category: block.category,
                task: block.task,
                plannedMinutes: block.plannedMinutes,
                resumeNote: "Dit blok stond nog open van gisteren. Hervat bewust vanaf je volgende stap.",
                parkedAt: Date()
            ),
            at: 0
        )

        activeBlock = nil
        activeDistraction = nil
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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
                parkedItems: parkedItems,
                activeDistraction: activeDistraction,
                distractionPeriods: distractionPeriods,
                balanceDays: balanceDays,
                closedWorkdays: closedWorkdays
            )
        )
    }
}
