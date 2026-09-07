import SwiftUI

struct BillingView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nog te factureren")
                    .font(.largeTitle.bold())
                Text("Hier staan alleen de exacte kwartieren die administratief nog open zijn.")
                    .foregroundStyle(.secondary)
            }

            if store.billingProjectSummaries.isEmpty {
                ContentUnavailableView(
                    "Niets open",
                    systemImage: "checkmark.seal",
                    description: Text("Er staat nu geen klanttijd open om te factureren.")
                )
            } else {
                List {
                    ForEach(store.billingProjectSummaries) { projectSummary in
                        Section {
                            ForEach(projectSummary.units) { unit in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(unit.task)
                                            .font(.headline)
                                        Text(unit.category)
                                            .foregroundStyle(.secondary)
                                        Text(unit.firstDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(durationText(unit.billableMinutes))
                                        .font(.headline)
                                        .monospacedDigit()

                                    Button {
                                        store.markBillingUnitInvoiced(unit.id)
                                    } label: {
                                        Image(systemName: "bag.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .help("Markeer dit werk als gefactureerd")
                                }
                                .padding(.vertical, 3)
                            }
                        } header: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.clientName(for: projectSummary.clientID))
                                    Text(store.projectName(for: projectSummary.projectID))
                                        .font(.caption)
                                }

                                Spacer()

                                Text("open: \(durationText(projectSummary.totalBillableMinutes))")

                                Button {
                                    store.markProjectInvoiced(projectSummary.projectID)
                                } label: {
                                    Label("Alles gefactureerd", systemImage: "bag.fill")
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
}

struct DoneView: View {
    @EnvironmentObject var store: AppStore
    @State private var showDistractions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gedaan")
                    .font(.largeTitle.bold())
                Text("Terugkijken naar wat er wél gebeurd is. Geen achterstallige score.")
                    .foregroundStyle(.secondary)
            }

            Label(store.focusMessage, systemImage: "scope")
                .font(.headline)
                .flowCard()

            if store.doneTasksByDay.isEmpty {
                ContentUnavailableView(
                    "Nog niets geregistreerd",
                    systemImage: "checkmark.circle",
                    description: Text("Afgeronde of achteraf toegevoegde taken verschijnen hier.")
                )
            } else {
                List {
                    ForEach(store.doneTasksByDay, id: \.date) { group in
                        Section(group.date.formatted(date: .complete, time: .omitted)) {
                            ForEach(group.tasks) { task in
                                HStack(alignment: .top) {
                                    Image(systemName: "checkmark.circle.fill")

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title)
                                            .font(.headline)

                                        Text("\(store.clientName(forProjectID: task.projectID)) — \(store.projectName(for: task.projectID))")
                                            .foregroundStyle(.secondary)

                                        Text("\(task.category) · blok \(durationText(task.plannedMinutes))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            DisclosureGroup(isExpanded: $showDistractions) {
                VStack(alignment: .leading, spacing: 8) {
                    if store.distractionPeriods.isEmpty {
                        Text("Nog geen afleidmomenten geregistreerd.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.distractionPeriods.prefix(30)) { period in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(period.task)
                                    Text(period.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(minutesText(period.duration))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Afleidmomenten — alleen als je details wilt zien", systemImage: "eye")
                    .foregroundStyle(.secondary)
            }
            .flowCard()
        }
        .padding(28)
    }
}
