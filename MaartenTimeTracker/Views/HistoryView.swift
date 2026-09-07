import SwiftUI

struct BillingView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nog te factureren")
                    .font(.largeTitle.bold())
                Text("Hier staan alleen klantblokken die nog niet met het geldzakje zijn afgehandeld.")
                    .foregroundStyle(.secondary)
            }

            if store.uninvoicedByClient.isEmpty {
                ContentUnavailableView(
                    "Niets open",
                    systemImage: "checkmark.seal",
                    description: Text("Er staat nu geen klanttijd meer open om te factureren.")
                )
            } else {
                List {
                    ForEach(Array(store.uninvoicedByClient.enumerated()), id: \.offset) { _, group in
                        Section {
                            ForEach(group.blocks) { block in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(block.task)
                                        Text(store.projectName(for: block.projectID))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(block.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(billableText(group: block.billableMinutes))
                                        .monospacedDigit()
                                }
                            }
                        } header: {
                            HStack {
                                Text(group.client.name)
                                Spacer()
                                Text("te factureren: \(billableText(group: group.billableMinutes))")
                                Button {
                                    store.markClientInvoiced(group.client)
                                } label: {
                                    Label("Gefactureerd", systemImage: "bag.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(28)
    }

    private func billableText(group minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) uur" : "\(h)u \(m)m"
    }
}

struct DoneView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gedaan")
                    .font(.largeTitle.bold())
                Text("Achteraf kijken wat je wél hebt gedaan.")
                    .foregroundStyle(.secondary)
            }

            if store.workBlocks.isEmpty {
                ContentUnavailableView(
                    "Nog geen blokken",
                    systemImage: "checkmark.circle",
                    description: Text("Zodra je een taak afrondt of stopt, verschijnt hij hier.")
                )
            } else {
                List {
                    ForEach(store.workBlocks) { block in
                        HStack(alignment: .top) {
                            Image(systemName: block.result == .done ? "checkmark.circle.fill" : "circle.dashed")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(block.task)
                                    .font(.headline)
                                Text("\(store.clientName(for: block.clientID)) — \(store.projectName(for: block.projectID))")
                                    .foregroundStyle(.secondary)
                                Text(block.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if block.clientID != nil {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(block.billableMinutes) min facturabel")
                                    if block.invoiced {
                                        Label("gefactureerd", systemImage: "bag.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Button(role: .destructive) {
                                store.deleteBlock(block)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(28)
    }
}
