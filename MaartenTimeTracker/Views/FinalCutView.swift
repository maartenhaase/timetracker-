import SwiftUI

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
