import SwiftUI

struct ClientsView: View {
    @EnvironmentObject var store: AppStore
    @State private var newClient = ""
    @State private var selectedClientID: UUID?
    @State private var newProject = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Klanten & projecten")
                .font(.largeTitle.bold())

            HStack {
                TextField("Nieuwe klant", text: $newClient)
                    .onSubmit(addClient)
                Button("Klant toevoegen", action: addClient)
                    .buttonStyle(.borderedProminent)
                    .disabled(newClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !store.clients.isEmpty {
                HStack {
                    Picker("Klant", selection: $selectedClientID) {
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
                            selectedClientID == nil ||
                            newProject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }

            List {
                ForEach(store.clients) { client in
                    Section(client.name) {
                        let clientProjects = store.projects.filter { $0.clientID == client.id }

                        if clientProjects.isEmpty {
                            Text("Nog geen projecten")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(clientProjects) { project in
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                    Text(project.name)
                                    Spacer()

                                    if store.activeBlock?.projectID == project.id {
                                        Text("nu actief")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Button(role: .destructive) {
                                            store.deleteProject(project)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(28)
        .onAppear {
            if selectedClientID == nil {
                selectedClientID = store.clients.first?.id
            }
        }
    }

    private func addClient() {
        store.addClient(newClient)
        newClient = ""
        if selectedClientID == nil {
            selectedClientID = store.clients.last?.id
        }
    }

    private func addProject() {
        guard let clientID = selectedClientID else { return }
        store.addProject(clientID: clientID, name: newProject)
        newProject = ""
    }
}
