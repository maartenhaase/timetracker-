import Foundation
import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore

    @State private var quickText = ""
    @State private var planProjectID: UUID?
    @State private var planCategory = "Werk"
    @State private var planTitle = ""
    @State private var planMinutes = 30
    @State private var planKind: DailyTaskKind = .normal

    @State private var doneProjectID: UUID?
    @State private var doneCategory = "Werk"
    @State private var doneTitle = ""
    @State private var doneMinutes = 30

    @State private var showParkSheet = false
    @State private var resumeNote = ""
    @State private var showAddBlock = false
    @State private var showDone = false
    @State private var showBalance = false

    private let durations = [15,30,45,60,90,120]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let block = store.activeBlock {
                    activeBlockCard(block)
                } else if store.isTodayClosed {
                    closedCard
                    doneTodayCard
                    balanceCard
                } else {
                    if !store.parkedItems.isEmpty { parkedCard }
                    dayStartCard
                    suggestionsCard
                    addNormalBlockCard
                    alreadyDoneCard
                    doneTodayCard
                    balanceCard
                    if store.recoverySuggestionMinutes > 0 { recoveryCard }
                    closeDayCard
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
        .sheet(isPresented: $showParkSheet) { parkingSheet }
        .onAppear {
            if let first = store.projects.first(where: { !$0.isArchived }) {
                if planProjectID == nil { planProjectID = first.id; planCategory = first.taskNames.first ?? "Werk" }
            }
        }
        .onChange(of: planProjectID) { _, value in
            let names = store.taskNames(for: value)
            if !names.contains(planCategory) { planCategory = names.first ?? "Werk" }
        }
        .onChange(of: doneProjectID) { _, value in
            let names = store.taskNames(for: value)
            if !names.contains(doneCategory) { doneCategory = names.first ?? "Werk" }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Vandaag").font(.largeTitle.bold())
            Text(store.isTodayClosed ? "Je werkdag is gesloten. De rest hoeft nu niet in je hoofd." : store.focusMessage)
                .foregroundStyle(.secondary)
        }
    }

    private var dayStartCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Dagstart", systemImage: "sparkles")
                .font(.title2.bold())

            // QUICK
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("1. Snelle dingen", systemImage: "bolt.fill")
                        .font(.headline)
                    Spacer()
                    Text("≤5 min per ding · bundel max ±20 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Even appen, mailtje, iets bestellen…", text: $quickText)
                        .onSubmit(addQuick)
                    Button(action: addQuick) {
                        Image(systemName: "plus")
                    }
                    .disabled(quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if store.quickTasksToday.isEmpty {
                    Text("Geen snelle dingen open. Prima.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.quickTasksToday) { task in
                        HStack {
                            Button {
                                store.completeQuickTask(task)
                            } label: {
                                Image(systemName: "circle")
                            }
                            .buttonStyle(.plain)
                            Text(task.title)
                            Spacer()
                            if task.projectID != nil {
                                Text(store.projectName(for: task.projectID))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        store.startQuickBundle()
                    } label: {
                        Label("START SNELLE BUNDEL · \(durationText(store.quickBundleMinutes))", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            // DEADLINE
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("2. Hoofdtaak van vandaag", systemImage: "scope")
                        .font(.headline)
                    Spacer()
                    Text("één belangrijke taak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let task = store.deadlineTaskToday {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title).font(.title3.bold())
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
                    }
                    Text("Deze krijgt vandaag extra ruimte, maar Flow blijft je ook herinneren aan pauze en fasebudget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let suggestion = store.suggestedCRMProjects.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Flow stelt voor:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\(store.clientName(for: suggestion.clientID)) — \(suggestion.name)")
                            .font(.headline)
                        Text("Volgende stap: \(store.nextCRMStage(for: suggestion))")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Maak dit hoofdtaak") {
                                store.planSuggestedDeadline(suggestion)
                            }
                            .buttonStyle(.borderedProminent)

                            if let normal = store.normalTasksToday.first {
                                Button("Kies '\(normal.title)'") {
                                    store.makeDeadlineTask(normal)
                                }
                            }
                        }
                    }
                } else {
                    Text("Nog geen hoofdtaak gekozen. Dat hoeft pas als er echt iets belangrijkers bovenuit steekt.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // COMPANY
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("3. Aan mijn bedrijf werken", systemImage: "building.2")
                        .font(.headline)
                    Spacer()
                    Text("beschermde ruimte · meestal 30 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let task = store.companyTasksToday.first {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title).font(.headline)
                            Text(durationText(task.plannedMinutes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("BEGIN") { store.startDailyTask(task) }
                            .buttonStyle(.borderedProminent)
                    }
                } else if let item = store.suggestedCompanyItem {
                    Text("Klantwerk krijgt snel alle ruimte. Zullen we ook \(durationText(item.defaultMinutes)) voor je eigen bedrijf beschermen?")
                        .foregroundStyle(.secondary)
                    Text("\(item.title) — \(item.nextStep)")
                        .font(.headline)
                    Button("Zet dit op vandaag") { store.planCompanyItem(item) }
                        .buttonStyle(.bordered)
                }
            }

            if !store.normalTasksToday.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Daarna: normale blokken", systemImage: "rectangle.stack")
                        .font(.headline)

                    ForEach(store.normalTasksToday) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                Text("\(projectLabel(task.projectID)) · \(durationText(task.plannedMinutes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("BEGIN") { store.startDailyTask(task) }
                                .buttonStyle(.bordered)
                            Button {
                                store.makeDeadlineTask(task)
                            } label: {
                                Image(systemName: "scope")
                            }
                            .buttonStyle(.borderless)
                            .help("Maak hoofdtaak")
                        }
                    }
                }
            }
        }
        .flowCard()
    }

    private var suggestionsCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("Flow kijkt naar deadlines, geparkeerd werk en de volgende CRM-stap. Jij beslist wat vandaag mag.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(store.suggestedCRMProjects.prefix(4)) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.clientName(for: project.clientID)) — \(project.name)")
                                .font(.headline)
                            Text("Zou je niet eens: \(store.nextCRMStage(for: project))?")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Zet op vandaag") {
                            store.planNextCRMStage(project)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Flow-suggesties", systemImage: "lightbulb")
                .font(.headline)
        }
        .flowCard()
    }

    private var addNormalBlockCard: some View {
        DisclosureGroup(isExpanded: $showAddBlock) {
            VStack(alignment: .leading, spacing: 12) {
                projectPicker(selection: $planProjectID)
                categoryPicker(projectID: planProjectID, selection: $planCategory)
                TextField("Concrete taak (optioneel)", text: $planTitle)

                Picker("Soort", selection: $planKind) {
                    Text("Normaal blok").tag(DailyTaskKind.normal)
                    Text("Hoofdtaak").tag(DailyTaskKind.deadline)
                    Text("Snelle taak").tag(DailyTaskKind.quick)
                }
                .pickerStyle(.segmented)

                if planKind == .quick {
                    Text("Snelle taken worden automatisch als 5 minuten behandeld en in de ochtendbundel gezet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    durationPicker(selection: $planMinutes)
                }

                Button {
                    _ = store.addDailyTask(
                        projectID: planProjectID,
                        category: planCategory,
                        title: planTitle,
                        plannedMinutes: planKind == .quick ? 5 : planMinutes,
                        kind: planKind
                    )
                    planTitle = ""
                    planKind = .normal
                    planMinutes = 30
                } label: {
                    Label("Zet op vandaag", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        } label: {
            Label("Zelf een werkblok toevoegen", systemImage: "plus.circle")
                .font(.headline)
        }
        .flowCard()
    }

    private var alreadyDoneCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ook werk dat nooit op je lijst stond mag meetellen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                projectPicker(selection: $doneProjectID)
                categoryPicker(projectID: doneProjectID, selection: $doneCategory)
                TextField("Wat heb je gedaan?", text: $doneTitle)
                durationPicker(selection: $doneMinutes)
                Button("Tel mee") {
                    store.recordDoneToday(projectID: doneProjectID, category: doneCategory, title: doneTitle, minutes: doneMinutes)
                    doneTitle = ""; doneMinutes = 30
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

    private var parkedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Veilig geparkeerd", systemImage: "pause.circle.fill")
                .font(.title3.bold())
            Text("De eerstvolgende stap staat hier, zodat je hem niet zelf hoeft vast te houden.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(store.parkedItems) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.task).font(.headline)
                        Text(item.resumeNote)
                        Text(projectLabel(item.projectID))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("HERVAT") { store.resumeParked(item) }
                        .buttonStyle(.borderedProminent)
                    Button("Laat los") { store.removeParked(item) }
                        .buttonStyle(.borderless)
                }
                if item.id != store.parkedItems.last?.id { Divider() }
            }
        }
        .flowCard()
    }

    private var doneTodayCard: some View {
        DisclosureGroup(isExpanded: $showDone) {
            VStack(alignment: .leading, spacing: 7) {
                if store.doneTodayTasks.isEmpty {
                    Text("Nog niets geregistreerd. Dat zegt niets over hoe je dag loopt.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.doneTodayTasks.prefix(12)) { task in
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark.circle.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                Text("\(projectLabel(task.projectID)) · \(task.category)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Dit heb je vandaag gedaan (\(store.doneTodayTasks.count))", systemImage: "checkmark.circle.fill")
                .font(.headline)
        }
        .flowCard()
    }

    private var balanceCard: some View {
        DisclosureGroup(isExpanded: $showBalance) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Geen uren en geen score. Eén klein anker buiten werk is genoeg.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                balanceRow(.together)
                balanceRow(.family)
                balanceRow(.selfCare)
            }
            .padding(.top, 8)
        } label: {
            Label("Buiten werk: Samen · Gezin · Zelf", systemImage: "heart")
                .font(.headline)
        }
        .flowCard()
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Herstelruimte", systemImage: "arrow.counterclockwise.circle")
                .font(.headline)
            Text("Als het helpt om rustig af te sluiten: één herstelblok van ongeveer \(durationText(store.recoverySuggestionMinutes)) is genoeg.")
                .foregroundStyle(.secondary)
            Text("Niet verplicht. Het wordt morgen niet als schuld meegenomen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .flowCard()
    }

    private var closeDayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Werkdag afronden", systemImage: "door.left.hand.closed")
                .font(.title3.bold())

            if !store.openTodayTasks.isEmpty {
                Text("Open werk gaat niet automatisch mee naar morgen. Neem alleen bewust iets mee.")
                    .foregroundStyle(.secondary)
                ForEach(store.openTodayTasks.prefix(8)) { task in
                    HStack {
                        Text(task.title)
                        Spacer()
                        Button("Morgen") { store.moveTaskToTomorrow(task) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
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

    private var closedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Werkdag gesloten", systemImage: "checkmark.seal.fill")
                .font(.title2.bold())
            Text("De open blokken hoeven nu niet door je hoofd te blijven lopen.")
                .foregroundStyle(.secondary)
            Button("Toch weer openen") { store.reopenWorkday() }
                .buttonStyle(.borderless)
        }
        .flowCard()
    }

    @ViewBuilder
    private func activeBlockCard(_ block: ActiveWorkBlock) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let focused = focusedSeconds(block, at: context.date)
            let target = TimeInterval(max(5, block.plannedMinutes) * 60)
            let progress = min(1, focused / max(1, target))

            VStack(alignment: .leading, spacing: 16) {
                Text(projectLabel(block.projectID))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(block.category.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(block.task)
                    .font(.title.bold())

                if block.category == "Snelle dingen" && !store.isDistracted {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Werk alleen dit korte bakje af; daarna naar je hoofdtaak.")
                            .foregroundStyle(.secondary)
                        ForEach(store.quickTasksToday) { task in
                            HStack {
                                Button { store.completeQuickTask(task) } label: {
                                    Image(systemName: "circle")
                                }
                                .buttonStyle(.plain)
                                Text(task.title)
                                Spacer()
                            }
                        }
                    }
                }

                if store.isDistracted {
                    Label("AFGELEID", systemImage: "exclamationmark.circle.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                    Text("De focustijd staat stil. Merken en terugkeren is hier de winst.")
                        .foregroundStyle(.secondary)
                    Button {
                        store.endDistraction()
                    } label: {
                        Label("IK BEN TERUG", systemImage: "arrow.uturn.backward")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    ProgressView(value: progress)
                    Text(blockStatus(focused, target: target))
                        .font(.headline)

                    if let warning = liveWarning(block: block, focused: focused) {
                        Label(warning, systemImage: "gauge.with.dots.needle.67percent")
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                    }

                    HStack(spacing: 9) {
                        Button {
                            store.finishActiveBlock(done: true)
                        } label: {
                            Label("KLAAR", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            resumeNote = ""
                            showParkSheet = true
                        } label: {
                            Label("PARKEREN", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button {
                            store.startDistraction()
                        } label: {
                            Label("AFGELEID", systemImage: "exclamationmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    Button("Stop blok; taak blijft open") { store.finishActiveBlock(done: false) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var parkingSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Blok veilig parkeren").font(.title2.bold())
            Text("Schrijf alleen de eerstvolgende stap op. Daarna mag je hoofd dit loslaten.")
                .foregroundStyle(.secondary)
            TextField("Bijv. verder bij 03:42 en logo vervangen", text: $resumeNote)
            HStack {
                Spacer()
                Button("Annuleer") { showParkSheet = false }
                Button("Parkeer veilig") {
                    store.parkActiveBlock(resumeNote: resumeNote)
                    showParkSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 470)
    }

    private func addQuick() {
        store.addQuickTask(title: quickText)
        quickText = ""
    }

    private func projectPicker(selection: Binding<UUID?>) -> some View {
        Picker("Project", selection: selection) {
            Text("Algemeen / intern").tag(UUID?.none)
            ForEach(store.projects.filter { !$0.isArchived }) { project in
                Text("\(store.clientName(for: project.clientID)) — \(project.name)")
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
        HStack(spacing: 7) {
            ForEach(durations, id: \.self) { minutes in
                Button(durationText(minutes)) { selection.wrappedValue = minutes }
                    .buttonStyle(.bordered)
                    .overlay {
                        if selection.wrappedValue == minutes {
                            RoundedRectangle(cornerRadius: 7).stroke(.primary, lineWidth: 2)
                        }
                    }
            }
        }
    }

    private func projectLabel(_ id: UUID?) -> String {
        guard let id, let project = store.projects.first(where: { $0.id == id }) else { return "Algemeen / intern" }
        return "\(store.clientName(for: project.clientID)) — \(project.name)"
    }

    private func balanceRow(_ kind: BalanceKind) -> some View {
        let day = store.balanceForToday()
        let done: Bool
        switch kind {
        case .together: done = day.togetherDone
        case .family: done = day.familyDone
        case .selfCare: done = day.selfDone
        }

        return HStack {
            Button { store.toggleBalance(kind: kind) } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            Label(kind.title, systemImage: kind.icon)
                .frame(width: 90, alignment: .leading)
            TextField(
                kind == .together ? "bijv. even samen koffie" :
                kind == .family ? "bijv. bewust samen eten / spelen" :
                "bijv. sporten, muziek of niets",
                text: Binding(
                    get: {
                        let current = store.balanceForToday()
                        switch kind {
                        case .together: return current.togetherText
                        case .family: return current.familyText
                        case .selfCare: return current.selfText
                        }
                    },
                    set: { store.updateBalanceText(kind: kind, text: $0) }
                )
            )
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
        let f = seconds / max(1, target)
        if f < 0.25 { return "Je bent begonnen. Houd alleen dit ene blok vast." }
        if f < 0.70 { return "Je zit in je blok." }
        if f < 1 { return "Je hebt al een flink stuk aandacht gegeven." }
        return "Je geplande blok staat. Doorgaan hoeft niet automatisch."
    }

    private func liveWarning(block: ActiveWorkBlock, focused: TimeInterval) -> String? {
        let sessionMinutes = Int(focused / 60)

        if let project = store.activeProject, project.kind == .wedding,
           let budget = store.weddingBudgetMinutes(category: block.category) {
            let completed = store.focusedMinutes(projectID: project.id, category: block.category)
            let live = completed + sessionMinutes
            if live >= budget {
                if block.category.lowercased().contains("ruwe") {
                    return "Ruwe montage zit rond het fasebudget. Dit hoeft nog niet mooi te zijn; ga liever door naar fijne montage."
                }
                if block.category.lowercased().contains("fijne") {
                    return "Fijne montage zit rond 8 uur. Tijd om richting eindmontage / afronden te gaan."
                }
                if block.category.lowercased().contains("eind") || block.category.lowercased().contains("afrond") {
                    return "Afrondbudget bereikt. Controleer en lever op; vermijd nu grote creatieve herbouw."
                }
                if block.category.lowercased().contains("aanpass") {
                    return "De standaard 1 uur aanpassingsruimte is bereikt. Check of extra tijd meerwerk is."
                }
            } else if live >= Int(Double(budget) * 0.75) {
                return "Je zit op ongeveer 75% van het fasebudget: \(durationText(live)) van \(durationText(budget))."
            }
        }

        if sessionMinutes >= 120 {
            return "Je zit al ongeveer 2 uur in dit blok. Parkeer even en kom los van je scherm."
        }
        if sessionMinutes >= 90 {
            return "Lang focusblok. Dit is een goed moment voor een echte korte pauze."
        }
        if sessionMinutes >= 60 {
            return "Je hebt ongeveer een uur aandacht gegeven. Even bewegen of drinken kan helpen voordat je doorgaat."
        }
        return nil
    }
}
