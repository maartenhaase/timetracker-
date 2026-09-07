import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showNewClient = false
    @State private var newClientName = ""
    @State private var showNewProject = false
    @State private var projectClientID: UUID?
    @State private var newProjectName = ""
    @State private var defaultTask = "Montage"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Klanten & projecten").font(.largeTitle.bold())
                Spacer()
                Button("Nieuwe klant", systemImage: "person.badge.plus") { showNewClient = true }
                Button("Nieuw project", systemImage: "folder.badge.plus") {
                    projectClientID = store.clients.first?.id
                    showNewProject = true
                }.disabled(store.clients.isEmpty)
            }

            List {
                ForEach(store.clients) { client in
                    Section(client.name) {
                        let clientProjects = store.projects.filter { $0.clientID == client.id }
                        if clientProjects.isEmpty { Text("Nog geen projecten").foregroundStyle(.secondary) }
                        ForEach(clientProjects) { project in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(project.name).font(.headline)
                                    Text("Standaardtaak: \(project.defaultTask)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if project.hourlyRate > 0 { Text(project.hourlyRate, format: .currency(code: "EUR")) }
                            }
                        }
                    }
                }
            }.listStyle(.inset)
        }
        .padding(28)
        .sheet(isPresented: $showNewClient) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nieuwe klant").font(.title2.bold())
                TextField("Naam", text: $newClientName)
                HStack {
                    Spacer()
                    Button("Annuleer") { showNewClient = false }
                    Button("Toevoegen") {
                        guard !newClientName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        _ = store.addClient(name: newClientName)
                        newClientName = ""
                        showNewClient = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(width: 380)
        }
        .sheet(isPresented: $showNewProject) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nieuw project").font(.title2.bold())
                Picker("Klant", selection: $projectClientID) {
                    ForEach(store.clients) { client in Text(client.name).tag(Optional(client.id)) }
                }
                TextField("Projectnaam", text: $newProjectName)
                TextField("Standaardtaak", text: $defaultTask)
                HStack {
                    Spacer()
                    Button("Annuleer") { showNewProject = false }
                    Button("Toevoegen") {
                        guard let clientID = projectClientID,
                              !newProjectName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        _ = store.addProject(clientID: clientID, name: newProjectName, defaultTask: defaultTask)
                        newProjectName = ""
                        defaultTask = "Montage"
                        showNewProject = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(width: 420)
        }
    }
}
