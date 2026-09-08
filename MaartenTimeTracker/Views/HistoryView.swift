import SwiftUI

struct BillingView: View {
    @EnvironmentObject var store: AppStore

    @State private var showManual = false
    @State private var manualClientID: UUID?
    @State private var manualProjectID: UUID?
    @State private var manualDescription = ""
    @State private var manualMinutes = 15
    @State private var manualDate = Date()
    @State private var showExport = false

    private let minuteOptions = [15,30,45,60,90,120]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Factureren")
                        .font(.largeTitle.bold())
                    Text("Exacte kwartieren horen hier; niet op je dagelijkse scorebord.")
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    showManual = true
                } label: {
                    Label("Handmatig toevoegen", systemImage: "plus")
                }

                Button {
                    store.copyBillingList()
                } label: {
                    Label("Kopieer lijst", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }

            if store.billingProjectSummaries.isEmpty && store.openManualBilling.isEmpty {
                ContentUnavailableView(
                    "Niets open",
                    systemImage: "checkmark.seal",
                    description: Text("Er staat nu geen klanttijd open om te factureren.")
                )
            } else {
                List {
                    ForEach(store.billingProjectSummaries) { summary in
                        Section {
                            ForEach(summary.units) { unit in
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
                                    .help("Markeer als gefactureerd")
                                }
                            }
                        } header: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.clientName(for: summary.clientID))
                                    Text(store.projectName(for: summary.projectID))
                                        .font(.caption)
                                }
                                Spacer()
                                Text("open: \(durationText(summary.totalBillableMinutes))")
                                Button {
                                    store.markProjectInvoiced(summary.projectID)
                                } label: {
                                    Label("Alles", systemImage: "bag.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }

                    if !store.openManualBilling.isEmpty {
                        Section("Handmatig toegevoegd") {
                            ForEach(store.openManualBilling) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.description).font(.headline)
                                        Text("\(store.clientName(for: entry.clientID)) — \(store.projectName(for: entry.projectID))")
                                            .foregroundStyle(.secondary)
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(durationText(entry.minutes))
                                    Button {
                                        store.markManualBillingInvoiced(entry)
                                    } label: {
                                        Image(systemName: "bag.fill")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            DisclosureGroup(isExpanded: $showExport) {
                Text(store.billingExportText())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.top, 8)
            } label: {
                Label("Voorbeeld kopieerlijst", systemImage: "doc.text")
                    .foregroundStyle(.secondary)
            }
            .flowCard()
        }
        .padding(28)
        .sheet(isPresented: $showManual) {
            VStack(alignment: .leading, spacing: 15) {
                Text("Handmatig facturabel toevoegen")
                    .font(.title2.bold())

                Picker("Klant", selection: $manualClientID) {
                    Text("Kies klant").tag(UUID?.none)
                    ForEach(store.clients.filter { !$0.isArchived }) { client in
                        Text(client.name).tag(Optional(client.id))
                    }
                }

                Picker("Project", selection: $manualProjectID) {
                    Text("Geen specifiek project").tag(UUID?.none)
                    ForEach(store.projects.filter {
                        !$0.isArchived &&
                        (manualClientID == nil || $0.clientID == manualClientID)
                    }) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }

                TextField("Omschrijving, bv. telefonisch overleg", text: $manualDescription)

                Picker("Tijd", selection: $manualMinutes) {
                    ForEach(minuteOptions, id: \.self) { value in
                        Text(durationText(value)).tag(value)
                    }
                }

                DatePicker("Datum", selection: $manualDate, displayedComponents: .date)

                HStack {
                    Spacer()
                    Button("Annuleer") { showManual = false }
                    Button("Toevoegen") {
                        guard let clientID = manualClientID else { return }
                        store.addManualBilling(
                            clientID: clientID,
                            projectID: manualProjectID,
                            description: manualDescription,
                            minutes: manualMinutes,
                            date: manualDate
                        )
                        manualDescription = ""
                        manualMinutes = 15
                        showManual = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        manualClientID == nil ||
                        manualDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .padding(24)
            .frame(width: 470)
        }
        .onChange(of: manualClientID) { _, clientID in
            if let projectID = manualProjectID,
               let project = store.projects.first(where: { $0.id == projectID }),
               project.clientID != clientID {
                manualProjectID = nil
            }
        }
    }
}

struct DoneView: View {
    @EnvironmentObject var store: AppStore
    @State private var showDistractions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gedaan")
                        .font(.largeTitle.bold())
                    Text("Recent werk blijft zichtbaar; ouder werk klapt automatisch het archief in.")
                        .foregroundStyle(.secondary)
                }

                Label(store.focusMessage, systemImage: "scope")
                    .font(.headline)
                    .flowCard()

                recentCard
                archiveCard

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
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Afleidmomenten — alleen als je details wilt", systemImage: "eye")
                        .foregroundStyle(.secondary)
                }
                .flowCard()
            }
            .padding(28)
        }
    }

    private var recentCard: some View {
        let recent = doneTasks.filter { Date().timeIntervalSince($0.completedAt ?? $0.date) <= 7 * 24 * 3600 }

        return VStack(alignment: .leading, spacing: 10) {
            Label("Afgelopen 7 dagen", systemImage: "checkmark.circle.fill")
                .font(.title3.bold())

            if recent.isEmpty {
                Text("Nog niets geregistreerd in de laatste week.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent.prefix(40)) { task in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                            Text("\(store.clientName(forProjectID: task.projectID)) — \(store.projectName(for: task.projectID)) · \(task.category)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((task.completedAt ?? task.date).formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .flowCard()
    }

    private var archiveCard: some View {
        let older = doneTasks.filter { Date().timeIntervalSince($0.completedAt ?? $0.date) > 7 * 24 * 3600 }
        let grouped = Dictionary(grouping: older) { task -> String in
            (task.completedAt ?? task.date).formatted(.dateTime.year().month(.wide))
        }
        let groups = grouped.keys.sorted().reversed()

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if older.isEmpty {
                    Text("Nog niets in het archief.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(groups), id: \.self) { key in
                        DisclosureGroup("\(key) · \(grouped[key]?.count ?? 0) items") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach((grouped[key] ?? []).sorted {
                                    ($0.completedAt ?? $0.date) > ($1.completedAt ?? $1.date)
                                }) { task in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                            Text("\(store.projectName(for: task.projectID)) · \((task.completedAt ?? task.date).formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            store.deleteDailyTask(task)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Ouder archief (\(older.count))", systemImage: "archivebox")
                .font(.headline)
        }
        .flowCard()
    }

    private var doneTasks: [DailyTask] {
        store.dailyTasks
            .filter { $0.isDone }
            .sorted { ($0.completedAt ?? $0.date) > ($1.completedAt ?? $1.date) }
    }
}
