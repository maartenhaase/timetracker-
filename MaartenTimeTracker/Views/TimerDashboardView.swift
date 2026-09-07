import SwiftUI

struct TimerDashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedProjectID: UUID?
    @State private var task = "Montage"

    private var availableProjects: [WorkProject] {
        store.projects.filter { !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tijdregistratie")
                        .font(.largeTitle.bold())
                    Text("Exacte uren zijn hier voor administratie. Ze bepalen niet of je dag geslaagd is.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CurrentAppPill()
            }

            if let timer = store.runningTimer,
               let project = store.activeProject {
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.clientName(for: project))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(project.name)
                        .font(.title2.bold())
                    Text(timer.task)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(formatDuration(context.date.timeIntervalSince(timer.startedAt)))
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    Button(role: .destructive) {
                        store.stopTimer()
                    } label: {
                        Label("Stop projecttimer", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(22)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if availableProjects.isEmpty {
                        ContentUnavailableView(
                            "Nog geen project",
                            systemImage: "folder.badge.plus",
                            description: Text("Maak eerst een klant en project aan.")
                        )
                    } else {
                        Picker("Project", selection: $selectedProjectID) {
                            Text("Kies project").tag(UUID?.none)
                            ForEach(availableProjects) { project in
                                Text("\(store.clientName(for: project)) — \(project.name)")
                                    .tag(Optional(project.id))
                            }
                        }

                        TextField("Taak, bv. Montage", text: $task)

                        Button {
                            guard let id = selectedProjectID else { return }
                            store.startTimer(projectID: id, task: task)
                        } label: {
                            Label("Start projecttimer", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(selectedProjectID == nil)
                    }
                }
                .padding(22)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
            }

            Spacer()
        }
        .padding(28)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = availableProjects.first?.id
            }
        }
        .onChange(of: selectedProjectID) { _, newValue in
            if let id = newValue,
               let project = store.projects.first(where: { $0.id == id }) {
                task = project.defaultTask
            }
        }
    }
}

struct CurrentAppPill: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .frame(width: 8, height: 8)
            Text(store.activityMonitor.currentAppName)
                .lineLimit(1)
        }
        .foregroundStyle(store.activityMonitor.isUserActive ? .primary : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
