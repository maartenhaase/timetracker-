import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let block = store.activeBlock {
                Text(store.clientName(for: block.clientID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(block.task)
                    .font(.headline)
                    .lineLimit(2)

                if store.isDistracted {
                    Button {
                        store.endDistraction()
                    } label: {
                        Label("Terug naar taak", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    HStack {
                        Button("Klaar") {
                            store.finishBlock(done: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button("Afgeleid") {
                            store.startDistraction()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            } else {
                Text("Geen taak actief")
                    .foregroundStyle(.secondary)
                Text("Open Maarten Time en kies één ding om aan te beginnen.")
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}
