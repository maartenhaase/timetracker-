import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let timer = store.runningTimer, let project = store.activeProject {
                Text(store.clientName(for: project)).font(.caption).foregroundStyle(.secondary)
                Text(project.name).font(.headline)
                Text(timer.task)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatDuration(context.date.timeIntervalSince(timer.startedAt)))
                        .font(.title2.monospacedDigit())
                }
                Button("Stop") { store.stopTimer() }.buttonStyle(.borderedProminent)
            } else {
                Text("Geen timer actief").foregroundStyle(.secondary)
                ForEach(store.projects.filter { !$0.isArchived }.prefix(8)) { project in
                    Button("▶︎ \(store.clientName(for: project)) — \(project.name)") {
                        store.startTimer(projectID: project.id, task: project.defaultTask)
                    }
                }
            }
            Divider()
            FinalCutStatusPill()
        }
        .padding(14)
        .frame(width: 320)
    }
}
