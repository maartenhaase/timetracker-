import Foundation
import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore

    @State private var planProjectID: UUID?
    @State private var planCategory = WorkProject.standardTaskNames[0]
    @State private var planTitle = ""
    @State private var planMinutes = 30

    @State private var doneProjectID: UUID?
    @State private var doneCategory = WorkProject.standardTaskNames[0]
    @State private var doneTitle = ""
    @State private var doneMinutes = 30

    @State private var showParkSheet = false
    @State private var resumeNote = ""

    private let durations = [15, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let active = store.activeBlock {
                    activeBlockCard(active)
                } else if store.isTodayClosed {
                    closedWorkdayCard
                    doneTodayCard
                    balanceCard
                } else {
                    if !store.parkedItems.isEmpty {
                        parkedCard
                    }

                    plannedCard
                    addBlockCard
                    alreadyDoneCard
                    doneTodayCard
                    balanceCard

                    if store.recoverySuggestionMinutes > 0 {
                        recoveryCard
                    }

                    closeWorkdayCard
                }

                if let message = store.lastRewardMessage {
                    Label(message, systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .flowCard()
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $showParkSheet) {
            parkingSheet
        }
        .onChange(of: planProjectID) { _, newValue in
            let names = store.taskNames(for: newValue)
            if !names.contains(planCategory) {
                planCategory = names.first ?? "Werk"
            }
        }
        .onChange(of: doneProjectID) { _, newValue in
            let names = store.taskNames(for: newValue)
            if !names.contains(doneCategory) {
                doneCategory = names.first ?? "Werk"
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Vandaag")
                .font(.largeTitle.bold())

            if store.isTodayClosed {
                Text("Je werkdag is gesloten. De rest hoeft nu niet in je hoofd.")
                    .foregroundStyle(.secondary)
            } else {
                Text(store.focusMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var plannedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wat zou fijn zijn als het vandaag lukt?", systemImage: "list.bullet")
                    .font(.title3.bold())
                Spacer()
                Text("mogelijkheden, geen schuldcontract")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.startableTodayTasks.isEmpty {
                Text("Nog geen open blokken. Voeg alleen toe wat vandaag echt ruimte mag krijgen.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.startableTodayTasks) { task in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.headline)

                                Text("\(projectLabel(task.projectID)) · \(task.category) · \(durationText(task.plannedMinutes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                store.startDailyTask(task)
                            } label: {
                                Label("BEGIN", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            if store.recoverySuggestionMinutes > 0 {
                                Menu {
                                    Button("Begin als herstelblok") {
                                        store.startDailyTask(task, asRecovery: true)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .menuStyle(.borderlessButton)
                            }

                            Button(role: .destructive) {
                                store.deleteDailyTask(task)
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.borderless)
                        }

                        if task.id != store.startableTodayTasks.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .flowCard()
    }

    private var parkedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Veilig geparkeerd", systemImage: "pause.circle.fill")
                .font(.title3.bold())

            Text("Deze blokken hoef je niet mentaal vast te houden. De volgende stap staat erbij.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(store.parkedItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.task)
                                .font(.headline)
                            Text("\(projectLabel(item.projectID)) · \(item.category)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            store.resumeParked(item)
                        } label: {
                            Label("HERVAT", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Label(item.resumeNote, systemImage: "arrow.right")
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Geparkeerd \(item.parkedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Button("Laat los") {
                            store.removeParked(item)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                .padding(.vertical, 4)

                if item.id != store.parkedItems.last?.id {
                    Divider()
                }
            }
        }
        .flowCard()
    }

    private var addBlockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Blok toevoegen", systemImage: "plus.circle")
                .font(.headline)

            projectPicker(selection: $planProjectID)
            categoryPicker(projectID: planProjectID, selection: $planCategory)

            TextField("Wat ga je concreet doen? (optioneel)", text: $planTitle)

            durationPicker(selection: $planMinutes)

            Button {
                _ = store.addDailyTask(
                    projectID: planProjectID,
                    category: planCategory,
                    title: planTitle,
                    plannedMinutes: planMinutes
                )
                planTitle = ""
                planMinutes = 30
            } label: {
                Label("Zet op vandaag", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
        }
        .flowCard()
    }

    private var alreadyDoneCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ook werk dat nooit op je lijst stond mag achteraf gewoon meetellen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                projectPicker(selection: $doneProjectID)
                categoryPicker(projectID: doneProjectID, selection: $doneCategory)
                TextField("Wat heb je gedaan? (optioneel)", text: $doneTitle)
                durationPicker(selection: $doneMinutes)

                Button {
                    store.recordDoneToday(
                        projectID: doneProjectID,
                        category: doneCategory,
                        title: doneTitle,
                        minutes: doneMinutes
                    )
                    doneTitle = ""
                    doneMinutes = 30
                } label: {
                    Label("Tel mee", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        } label: {
            Label("Wat heb je al gedaan?", systemImage: "sparkles")
                .font(.headline)
        }
        .flowCard()
    }

    private var doneTodayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dit heb je vandaag gedaan", systemImage: "checkmark.circle.fill")
                .font(.title3.bold())

            if store.doneTodayTasks.isEmpty {
                Text("Nog niets geregistreerd. Dat betekent niet dat er niets gebeurd is.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.doneTodayTasks.prefix(10)) { task in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                            Text("\(projectLabel(task.projectID)) · \(task.category) · \(durationText(task.plannedMinutes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .flowCard()
    }

    private var balanceCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                Text("Geen timers en geen score. Hooguit één klein anker buiten werk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                balanceRow(.together)
                balanceRow(.family)
                balanceRow(.selfCare)
            }
            .padding(.top, 10)
        } label: {
            Label("Buiten werk: Samen · Gezin · Zelf", systemImage: "heart")
                .font(.headline)
        }
        .flowCard()
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Herstelruimte", systemImage: "arrow.counterclockwise.circle")
                .font(.headline)

            Text("Er waren vandaag wat afleidmomenten. Als het jou helpt om rustig af te sluiten, is één herstelblok van ongeveer \(durationText(store.recoverySuggestionMinutes)) genoeg.")
                .foregroundStyle(.secondary)

            Text("Niet verplicht, en dit wordt morgen niet als schuld meegenomen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .flowCard()
    }

    private var closeWorkdayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Werkdag afronden", systemImage: "door.left.hand.closed")
                .font(.title3.bold())

            if !store.openTodayTasks.isEmpty {
                Text("Wat nog open staat hoeft niet automatisch mee naar morgen. Kies alleen bewust wat je wilt meenemen.")
                    .foregroundStyle(.secondary)

                ForEach(store.openTodayTasks) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                            Text(projectLabel(task.projectID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Morgen") {
                            store.moveTaskToTomorrow(task)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else {
                Text("Er staan geen geplande blokken meer open.")
                    .foregroundStyle(.secondary)
            }

            if !store.parkedItems.isEmpty {
                Label("Geparkeerde blokken blijven veilig bewaard.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.closeWorkday()
            } label: {
                Label("WERKDAG SLUITEN", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .flowCard()
    }

    private var closedWorkdayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Werkdag gesloten", systemImage: "checkmark.seal.fill")
                .font(.title2.bold())

            Text("De open blokken hoeven vanavond niet door je hoofd te blijven lopen.")
                .foregroundStyle(.secondary)

            if !store.parkedItems.isEmpty {
                Text("Ook je geparkeerde werk blijft bewaard met de volgende stap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Toch weer openen") {
                store.reopenWorkday()
            }
            .buttonStyle(.borderless)
        }
        .flowCard()
    }

    @ViewBuilder
    private func activeBlockCard(_ block: ActiveWorkBlock) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let focused = focusedSeconds(block, at: context.date)
            let target = TimeInterval(max(15, block.plannedMinutes) * 60)
            let progress = min(1, focused / max(1, target))

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(projectLabel(block.projectID))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(block.category.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(block.task)
                        .font(.title.bold())

                    Text("Blok: \(durationText(block.plannedMinutes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if store.isDistracted {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("AFGELEID", systemImage: "exclamationmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.red)

                        Text("De focustijd staat stil. Zodra je het merkt, hoef je alleen terug te keren.")
                            .foregroundStyle(.secondary)

                        Button {
                            store.endDistraction()
                        } label: {
                            Label("IK BEN TERUG", systemImage: "arrow.uturn.backward")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress)
                        Text(blockStatus(focused, target: target))
                            .font(.headline)

                        Text(progress >= 1
                             ? "Je geplande focusblok staat. Alleen doorgaan als dat nog logisch is."
                             : "De balk is richting, geen verplichting om de hele taak af te krijgen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            store.finishActiveBlock(done: true)
                        } label: {
                            Label("KLAAR", systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            resumeNote = ""
                            showParkSheet = true
                        } label: {
                            Label("PARKEREN", systemImage: "pause.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button {
                            store.startDistraction()
                        } label: {
                            Label("AFGELEID", systemImage: "exclamationmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    Button("Stop blok; taak blijft open") {
                        store.finishActiveBlock(done: false)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                if block.isRecovery {
                    Label("Dit blok telt ook als herstelblok.", systemImage: "arrow.counterclockwise.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var parkingSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Blok veilig parkeren")
                .font(.title2.bold())

            Text("Schrijf alleen de eerstvolgende stap op. Dan hoeft je hoofd het blok niet vast te houden.")
                .foregroundStyle(.secondary)

            TextField("Bijv. verder bij 03:42 en logo vervangen", text: $resumeNote)

            HStack {
                Spacer()
                Button("Annuleer") {
                    showParkSheet = false
                }
                Button("Parkeer veilig") {
                    store.parkActiveBlock(resumeNote: resumeNote)
                    showParkSheet = false
                    resumeNote = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 470)
    }

    private func projectPicker(selection: Binding<UUID?>) -> some View {
        Picker("Project", selection: selection) {
            Text("Algemeen / intern").tag(UUID?.none)

            ForEach(store.projects.filter { !$0.isArchived }) { project in
                Text(projectPickerLabel(project))
                    .tag(Optional(project.id))
            }
        }
    }

    private func categoryPicker(projectID: UUID?, selection: Binding<String>) -> some View {
        Picker("Soort werk", selection: selection) {
            ForEach(store.taskNames(for: projectID), id: \.self) { name in
                Text(name).tag(name)
            }
        }
    }

    private func durationPicker(selection: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            ForEach(durations, id: \.self) { minutes in
                Button(durationText(minutes)) {
                    selection.wrappedValue = minutes
                }
                .buttonStyle(.bordered)
                .overlay {
                    if selection.wrappedValue == minutes {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.primary, lineWidth: 2)
                    }
                }
            }
        }
    }

    private func balanceRow(_ kind: BalanceKind) -> some View {
        let day = store.balanceForToday()
        let currentText: String
        let isDone: Bool

        switch kind {
        case .together:
            currentText = day.togetherText
            isDone = day.togetherDone
        case .family:
            currentText = day.familyText
            isDone = day.familyDone
        case .selfCare:
            currentText = day.selfText
            isDone = day.selfDone
        }

        return HStack(spacing: 10) {
            Button {
                store.toggleBalance(kind: kind)
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            Label(kind.title, systemImage: kind.icon)
                .frame(width: 90, alignment: .leading)

            TextField(
                kind == .together ? "bijv. even samen koffie" :
                kind == .family ? "bijv. bewust spelen / eten" :
                "bijv. muziek, wandelen of niets",
                text: Binding(
                    get: { currentBalanceText(kind) },
                    set: { store.updateBalanceText(kind: kind, text: $0) }
                )
            )
        }
    }

    private func currentBalanceText(_ kind: BalanceKind) -> String {
        let day = store.balanceForToday()
        switch kind {
        case .together: return day.togetherText
        case .family: return day.familyText
        case .selfCare: return day.selfText
        }
    }

    private func focusedSeconds(_ block: ActiveWorkBlock, at date: Date) -> TimeInterval {
        var distraction = block.distractionSeconds
        if let current = store.activeDistraction {
            distraction += max(0, date.timeIntervalSince(current.startedAt))
        }
        return max(0, date.timeIntervalSince(block.startedAt) - distraction)
    }

    private func blockStatus(_ seconds: TimeInterval, target: TimeInterval) -> String {
        let fraction = seconds / max(1, target)

        if fraction < 0.25 {
            return "Je bent begonnen. Houd alleen dit ene blok vast."
        } else if fraction < 0.70 {
            return "Je zit in je blok."
        } else if fraction < 1 {
            return "Je hebt al een flink stuk aandacht gegeven."
        } else {
            return "Dit focusblok staat."
        }
    }

    private func projectPickerLabel(_ project: WorkProject) -> String {
        "\(store.clientName(for: project.clientID)) — \(project.name)"
    }

    private func projectLabel(_ projectID: UUID?) -> String {
        guard let projectID,
              let project = store.projects.first(where: { $0.id == projectID }) else {
            return "Algemeen / intern"
        }
        return projectPickerLabel(project)
    }
}
