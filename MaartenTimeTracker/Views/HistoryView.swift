import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var showManual = false
    @State private var manualProjectID: UUID?
    @State private var manualTask = "Montage"
    @State private var manualStart = Date().addingTimeInterval(-3600)
    @State private var manualEnd = Date()

    private var totalDuration: TimeInterval { store.entries.reduce(0) { $0 + $1.duration } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Uren").font(.largeTitle.bold())
                    Text("Totaal geregistreerd: \(formatDuration(totalDuration))").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Handmatig toevoegen", systemImage: "plus") {
                    manualProjectID = store.projects.first?.id
                    showManual = true
                }
                Button("Exporteer CSV", systemImage: "square.and.arrow.up") { exportCSV() }
                    .disabled(store.entries.isEmpty)
            }

            List {
                ForEach(store.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.projectName(entry.projectID)).font(.headline)
                            Text(entry.task).foregroundStyle(.secondary)
                            Text(entry.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatDuration(entry.duration)).monospacedDigit()
                        Button(role: .destructive) { store.deleteEntry(entry) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }.padding(.vertical, 4)
                }
            }
        }
        .padding(28)
        .sheet(isPresented: $showManual) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tijd handmatig toevoegen").font(.title2.bold())
                Picker("Project", selection: $manualProjectID) {
                    ForEach(store.projects) { project in
                        Text("\(store.clientName(for: project)) — \(project.name)").tag(Optional(project.id))
                    }
                }
                TextField("Taak", text: $manualTask)
                DatePicker("Start", selection: $manualStart)
                DatePicker("Einde", selection: $manualEnd)
                HStack {
                    Spacer()
                    Button("Annuleer") { showManual = false }
                    Button("Toevoegen") {
                        guard let projectID = manualProjectID else { return }
                        store.addManualEntry(projectID: projectID, task: manualTask, start: manualStart, end: manualEnd)
                        showManual = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualProjectID == nil || manualEnd <= manualStart)
                }
            }.padding(24).frame(width: 430)
        }
    }

    private func exportCSV() {
        let header = "client,project,task,start,end,hours\n"
        let lines = store.entries.map { entry -> String in
            let project = store.projects.first(where: { $0.id == entry.projectID })
            let client = project.flatMap { p in store.clients.first(where: { $0.id == p.clientID })?.name } ?? ""
            let projectName = project?.name ?? ""
            let hours = entry.duration / 3600
            return [client, projectName, entry.task, entry.start.ISO8601Format(), entry.end.ISO8601Format(), String(format: "%.2f", hours)]
                .map(csvEscape).joined(separator: ",")
        }
        let csv = header + lines.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "uren.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
