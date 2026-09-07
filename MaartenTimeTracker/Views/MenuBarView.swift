import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(store.activityMonitor.currentAppName, systemImage: "macwindow")
                    .lineLimit(1)
                Spacer()
                if !store.activityMonitor.isUserActive {
                    Text("even weg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let focus = store.activeFocus {
                Divider()
                HStack {
                    Label(
                        focus.phase == .focus ? focus.task : "Pauze",
                        systemImage: focus.phase == .focus ? "scope" : "cup.and.saucer"
                    )
                    .lineLimit(1)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(focusCountdown(max(0, focus.endsAt.timeIntervalSince(context.date))))
                            .monospacedDigit()
                    }
                }
            }

            Divider()

            if let timer = store.runningTimer,
               let project = store.activeProject {
                Text(store.clientName(for: project))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.name)
                    .font(.headline)
                Text(timer.task)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatDuration(context.date.timeIntervalSince(timer.startedAt)))
                        .font(.title2.monospacedDigit())
                }

                Button("Stop timer") {
                    store.stopTimer()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Geen projecttimer actief")
                    .foregroundStyle(.secondary)

                ForEach(store.projects.filter { !$0.isArchived }.prefix(6)) { project in
                    Button("▶︎ \(store.clientName(for: project)) — \(project.name)") {
                        store.startTimer(projectID: project.id, task: project.defaultTask)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 330)
    }
}
