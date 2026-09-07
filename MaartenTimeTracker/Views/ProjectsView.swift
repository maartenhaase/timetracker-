import SwiftUI

struct ClientsView: View {
    @EnvironmentObject var store: AppStore
    @State private var newClient = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Klanten")
                .font(.largeTitle.bold())

            HStack {
                TextField("Nieuwe klant", text: $newClient)
                    .onSubmit(add)
                Button("Voeg toe", action: add)
                    .buttonStyle(.borderedProminent)
                    .disabled(newClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            List {
                ForEach(store.clients) { client in
                    HStack {
                        Text(client.name)
                            .font(.headline)
                        Spacer()
                        if store.activeBlock?.clientID == client.id {
                            Text("nu actief")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                store.deleteClient(client)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
        .padding(28)
    }

    private func add() {
        store.addClient(newClient)
        newClient = ""
    }
}
