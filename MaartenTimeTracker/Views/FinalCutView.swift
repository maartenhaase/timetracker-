import Foundation
import SwiftUI

struct DistractionView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Afleiding")
                    .font(.largeTitle.bold())
                Text("Geen straflijst. Alleen zichtbaar maken hoeveel tijd je eventueel later wilt terugpakken.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Inhaalpotje vandaag")
                    .font(.headline)

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    if store.recoveryBalanceSeconds < 30 {
                        Label("Je staat rustig. Niets hoeft ingehaald.", systemImage: "checkmark.circle.fill")
                            .font(.title3.bold())
                    } else {
                        Text("Ongeveer \(minutes(store.recoveryBalanceSeconds)) staat nog open.")
                            .font(.title2.bold())
                        Text("Start bij Werk gewoon een volgend blok en zet ‘Dit blok telt als inhalen’ aan.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))

            if store.todayDistractions.isEmpty && !store.isDistracted {
                ContentUnavailableView(
                    "Geen afleidmomenten geregistreerd",
                    systemImage: "leaf",
                    description: Text("Mooi. Of je hebt de knop vandaag gewoon nog niet nodig gehad.")
                )
            } else {
                List {
                    ForEach(store.todayDistractions) { period in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(period.task)
                                Text(period.startedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(minutes(period.duration))
                                .monospacedDigit()
                        }
                    }

                    if let active = store.activeDistraction,
                       let task = store.activeBlock?.task {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            HStack {
                                Text(task)
                                Spacer()
                                Text("\(minutes(context.date.timeIntervalSince(active.startedAt))) · loopt")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(28)
    }

    private func minutes(_ seconds: TimeInterval) -> String {
        "\(max(1, Int(ceil(seconds / 60)))) min"
    }
}
