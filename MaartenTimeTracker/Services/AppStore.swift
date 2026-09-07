import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppStore: NSObject, ObservableObject {
    @Published var clients: [Client] = [] { didSet { save() } }
    @Published var projects: [WorkProject] = [] { didSet { save() } }
    @Published var entries: [TimeEntry] = [] { didSet { save() } }
    @Published var runningTimer: RunningTimer? { didSet { save() } }

    @Published var appActivities: [AppActivity] = [] { didSet { save() } }
    @Published var automaticAppTrackingEnabled = true {
        didSet {
            activityMonitor.trackingEnabled = automaticAppTrackingEnabled
            save()
        }
    }

    @Published var activeFocus: ActiveFocus? { didSet { save() } }
    @Published var focusSessions: [FocusSession] = [] { didSet { save() } }
    @Published var parkingNotes: [ParkingNote] = [] { didSet { save() } }
    @Published var dayItems: [DayItem] = [] { didSet { save() } }
    @Published var dayCapacities: [DayCapacity] = [] { didSet { save() } }
    @Published var focusJustCompleted = false
    @Published var lastRewardMessage: String? = nil

    let activityMonitor = AppActivityMonitor()
    let calendarService = CalendarService()

    private var isLoading = true
    private var heartbeat: Timer?

    override init() {
        super.init()

        let state = PersistenceController.shared.load()
        clients = state.clients
        projects = state.projects
        entries = state.entries
        runningTimer = state.runningTimer
        appActivities = state.appActivities
        automaticAppTrackingEnabled = state.automaticAppTrackingEnabled
        activeFocus = state.activeFocus
        focusSessions = state.focusSessions
        parkingNotes = state.parkingNotes
        dayItems = state.dayItems
        dayCapacities = state.dayCapacities

        activityMonitor.trackingEnabled = automaticAppTrackingEnabled
        activityMonitor.onActivityEnded = { [weak self] name, bundle, start, end in
            self?.recordAppActivity(name: name, bundle: bundle, start: start, end: end)
        }
        activityMonitor.start()
        calendarService.refresh()

        heartbeat = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(heartbeatFired),
            userInfo: nil,
            repeats: true
        )

        isLoading = false
        save()
    }

    deinit {
        heartbeat?.invalidate()
    }

    @objc private func heartbeatFired() {
        checkFocusCompletion()
    }

    var activeProject: WorkProject? {
        guard let id = runningTimer?.projectID else { return nil }
        return projects.first(where: { $0.id == id })
    }

    var focusRemaining: TimeInterval {
        guard let focus = activeFocus else { return 0 }
        return max(0, focus.endsAt.timeIntervalSinceNow)
    }

    var todayActivities: [AppActivity] {
        appActivities.filter { Calendar.current.isDateInToday($0.start) }
    }

    var todayTrackedAppTime: TimeInterval {
        todayActivities.reduce(0) { $0 + $1.duration }
    }

    func appSummary(for date: Date = Date()) -> [(name: String, bundle: String, duration: TimeInterval)] {
        let calendar = Calendar.current
        let filtered = appActivities.filter { calendar.isDate($0.start, inSameDayAs: date) }
        var totals: [String: (name: String, bundle: String, duration: TimeInterval)] = [:]

        for activity in filtered {
            let key = activity.bundleIdentifier.isEmpty ? activity.appName : activity.bundleIdentifier
            var current = totals[key] ?? (activity.appName, activity.bundleIdentifier, 0)
            current.duration += activity.duration
            totals[key] = current
        }

        return totals.values.sorted { $0.duration > $1.duration }
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
        runningTimer = RunningTimer(
            projectID: projectID,
            task: normalizedTask(task),
            startedAt: Date(),
            source: source
        )
    }

    func stopTimer() {
        guard let timer = runningTimer else { return }
        let end = Date()
        if end > timer.startedAt {
            entries.insert(
                TimeEntry(
                    projectID: timer.projectID,
                    task: timer.task,
                    start: timer.startedAt,
                    end: end
                ),
                at: 0
            )
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
        let project = WorkProject(
            clientID: clientID,
            name: cleaned,
            defaultTask: normalizedTask(defaultTask)
        )
        projects.append(project)
        return project
    }

    func deleteClient(_ client: Client) {
        let projectIDs = Set(projects.filter { $0.clientID == client.id }.map(\.id))
        if let current = runningTimer, projectIDs.contains(current.projectID) { stopTimer() }
        clients.removeAll { $0.id == client.id }
        projects.removeAll { $0.clientID == client.id }
    }

    func archiveProject(_ project: WorkProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        if runningTimer?.projectID == project.id { stopTimer() }
        projects[index].isArchived = true
    }

    func deleteEntry(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func addManualEntry(projectID: UUID, task: String, start: Date, end: Date) {
        guard end > start else { return }
        entries.insert(
            TimeEntry(
                projectID: projectID,
                task: normalizedTask(task),
                start: start,
                end: end
            ),
            at: 0
        )
    }

    func startFocus(minutes: Int, projectID: UUID?, task: String) {
        finishActiveFocus(completed: false, stopTimerIfStarted: true)

        let now = Date()
        let cleanedTask = normalizedTask(task)
        var startedTimer = false

        if let projectID {
            if runningTimer == nil {
                startTimer(projectID: projectID, task: cleanedTask, source: .focus)
                startedTimer = true
            }
        }

        activeFocus = ActiveFocus(
            phase: .focus,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(minutes * 60)),
            plannedMinutes: minutes,
            projectID: projectID,
            task: cleanedTask,
            startedProjectTimer: startedTimer
        )
        focusJustCompleted = false
    }

    func startBreak(minutes: Int) {
        finishActiveFocus(completed: false, stopTimerIfStarted: true)
        let now = Date()
        activeFocus = ActiveFocus(
            phase: .breakTime,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(minutes * 60)),
            plannedMinutes: minutes,
            projectID: nil,
            task: "Pauze",
            startedProjectTimer: false
        )
        focusJustCompleted = false
    }

    func stopFocus() {
        finishActiveFocus(completed: false, stopTimerIfStarted: true)
    }

    var todayItems: [DayItem] {
        dayItems.filter { Calendar.current.isDateInToday($0.targetDate) }
    }

    var tomorrowItems: [DayItem] {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return [] }
        return dayItems.filter { Calendar.current.isDate($0.targetDate, inSameDayAs: tomorrow) }
    }

    var completedTodayItems: [DayItem] {
        todayItems.filter { $0.isDone }
    }

    var openTodayItems: [DayItem] {
        todayItems.filter { !$0.isDone }
    }

    var completedFocusToday: [FocusSession] {
        focusSessions.filter {
            $0.phase == .focus &&
            $0.completed &&
            Calendar.current.isDateInToday($0.start)
        }
    }

    var todayFocusMessage: String {
        let count = completedFocusToday.count
        switch count {
        case 0:
            return "Nog geen afgerond focusblok — dat zegt niets over de waarde van je dag."
        case 1:
            return "Je hebt vandaag al een goed focusmoment neergezet."
        case 2...3:
            return "Je hebt vandaag meerdere sterke focusmomenten gehad."
        default:
            return "Je hebt vandaag opvallend veel geconcentreerde blokken opgebouwd."
        }
    }

    func dayCapacity(for date: Date) -> Int? {
        dayCapacities.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })?.availableWorkMinutes
    }

    func setDayCapacity(hours: Int?, for date: Date = Date()) {
        dayCapacities.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if let hours {
            dayCapacities.append(DayCapacity(date: Calendar.current.startOfDay(for: date), availableWorkMinutes: hours * 60))
        }
    }

    func addDayItem(title: String, plannedMinutes: Int? = nil, targetDate: Date = Date()) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        dayItems.append(
            DayItem(
                title: cleaned,
                targetDate: Calendar.current.startOfDay(for: targetDate),
                plannedMinutes: plannedMinutes
            )
        )
    }

    func recordDoneItem(title: String, targetDate: Date = Date()) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        dayItems.append(
            DayItem(
                title: cleaned,
                targetDate: Calendar.current.startOfDay(for: targetDate),
                isDone: true,
                completedAt: Date()
            )
        )
        lastRewardMessage = "Ja. Dit telt."
        playRewardSound()
    }

    func completeDayItem(_ item: DayItem) {
        guard let index = dayItems.firstIndex(where: { $0.id == item.id }) else { return }
        dayItems[index].isDone = true
        dayItems[index].completedAt = Date()
        lastRewardMessage = "Mooi. Dit heb je gedaan."
        playRewardSound()
    }

    func reopenDayItem(_ item: DayItem) {
        guard let index = dayItems.firstIndex(where: { $0.id == item.id }) else { return }
        dayItems[index].isDone = false
        dayItems[index].completedAt = nil
    }

    func moveDayItemToTomorrow(_ item: DayItem) {
        guard let index = dayItems.firstIndex(where: { $0.id == item.id }),
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        dayItems[index].targetDate = Calendar.current.startOfDay(for: tomorrow)
        dayItems[index].isDone = false
        dayItems[index].completedAt = nil
    }

    func deleteDayItem(_ item: DayItem) {
        dayItems.removeAll { $0.id == item.id }
    }

    func addParkingNote(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        parkingNotes.insert(ParkingNote(text: cleaned), at: 0)
    }

    func toggleParkingNote(_ note: ParkingNote) {
        guard let index = parkingNotes.firstIndex(where: { $0.id == note.id }) else { return }
        parkingNotes[index].isDone.toggle()
    }

    func deleteParkingNote(_ note: ParkingNote) {
        parkingNotes.removeAll { $0.id == note.id }
    }

    private func checkFocusCompletion() {
        guard let focus = activeFocus, Date() >= focus.endsAt else { return }
        finishActiveFocus(completed: true, stopTimerIfStarted: true)
        focusJustCompleted = true
        lastRewardMessage = "Goed focusblok. Afmaken was niet nodig om dit te laten tellen."
        playRewardSound()
        NSApp.requestUserAttention(.informationalRequest)
    }

    private func finishActiveFocus(completed: Bool, stopTimerIfStarted: Bool) {
        guard let focus = activeFocus else { return }
        let now = Date()
        let end = completed ? focus.endsAt : min(now, focus.endsAt)

        focusSessions.insert(
            FocusSession(
                phase: focus.phase,
                start: focus.startedAt,
                end: end,
                plannedMinutes: focus.plannedMinutes,
                projectID: focus.projectID,
                task: focus.task,
                completed: completed
            ),
            at: 0
        )

        if stopTimerIfStarted,
           focus.startedProjectTimer,
           runningTimer?.source == .focus {
            stopTimer()
        }

        activeFocus = nil
    }

    private func recordAppActivity(name: String, bundle: String, start: Date, end: Date) {
        guard end > start else { return }
        let activity = AppActivity(
            appName: name,
            bundleIdentifier: bundle,
            start: start,
            end: end
        )

        // Merge very small adjacent slices from the same app.
        if let first = appActivities.first,
           first.appName == name,
           first.bundleIdentifier == bundle,
           start.timeIntervalSince(first.end) < 4 {
            var merged = first
            merged.end = end
            appActivities[0] = merged
        } else {
            appActivities.insert(activity, at: 0)
        }

        if appActivities.count > 5000 {
            appActivities.removeLast(appActivities.count - 5000)
        }
    }

    private func playRewardSound() {
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func normalizedTask(_ task: String) -> String {
        let value = task.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Werk" : value
    }

    private func save() {
        guard !isLoading else { return }
        let state = PersistedState(
            clients: clients,
            projects: projects,
            entries: entries,
            runningTimer: runningTimer,
            appActivities: appActivities,
            automaticAppTrackingEnabled: automaticAppTrackingEnabled,
            activeFocus: activeFocus,
            focusSessions: focusSessions,
            parkingNotes: parkingNotes,
            dayItems: dayItems,
            dayCapacities: dayCapacities
        )
        PersistenceController.shared.save(state)
    }
}
