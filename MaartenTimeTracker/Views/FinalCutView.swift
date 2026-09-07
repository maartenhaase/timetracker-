import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore

    @State private var doneText = ""
    @State private var maybeText = ""
    @State private var plannedMinutes: Int? = nil
    @State private var capacityHours: Int? = nil

    private let durationChoices: [(String, Int?)] = [
        ("Geen schatting", nil),
        ("Klein stukje", 15),
        ("Eén blok", 30),
        ("Ruimer blok", 60),
        ("Groot stuk", 90)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                winsCard
                justDidCard
                calendarCard
                gentlePlanCard
                tomorrowCard
            }
            .padding(28)
        }
        .onAppear {
            store.calendarService.refresh()
            capacityHours = store.dayCapacity(for: Date()).map { $0 / 60 }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Vandaag")
                .font(.largeTitle.bold())
            Text("Geen scorebord. Alleen zichtbaar maken wat er wél gebeurt.")
                .foregroundStyle(.secondary)

            Text(store.todayFocusMessage)
                .font(.headline)
                .padding(.top, 6)
        }
    }

    private var winsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dit heb je vandaag gedaan", systemImage: "checkmark.circle.fill")
                    .font(.title3.bold())
                Spacer()
                if store.completedTodayItems.isEmpty && store.completedFocusToday.isEmpty {
                    Text("de dag is nog open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.completedTodayItems.isEmpty && store.completedFocusToday.isEmpty {
                Text("Nog niets geregistreerd. Dat betekent niet dat je niets hebt gedaan — je kunt hieronder ook achteraf iets toevoegen.")
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(store.completedTodayItems.reversed())) { item in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(item.title)
                    Spacer()
                    Button("Heropen") {
                        store.reopenDayItem(item)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            if !store.completedFocusToday.isEmpty {
                Divider()
                ForEach(store.completedFocusToday.prefix(6)) { session in
                    HStack {
                        Image(systemName: "scope")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.task.isEmpty ? "Focusblok" : session.task)
                            Text("Goed gefocust — afronden was niet nodig om dit te laten tellen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .softCard()
    }

    private var justDidCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Wat heb je net gedaan?", systemImage: "sparkles")
                .font(.headline)
            Text("Ook werk dat niet op een lijst stond mag meetellen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Bijv. klant gebeld, selectie gemaakt, administratie gedaan…", text: $doneText)
                    .onSubmit(recordDone)
                Button("Tel mee") {
                    recordDone()
                }
                .buttonStyle(.borderedProminent)
                .disabled(doneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let reward = store.lastRewardMessage {
                Label(reward, systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .softCard()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Je dag zoals hij echt is", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                if store.calendarService.canReadCalendar {
                    Button("Ververs") {
                        store.calendarService.refresh()
                    }
                    .buttonStyle(.borderless)
                }
            }

            if !store.calendarService.canReadCalendar {
                Text("Je kunt Apple Agenda alleen-lezen koppelen. Afspraken worden context, geen extra to-do's.")
                    .foregroundStyle(.secondary)
                Button("Geef toegang tot Agenda") {
                    store.calendarService.requestAccess()
                }
            } else if store.calendarService.todayEvents.isEmpty {
                Text("Geen afspraken gevonden voor vandaag.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.calendarService.todayEvents.prefix(10)) { event in
                    HStack(alignment: .top) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                            Text(calendarTimeText(event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .softCard()
    }

    private var gentlePlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wat zou fijn zijn als het vandaag lukt?")
                .font(.title3.bold())
            Text("Dit zijn mogelijkheden, geen schuldcontracten. Alles mag morgen opnieuw gekozen worden.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Ruimte vandaag", selection: $capacityHours) {
                Text("Geen urenlimiet invullen").tag(Int?.none)
                ForEach(1...8, id: \.self) { hour in
                    Text("\(hour) uur ruimte").tag(Optional(hour))
                }
            }
            .onChange(of: capacityHours) { _, value in
                store.setDayCapacity(hours: value)
            }

            HStack {
                TextField("Iets wat je mogelijk wilt doen…", text: $maybeText)
                    .onSubmit(addMaybe)

                Picker("Omvang", selection: $plannedMinutes) {
                    ForEach(durationChoices, id: \.0) { choice in
                        Text(choice.0).tag(choice.1)
                    }
                }
                .frame(width: 155)

                Button("Zet erbij") {
                    addMaybe()
                }
                .disabled(maybeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if store.openTodayItems.isEmpty {
                Text("Geen open mogelijkheden. Je hoeft hier niets bij te zetten om een goede dag te hebben.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.openTodayItems) { item in
                    HStack(spacing: 10) {
                        Button {
                            store.completeDayItem(item)
                        } label: {
                            Image(systemName: "circle")
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            if let planned = item.plannedMinutes {
                                Text(softDuration(planned))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Morgen") {
                            store.moveDayItemToTomorrow(item)
                        }
                        .buttonStyle(.borderless)

                        Button(role: .destructive) {
                            store.deleteDayItem(item)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .softCard()
    }

    private var tomorrowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Voor morgen", systemImage: "arrow.right.circle")
                .font(.title3.bold())
            Text("Alleen dingen die jij bewust hebt doorgeschoven staan hier. Geen automatische stapel.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.tomorrowItems.isEmpty {
                Text("Nog niets meegenomen. Morgen mag opnieuw beginnen.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.tomorrowItems) { item in
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                        Text(item.title)
                        Spacer()
                    }
                }
            }

            if store.calendarService.canReadCalendar && !store.calendarService.tomorrowEvents.isEmpty {
                Divider()
                Text("Morgen staat al in je agenda:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(store.calendarService.tomorrowEvents.prefix(6)) { event in
                    Text("• \(event.title)")
                        .font(.caption)
                }
            }
        }
        .softCard()
    }

    private func recordDone() {
        store.recordDoneItem(title: doneText)
        doneText = ""
    }

    private func addMaybe() {
        store.addDayItem(title: maybeText, plannedMinutes: plannedMinutes)
        maybeText = ""
        plannedMinutes = nil
    }

    private func calendarTimeText(_ event: CalendarEventItem) -> String {
        if event.isAllDay {
            return "hele dag · \(event.calendarTitle)"
        }
        return "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened)) · \(event.calendarTitle)"
    }

    private func softDuration(_ minutes: Int) -> String {
        switch minutes {
        case ..<20: return "klein stukje"
        case ..<45: return "ongeveer één blok"
        case ..<75: return "ruimer blok"
        default: return "groter stuk"
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appgebruik")
                        .font(.largeTitle.bold())
                    Text("Automatisch bijgehouden zolang je echt met muis of toetsenbord bezig bent.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Automatisch bijhouden", isOn: $store.automaticAppTrackingEnabled)
                    .toggleStyle(.switch)
            }

            HStack(spacing: 14) {
                statCard(
                    title: "Nu actief",
                    value: store.activityMonitor.currentAppName,
                    icon: "cursorarrow.motionlines"
                )
                statCard(
                    title: "Status",
                    value: store.activityMonitor.isUserActive ? "Actief" : "Even weg",
                    icon: store.activityMonitor.isUserActive ? "bolt.fill" : "cup.and.saucer"
                )
                statCard(
                    title: "Vandaag gemeten",
                    value: compactDuration(store.todayTrackedAppTime),
                    icon: "clock"
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Vandaag per programma")
                        .font(.title3.bold())
                    Spacer()
                    Text("Na 2 minuten zonder invoer telt de tijd niet verder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let summary = store.appSummary()
                if summary.isEmpty {
                    ContentUnavailableView(
                        "Nog geen appgebruik",
                        systemImage: "macwindow",
                        description: Text("Gebruik je Mac even; Safari, Final Cut, Mail en andere programma's verschijnen hier vanzelf.")
                    )
                } else {
                    List {
                        ForEach(Array(summary.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Image(systemName: "app")
                                    .foregroundStyle(.secondary)
                                Text(row.name)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(compactDuration(row.duration))
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(28)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct FocusView: View {
    @EnvironmentObject var store: AppStore

    @State private var selectedProjectID: UUID?
    @State private var task = ""
    @State private var focusMinutes = 25
    @State private var noteText = ""

    private let focusOptions = [15, 25, 45, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus")
                        .font(.largeTitle.bold())
                    Text("Eén ding tegelijk. Klein beginnen is prima.")
                        .foregroundStyle(.secondary)
                }

                if let focus = store.activeFocus {
                    activeFocusCard(focus)
                } else {
                    startFocusCard
                }

                if store.focusJustCompleted {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Blok afgerond", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Text("Niet meteen het volgende grote ding induiken. Pak kort afstand.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("5 min pauze") {
                                store.startBreak(minutes: 5)
                                store.focusJustCompleted = false
                            }
                            .buttonStyle(.borderedProminent)

                            Button("10 min pauze") {
                                store.startBreak(minutes: 10)
                                store.focusJustCompleted = false
                            }

                            Button("Geen pauze") {
                                store.focusJustCompleted = false
                            }
                        }
                    }
                    .focusCard()
                }

                parkingLot
            }
            .padding(28)
        }
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = store.projects.first(where: { !$0.isArchived })?.id
            }
            if task.isEmpty,
               let id = selectedProjectID,
               let project = store.projects.first(where: { $0.id == id }) {
                task = project.defaultTask
            }
        }
        .onChange(of: selectedProjectID) { _, newID in
            guard let id = newID,
                  let project = store.projects.first(where: { $0.id == id }) else { return }
            task = project.defaultTask
        }
    }

    private var startFocusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Waar ga je nu alleen aan werken?", systemImage: "scope")
                .font(.title3.bold())

            Picker("Project", selection: $selectedProjectID) {
                Text("Geen project / alleen focus").tag(UUID?.none)
                ForEach(store.projects.filter { !$0.isArchived }) { project in
                    Text("\(store.clientName(for: project)) — \(project.name)")
                        .tag(Optional(project.id))
                }
            }

            TextField("Eén concrete taak, bv. eerste montage maken", text: $task)

            HStack(spacing: 8) {
                ForEach(focusOptions, id: \.self) { minutes in
                    Button("\(minutes) min") {
                        focusMinutes = minutes
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .overlay {
                        if focusMinutes == minutes {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(.primary, lineWidth: 2)
                        }
                    }
                }
            }

            Button {
                store.startFocus(
                    minutes: focusMinutes,
                    projectID: selectedProjectID,
                    task: task.isEmpty ? "Focus" : task
                )
            } label: {
                Label("Start focusblok", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(selectedProjectID == nil
                 ? "Er wordt geen projecttijd gestart."
                 : "Als er nog geen projecttimer loopt, start die automatisch mee en stopt hij na het focusblok.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .focusCard()
    }

    private func activeFocusCard(_ focus: ActiveFocus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    focus.phase == .focus ? "Focusblok" : "Pauze",
                    systemImage: focus.phase == .focus ? "scope" : "cup.and.saucer.fill"
                )
                .font(.headline)
                Spacer()
                Text("\(focus.plannedMinutes) min")
                    .foregroundStyle(.secondary)
            }

            if focus.phase == .focus {
                Text(focus.task)
                    .font(.title2.bold())

                if let id = focus.projectID,
                   let project = store.projects.first(where: { $0.id == id }) {
                    Text("\(store.clientName(for: project)) — \(project.name)")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Even los van het scherm of doe iets kleins.")
                    .font(.title3.bold())
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, focus.endsAt.timeIntervalSince(context.date))
                Text(focusCountdown(remaining))
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Button(role: .destructive) {
                store.stopFocus()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        }
        .focusCard()
    }

    private var parkingLot: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gedachten-parkeerplaats")
                        .font(.title3.bold())
                    Text("Iets schiet je te binnen? Zet het hier neer in plaats van meteen van taak te wisselen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                TextField("Bijv. mail Jeroen nog beantwoorden…", text: $noteText)
                    .onSubmit(addNote)
                Button("Parkeer", action: addNote)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(store.parkingNotes.filter { !$0.isDone }.prefix(12)) { note in
                HStack {
                    Button {
                        store.toggleParkingNote(note)
                    } label: {
                        Image(systemName: "circle")
                    }
                    .buttonStyle(.plain)

                    Text(note.text)
                    Spacer()

                    Button(role: .destructive) {
                        store.deleteParkingNote(note)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .focusCard()
    }

    private func addNote() {
        store.addParkingNote(noteText)
        noteText = ""
    }
}

private extension View {
    func focusCard() -> some View {
        self
            .padding(18)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }
}

func compactDuration(_ duration: TimeInterval) -> String {
    let totalMinutes = max(0, Int(duration) / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
        return "\(hours)u \(minutes)m"
    }
    return "\(minutes)m"
}

func focusCountdown(_ duration: TimeInterval) -> String {
    let total = max(0, Int(duration))
    return String(format: "%02d:%02d", total / 60, total % 60)
}


private extension View {
    func softCard() -> some View {
        self
            .padding(18)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 16))
    }
}
