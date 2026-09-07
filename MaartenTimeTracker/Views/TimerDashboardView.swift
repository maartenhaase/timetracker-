import Foundation
import SwiftUI

struct TodayWorkView: View {
    @EnvironmentObject var store: AppStore

    @State private var planProjectID: UUID?
    @State private var planTitle = ""
    @State private var planMinutes = 30

    @State private var doneProjectID: UUID?
    @State private var doneTitle = ""
    @State private var doneMinutes = 30

    @State private var isRecovery = false

    private let durations = [15, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vandaag")
                        .font(.largeTitle.bold())
                    Text("Plan in blokken. Wat je al gedaan hebt mag net zo goed meetellen.")
                        .foregroundStyle(.secondary)
                }

                if let block = store.activeBlock {
                    activeCard(block)
                } else {
                    plannedTasksCard
                    addPlanCard
                    alreadyDoneCard
                    doneTodayCard
                }

                if let message = store.lastRewardMessage {
                    Label(message, systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(28)
        }
    }

    private var plannedTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wat wil je vandaag doen?", systemImage: "list.bullet")
                    .font(.title3.bold())
                Spacer()
                if !store.openTodayTasks.isEmpty {
                    Text("\(store.openTodayTasks.count) open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.openTodayTasks.isEmpty {
                Text("Nog niets gepland. Voeg alleen toe wat vandaag realistisch voelt.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.openTodayTasks) { task in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.headline)
                            HStack(spacing: 6) {
                                Text(projectLabel(task.projectID))
                                Text("•")
                                Text(durationText(task.plannedMinutes))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            store.startDailyTask(task, isRecovery: false)
                        } label: {
                            Label("BEGIN", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(role: .destructive) {
                            store.deleteDailyTask(task)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)

                    if task.id != store.openTodayTasks.last?.id {
                        Divider()
                    }
                }
            }
        }
        .softCard()
    }

    private var addPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voeg een blok toe")
                .font(.headline)

            Picker("Project", selection: $planProjectID) {
                Text("Algemeen / intern").tag(UUID?.none)
                ForEach(store.projects) { project in
                    Text(projectPickerLabel(project))
                        .tag(Optional(project.id))
                }
            }

            TextField("Wat wil je doen?", text: $planTitle)

            durationPicker(selection: $planMinutes)

            Button {
                store.addDailyTask(
                    projectID: planProjectID,
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
            .disabled(planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .softCard()
    }

    private var alreadyDoneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Wat heb je al gedaan?", systemImage: "sparkles")
                .font(.headline)

            Text("Ook iets dat nooit op je lijst stond mag achteraf gewoon meetellen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Project", selection: $doneProjectID) {
                Text("Algemeen / intern").tag(UUID?.none)
                ForEach(store.projects) { project in
                    Text(projectPickerLabel(project))
                        .tag(Optional(project.id))
                }
            }

            TextField("Wat heb je gedaan?", text: $doneTitle)

            durationPicker(selection: $doneMinutes)

            Button {
                store.recordDoneToday(
                    projectID: doneProjectID,
                    title: doneTitle,
                    plannedMinutes: doneMinutes
                )
                doneTitle = ""
                doneMinutes = 30
            } label: {
                Label("Tel mee", systemImage: "checkmark")
            }
            .disabled(doneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .softCard()
    }

    private var doneTodayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Vandaag gedaan", systemImage: "checkmark.circle.fill")
                .font(.title3.bold())

            if store.doneTodayTasks.isEmpty {
                Text("Nog niets geregistreerd. Dat zegt niets over hoe je dag loopt.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.doneTodayTasks.reversed()) { task in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                            Text("\(projectLabel(task.projectID)) • \(durationText(task.plannedMinutes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .softCard()
    }

    @ViewBuilder
    private func activeCard(_ block: ActiveWorkBlock) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let focused = focusedSeconds(block, at: context.date)
            let target = TimeInterval((block.plannedMinutes ?? 30) * 60)
            let progress = min(1, focused / max(1, target))

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    if let project = store.activeProject {
                        Text(projectPickerLabel(project))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else if let client = store.activeClient {
                        Text(client.name)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Algemeen / intern")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(block.task)
                        .font(.title.bold())

                    if let planned = block.plannedMinutes {
                        Text("Gepland blok: \(durationText(planned))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.isDistracted {
                    Label("Afleiding loopt nu apart.", systemImage: "pause.circle.fill")
                        .font(.headline)

                    Button {
                        store.endDistraction()
                    } label: {
                        Label("TERUG NAAR TAAK", systemImage: "arrow.uturn.backward")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Text("Deze tijd telt niet mee als focustijd en gaat naar je inhaalpotje.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress)

                        Text(blockStatus(focused, target: target))
                            .font(.headline)

                        if focused >= target {
                            Text("Je geplande blok staat. Alleen doorgaan als dat nu nog logisch is.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("De balk is richting, geen verplichting.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            store.finishBlock(done: true)
                        } label: {
                            Label("KLAAR", systemImage: "checkmark")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            store.startDistraction()
                        } label: {
                            Label("AFGELEID", systemImage: "exclamationmark")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    Button("Stop blok, taak blijft open") {
                        store.finishBlock(done: false)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                if store.recoveryBalanceSeconds > 30 && !block.isRecovery {
                    Toggle("Dit blok ook als inhalen tellen", isOn: $isRecovery)
                        .disabled(true)
                        .hidden()
                }

                if block.isRecovery {
                    Label("Dit blok telt ook als inhaaltijd.", systemImage: "arrow.counterclockwise.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
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

    private func projectPickerLabel(_ project: WorkProject) -> String {
        let client = store.clients.first(where: { $0.id == project.clientID })?.name ?? "Onbekend"
        return "\(client) — \(project.name)"
    }

    private func projectLabel(_ projectID: UUID?) -> String {
        guard let projectID,
              let project = store.projects.first(where: { $0.id == projectID }) else {
            return "Algemeen"
        }
        return projectPickerLabel(project)
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
            return "Je bent begonnen. Houd alleen dit ene ding vast."
        } else if fraction < 0.65 {
            return "Je zit goed in je blok."
        } else if fraction < 1 {
            return "Je bent een flink stuk op weg."
        } else {
            return "Je geplande blok is neergezet."
        }
    }

    private func durationText(_ minutes: Int) -> String {
        switch minutes {
        case 15: return "15 min"
        case 30: return "30 min"
        case 45: return "45 min"
        case 60: return "1 uur"
        case 90: return "1,5 uur"
        default: return "\(minutes) min"
        }
    }
}

private extension View {
    func softCard() -> some View {
        self
            .padding(18)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 16))
    }
}
