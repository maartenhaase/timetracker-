import SwiftUI

struct ClientsProjectsView: View {
    @EnvironmentObject var store: AppStore

    @State private var newClient = ""
    @State private var projectClientID: UUID?
    @State private var newProject = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Klanten & projecten")
                    .font(.largeTitle.bold())
                Text("Een project krijgt automatisch je vaste soorten werk. Alleen uitzonderingen hoef je toe te voegen.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Nieuwe klant", text: $newClient)
                    .onSubmit(addClient)

                Button("Klant toevoegen", action: addClient)
                    .buttonStyle(.borderedProminent)
                    .disabled(newClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !store.clients.isEmpty {
                HStack {
                    Picker("Klant", selection: $projectClientID) {
                        Text("Kies klant").tag(UUID?.none)
                        ForEach(store.clients) { client in
                            Text(client.name).tag(Optional(client.id))
                        }
                    }
                    .frame(width: 220)

                    TextField("Nieuw project", text: $newProject)
                        .onSubmit(addProject)

                    Button("Project toevoegen", action: addProject)
                        .disabled(
                            projectClientID == nil ||
                            newProject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }

            List {
                ForEach(store.clients) { client in
                    Section {
                        let clientProjects = store.projects.filter { $0.clientID == client.id && !$0.isArchived }

                        if clientProjects.isEmpty {
                            Text("Nog geen projecten")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(clientProjects) { project in
                                ProjectRow(project: project)
                            }
                        }
                    } header: {
                        HStack {
                            Text(client.name)
                            Spacer()
                            Button(role: .destructive) {
                                store.deleteClient(client)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(28)
        .onAppear {
            if projectClientID == nil {
                projectClientID = store.clients.first?.id
            }
        }
    }

    private func addClient() {
        store.addClient(newClient)
        newClient = ""

        if projectClientID == nil {
            projectClientID = store.clients.last?.id
        }
    }

    private func addProject() {
        guard let clientID = projectClientID else { return }
        store.addProject(clientID: clientID, name: newProject)
        newProject = ""
    }
}

private struct ProjectRow: View {
    @EnvironmentObject var store: AppStore
    let project: WorkProject

    @State private var customTask = ""

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vaste taken")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(project.taskNames, id: \.self) { task in
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                        Text(task)
                        Spacer()

                        if !WorkProject.standardTaskNames.contains(task) {
                            Button(role: .destructive) {
                                store.deleteCustomTask(projectID: project.id, taskName: task)
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Divider()

                HStack {
                    TextField("Extra taak voor dit project", text: $customTask)
                        .onSubmit(addTask)
                    Button("Toevoegen", action: addTask)
                        .disabled(customTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        store.deleteProject(project)
                    } label: {
                        Label("Project verwijderen", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                Image(systemName: "folder")
                Text(project.name)
                    .font(.headline)
                Spacer()
                Text("\(project.taskNames.count) soorten werk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addTask() {
        store.addCustomTask(projectID: project.id, name: customTask)
        customTask = ""
    }
}
