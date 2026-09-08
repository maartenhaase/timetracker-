import SwiftUI

struct WorkCRMView: View {
    @EnvironmentObject var store: AppStore

    enum WorkSection: String, CaseIterable, Identifiable {
        case weddings = "Bruiloften"
        case business = "Zakelijk"
        case company = "Eigen bedrijf"
        var id: String { rawValue }
    }

    @State private var section: WorkSection = .weddings

    @State private var weddingNames = ""
    @State private var weddingHasDate = true
    @State private var weddingDate = Date().addingTimeInterval(60*60*24*60)
    @State private var weddingEmail = ""
    @State private var weddingPhone = ""

    @State private var businessClientName = ""
    @State private var businessProjectClientID: UUID?
    @State private var businessProjectName = ""
    @State private var businessHasDeadline = false
    @State private var businessDeadline = Date().addingTimeInterval(60*60*24*14)

    @State private var companyTitle = ""
    @State private var companyNextStep = ""
    @State private var companyMinutes = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Werk")
                    .font(.largeTitle.bold())
                Text("CRM bewaart wat er moet gebeuren. Vandaag bepaalt waar je nu aandacht aan geeft.")
                    .foregroundStyle(.secondary)
            }

            Picker("Werksoort", selection: $section) {
                ForEach(WorkSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch section {
                case .weddings: weddingView
                case .business: businessView
                case .company: companyView
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(28)
        .onAppear {
            if businessProjectClientID == nil {
                businessProjectClientID = store.clients.first(where: { $0.kind == .business && !$0.isArchived })?.id
            }
        }
    }

    private var weddingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Namen bruidspaar", text: $weddingNames)
                        Toggle("Trouwdatum bekend", isOn: $weddingHasDate)
                        if weddingHasDate {
                            DatePicker("Trouwdatum", selection: $weddingDate, displayedComponents: .date)
                        }
                        HStack {
                            TextField("E-mail (optioneel)", text: $weddingEmail)
                            TextField("Telefoon (optioneel)", text: $weddingPhone)
                        }

                        Button {
                            store.addWeddingInquiry(
                                names: weddingNames,
                                weddingDate: weddingHasDate ? weddingDate : nil,
                                email: weddingEmail,
                                phone: weddingPhone
                            )
                            weddingNames = ""
                            weddingEmail = ""
                            weddingPhone = ""
                        } label: {
                            Label("Nieuwe aanvraag toevoegen", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(weddingNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Nieuwe bruiloftaanvraag", systemImage: "person.badge.plus")
                        .font(.headline)
                }
                .flowCard()

                let active = store.projects.filter { project in
                    project.kind == .wedding &&
                    !project.isArchived &&
                    !(store.clients.first(where: { $0.id == project.clientID })?.isArchived ?? false)
                }

                if active.isEmpty {
                    ContentUnavailableView(
                        "Geen actieve bruiloften",
                        systemImage: "heart",
                        description: Text("Nieuwe aanvragen verschijnen hier met één duidelijke volgende stap.")
                    )
                } else {
                    ForEach(active.sorted(by: weddingSort)) { project in
                        WeddingProjectCard(project: project)
                    }
                }

                let archived = store.projects.filter { $0.kind == .wedding && $0.isArchived }
                if !archived.isEmpty {
                    DisclosureGroup("Archief (\(archived.count))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(archived) { project in
                                HStack {
                                    Text("\(store.clientName(for: project.clientID)) — \(project.name)")
                                    Spacer()
                                    Button("Herstel") { store.restoreProject(project) }
                                    Button(role: .destructive) {
                                        store.deleteProject(project)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .flowCard()
                }
            }
        }
    }

    private var businessView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("Nieuwe zakelijke klant", text: $businessClientName)
                            Button("Klant toevoegen") {
                                store.addClient(businessClientName, kind: .business)
                                businessClientName = ""
                                if businessProjectClientID == nil {
                                    businessProjectClientID = store.clients.last?.id
                                }
                            }
                            .disabled(businessClientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Divider()

                        Picker("Klant", selection: $businessProjectClientID) {
                            Text("Kies klant").tag(UUID?.none)
                            ForEach(store.clients.filter { $0.kind == .business && !$0.isArchived }) { client in
                                Text(client.name).tag(Optional(client.id))
                            }
                        }

                        TextField("Nieuw project / film / ronde", text: $businessProjectName)
                        Toggle("Deadline bekend", isOn: $businessHasDeadline)
                        if businessHasDeadline {
                            DatePicker("Deadline", selection: $businessDeadline, displayedComponents: .date)
                        }

                        Button {
                            guard let clientID = businessProjectClientID else { return }
                            store.addBusinessProject(
                                clientID: clientID,
                                name: businessProjectName,
                                deadline: businessHasDeadline ? businessDeadline : nil
                            )
                            businessProjectName = ""
                        } label: {
                            Label("Project toevoegen", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            businessProjectClientID == nil ||
                            businessProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Klant / project toevoegen", systemImage: "plus.circle")
                        .font(.headline)
                }
                .flowCard()

                let activeClients = store.clients.filter { $0.kind == .business && !$0.isArchived }

                ForEach(activeClients) { client in
                    let clientProjects = store.projects.filter {
                        $0.clientID == client.id && $0.kind == .business && !$0.isArchived
                    }

                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            if clientProjects.isEmpty {
                                Text("Nog geen projecten")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(clientProjects) { project in
                                    BusinessProjectCard(project: project)
                                }
                            }

                            HStack {
                                Spacer()
                                Button("Klant archiveren") { store.archiveClient(client) }
                                    .buttonStyle(.borderless)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Label(client.name, systemImage: "building.2")
                                .font(.title3.bold())
                            Spacer()
                            Text("\(clientProjects.count) projecten")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .flowCard()
                }

                let archivedClients = store.clients.filter { $0.kind == .business && $0.isArchived }
                if !archivedClients.isEmpty {
                    DisclosureGroup("Zakelijk archief (\(archivedClients.count))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(archivedClients) { client in
                                HStack {
                                    Text(client.name)
                                    Spacer()
                                    Button("Herstel") { store.restoreClient(client) }
                                    Button(role: .destructive) {
                                        store.deleteClient(client)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .flowCard()
                }
            }
        }
    }

    private var companyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Bedrijf bouwen", systemImage: "building.2.crop.circle")
                        .font(.title3.bold())
                    Text("Dit is de lijst die klantwerk anders jarenlang kan verdringen. Geen deadlines; iedere dag één klein blok is genoeg.")
                        .foregroundStyle(.secondary)

                    TextField("Onderwerp, bv. cursus / promo / website", text: $companyTitle)
                    TextField("Eerstvolgende stap", text: $companyNextStep)
                    HStack {
                        Picker("Blok", selection: $companyMinutes) {
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("45 min").tag(45)
                            Text("1 uur").tag(60)
                        }
                        .frame(width: 160)

                        Button("Toevoegen") {
                            store.addCompanyItem(
                                title: companyTitle,
                                nextStep: companyNextStep,
                                minutes: companyMinutes
                            )
                            companyTitle = ""
                            companyNextStep = ""
                            companyMinutes = 30
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(companyTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .flowCard()

                ForEach(store.companyItems.filter { !$0.isArchived }) { item in
                    CompanyItemCard(item: item)
                }

                let archived = store.companyItems.filter { $0.isArchived }
                if !archived.isEmpty {
                    DisclosureGroup("Archief (\(archived.count))") {
                        ForEach(archived) { item in
                            Text(item.title)
                        }
                    }
                    .flowCard()
                }
            }
        }
    }

    private func weddingSort(_ a: WorkProject, _ b: WorkProject) -> Bool {
        switch (a.weddingDate, b.weddingDate) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return store.clientName(for: a.clientID) < store.clientName(for: b.clientID)
        }
    }
}

private struct WeddingProjectCard: View {
    @EnvironmentObject var store: AppStore
    let project: WorkProject

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Volgende stap")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(store.nextCRMStage(for: project))
                            .font(.title3.bold())
                    }
                    Spacer()
                    Button("Zet op vandaag") {
                        store.planNextCRMStage(project)
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Button {
                        store.retreatCRM(project)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(project.weddingStepIndex == 0)

                    Button {
                        store.advanceCRM(project)
                    } label: {
                        Label("Stap afgerond", systemImage: "checkmark")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if let date = project.weddingDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }

                if store.nextCRMStage(for: project) == "Contactmoment ingepland",
                   let date = project.weddingDate,
                   let suggested = Calendar.current.date(byAdding: .day, value: -14, to: date) {
                    Label(
                        "Praktische suggestie: contactmoment rond \(suggested.formatted(date: .abbreviated, time: .omitted)).",
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                weddingBudget

                DisclosureGroup("Hele workflow") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(weddingCRMStages.enumerated()), id: \.offset) { index, stage in
                            HStack {
                                Image(systemName: index < project.weddingStepIndex ? "checkmark.circle.fill" : index == project.weddingStepIndex ? "arrow.right.circle.fill" : "circle")
                                Text(stage)
                                    .foregroundStyle(index > project.weddingStepIndex ? .secondary : .primary)
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                HStack {
                    Spacer()
                    Button("Archiveren") { store.archiveProject(project) }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.clientName(for: project.clientID))
                        .font(.title3.bold())
                    Text("Volgende: \(store.nextCRMStage(for: project))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let date = project.weddingDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .flowCard()
    }

    private var weddingBudget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Trouwfilm-editbudget", systemImage: "gauge.with.dots.needle.50percent")
                .font(.headline)

            BudgetLine(
                title: "Ruwe montage",
                used: store.focusedMinutes(projectID: project.id, category: "Ruwe montage"),
                budget: 120
            )
            BudgetLine(
                title: "Fijne montage",
                used: store.focusedMinutes(projectID: project.id, category: "Fijne montage"),
                budget: 480
            )
            BudgetLine(
                title: "Eindmontage / afronden",
                used: store.focusedMinutes(projectID: project.id, category: "Eindmontage / afronden"),
                budget: 120
            )
            BudgetLine(
                title: "Aanpassingen (extra buffer)",
                used: store.focusedMinutes(projectID: project.id, category: "Aanpassingen"),
                budget: 60
            )

            Text("Standaard montage: ongeveer \(durationText(store.weddingTotalEditMinutes(projectID: project.id))) besteed van ±12 uur, plus eventueel 1 uur aanpassingen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BudgetLine: View {
    let title: String
    let used: Int
    let budget: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(durationText(used)) / \(durationText(budget))")
                    .font(.caption)
                    .foregroundStyle(used > budget ? .red : .secondary)
            }
            ProgressView(value: min(1, Double(used) / Double(max(1, budget))))
        }
    }
}

private struct BusinessProjectCard: View {
    @EnvironmentObject var store: AppStore
    let project: WorkProject
    @State private var extraTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name).font(.headline)
                    Text("Volgende: \(store.nextCRMStage(for: project))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let deadline = project.deadline {
                    Text(deadline.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Zet volgende stap op vandaag") {
                    store.planNextCRMStage(project)
                }
                .buttonStyle(.borderedProminent)

                Button("Stap afgerond") {
                    store.advanceCRM(project)
                }
                .buttonStyle(.bordered)

                Button {
                    store.retreatCRM(project)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(project.businessStepIndex == 0)
            }

            HStack {
                Button("+ Aanpassingsronde") {
                    store.addBusinessRevision(project)
                }
                .buttonStyle(.bordered)

                TextField("Meerwerk / extra / upsell", text: $extraTitle)
                Button("+ Extra") {
                    store.addBusinessExtra(project, title: extraTitle)
                    extraTitle = ""
                }
                .disabled(extraTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("Zakelijk heeft bewust geen projecttijdlimiet. Flow bewaakt alleen lange onafgebroken focusblokken.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Archiveren") { store.archiveProject(project) }
                    .buttonStyle(.borderless)
            }

            Divider()
        }
    }
}

private struct CompanyItemCard: View {
    @EnvironmentObject var store: AppStore
    let item: CompanyWorkItem
    @State private var nextStep: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.title3.bold())
                    Text(item.nextStep.isEmpty ? "Nog geen volgende stap" : item.nextStep)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(durationText(item.defaultMinutes))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Zet op vandaag") { store.planCompanyItem(item) }
                    .buttonStyle(.borderedProminent)

                TextField("Nieuwe volgende stap", text: $nextStep)
                Button("Bewaar stap") {
                    store.updateCompanyItem(item, nextStep: nextStep)
                    nextStep = ""
                }
                .disabled(nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                if let last = item.lastWorkedAt {
                    Text("Laatst aandacht gegeven: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Archiveren") { store.archiveCompanyItem(item) }
                    .buttonStyle(.borderless)
            }
        }
        .flowCard()
        .onAppear {
            nextStep = item.nextStep
        }
    }
}
