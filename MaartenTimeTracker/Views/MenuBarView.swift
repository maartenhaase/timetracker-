import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let block = store.activeBlock {
                Text(store.clientName(forProjectID: block.projectID))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(block.task)
                    .font(.headline)
                    .lineLimit(2)

                Text(block.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.isDistracted {
                    Button {
                        store.endDistraction()
                    } label: {
                        Label("IK BEN TERUG", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    HStack {
                        Button("Klaar") {
                            store.finishActiveBlock(done: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button("Afgeleid") {
                            store.startDistraction()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    Button("Open app om veilig te parkeren") {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .buttonStyle(.borderless)
                }
            } else if let parked = store.parkedItems.first {
                Text("Veilig geparkeerd")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(parked.task)
                    .font(.headline)

                Text(parked.resumeNote)
                    .font(.caption)

                Button("Hervat") {
                    store.resumeParked(parked)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(store.isTodayClosed ? "Werkdag gesloten" : "Geen blok actief")
                    .foregroundStyle(.secondary)

                Text(store.isTodayClosed
                     ? "De rest mag wachten."
                     : "Open Maarten Flow en kies één blok.")
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
