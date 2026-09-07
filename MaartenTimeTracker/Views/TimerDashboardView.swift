import SwiftUI

struct TimerDashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedProjectID: UUID?
    @State private var task = "Montage"

    private var availableProjects: [WorkProject] { store.projects.filter { !$0.isArchived } }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tijdregistratie").font(.largeTitle.bold())
                    Text("Snel starten, stoppen en weer door.").foregroundStyle(.secondary)
                }
                Spacer()
                FinalCutStatusPill()
            }
            if let timer = store.runningTimer, let project = store.activeProject {
                RunningCard(timer: timer, project: project)
            } else {
                StartCard(selectedProjectID: $selectedProjectID, task: $task)
            }
            if !store.pendingFinalCutLabel.isEmpty { PendingFinalCutCard(label: store.pendingFinalCutLabel) }
            Spacer()
        }
        .padding(28)
        .onAppear { if selectedProjectID == nil { selectedProjectID = availableProjects.first?.id } }
        .onChange(of: selectedProjectID) { _, newValue in
            if let id = newValue, let project = store.projects.first(where: { $0.id == id }) { task = project.defaultTask }
        }
    }
}

private struct RunningCard: View {
    @EnvironmentObject var store: AppStore
    let timer: RunningTimer
    let project: WorkProject
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.clientName(for: project)).font(.headline).foregroundStyle(.secondary)
            Text(project.name).font(.title2.bold())
            Text(timer.task).font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formatDuration(context.date.timeIntervalSince(timer.startedAt)))
                    .font(.system(size: 52, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            Button(role: .destructive) { store.stopTimer() } label: {
                Label("Stop timer", systemImage: "stop.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(24)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct StartCard: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedProjectID: UUID?
    @Binding var task: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Project", selection: $selectedProjectID) {
                Text("Kies project").tag(UUID?.none)
                ForEach(store.projects.filter { !$0.isArchived }) { project in
                    Text("\(store.clientName(for: project)) — \(project.name)").tag(Optional(project.id))
                }
            }
            TextField("Taak, bv. Montage", text: $task)
            Button {
                guard let id = selectedProjectID else { return }
                store.startTimer(projectID: id, task: task)
            } label: {
                Label("Start timer", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).disabled(selectedProjectID == nil)
        }
        .padding(24)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PendingFinalCutCard: View {
    @EnvironmentObject var store: AppStore
    let label: String
    @State private var projectID: UUID?
    @State private var task = "Montage"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nieuw uit Final Cut", systemImage: "sparkles").font(.headline)
            Text(label).font(.title3.bold())
            Text("Koppel dit één keer aan een project. Daarna herkent de app het automatisch.").foregroundStyle(.secondary)
            HStack {
                Picker("Project", selection: $projectID) {
                    Text("Kies project").tag(UUID?.none)
                    ForEach(store.projects.filter { !$0.isArchived }) { project in
                        Text("\(store.clientName(for: project)) — \(project.name)").tag(Optional(project.id))
                    }
                }
                TextField("Taak", text: $task).frame(width: 150)
                Button("Koppel") {
                    guard let projectID else { return }
                    store.addMapping(label: label, projectID: projectID, task: task)
                }.disabled(projectID == nil)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct FinalCutStatusPill: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        HStack(spacing: 7) {
            Circle().frame(width: 8, height: 8)
            Text(store.finalCutMonitor.isFinalCutFrontmost ? "Final Cut actief" : "Final Cut niet actief")
        }
        .foregroundStyle(store.finalCutMonitor.isFinalCutFrontmost ? .primary : .secondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}

func formatDuration(_ duration: TimeInterval) -> String {
    let total = max(0, Int(duration))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
