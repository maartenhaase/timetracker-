import SwiftUI

struct FinalCutView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Final Cut").font(.largeTitle.bold())
                permissionCard
                detectionCard
                mappingsCard
                activitiesCard
            }.padding(28)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Toegankelijkheid", systemImage: store.finalCutMonitor.hasAccessibilityPermission ? "checkmark.shield" : "exclamationmark.triangle").font(.headline)
            if store.finalCutMonitor.hasAccessibilityPermission {
                Text("Toegang is actief. Hierdoor kan de app labels uit de Final Cut-interface lezen.").foregroundStyle(.secondary)
            } else {
                Text("Geef de app toegang via Systeeminstellingen → Privacy en beveiliging → Toegankelijkheid. Zonder dit ziet de app wel dát Final Cut actief is, maar niet betrouwbaar waaraan je werkt.").foregroundStyle(.secondary)
                Button("Vraag toestemming") { store.finalCutMonitor.requestAccessibilityPermission() }
            }
        }.cardStyle()
    }

    private var detectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live detectie").font(.headline)
                Spacer()
                Toggle("Automatisch wisselen", isOn: $store.autoSwitchFinalCut).toggleStyle(.switch)
            }
            Text(store.finalCutMonitor.isFinalCutFrontmost ? "Final Cut staat vooraan" : "Open Final Cut en klik in je timeline om te testen.").foregroundStyle(.secondary)
            if !store.finalCutMonitor.detectedLabel.isEmpty {
                LabeledContent("Beste herkenning") { Text(store.finalCutMonitor.detectedLabel).fontWeight(.semibold) }
            }
            if !store.finalCutMonitor.candidateLabels.isEmpty {
                DisclosureGroup("Ruwe labels die Final Cut prijsgeeft") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(store.finalCutMonitor.candidateLabels.prefix(20), id: \.self) { label in
                            Text("• \(label)").textSelection(.enabled)
                        }
                    }.padding(.top, 6)
                }
            }
        }.cardStyle()
    }

    private var mappingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aangeleerde koppelingen").font(.headline)
            if store.finalCutMappings.isEmpty {
                Text("Nog geen koppelingen. Zodra Final Cut een nieuw label toont, kun je het aan een project koppelen.").foregroundStyle(.secondary)
            } else {
                ForEach(store.finalCutMappings) { mapping in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(mapping.detectedLabel).fontWeight(.medium)
                            Text("→ \(store.projectName(mapping.projectID)) · \(mapping.task)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.finalCutMappings.removeAll { $0.id == mapping.id }
                        } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                    Divider()
                }
            }
        }.cardStyle()
    }

    private var activitiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final Cut-activiteit").font(.headline)
            Text("Ook als je de timer vergeet, houdt deze lijst bij wanneer Final Cut vooraan stond. Met een bekende koppeling kun je die tijd achteraf toevoegen.").foregroundStyle(.secondary)
            if store.finalCutActivities.isEmpty {
                Text("Nog geen activiteit geregistreerd.").foregroundStyle(.secondary)
            } else {
                ForEach(store.finalCutActivities.prefix(25)) { activity in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(activity.detectedLabel).lineLimit(1)
                            Text("\(activity.start.formatted(date: .abbreviated, time: .shortened)) – \(activity.end.formatted(date: .omitted, time: .shortened)) · \(formatDuration(activity.duration))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if activity.imported {
                            Label("Toegevoegd", systemImage: "checkmark").font(.caption)
                        } else if let mapping = store.mapping(for: activity.detectedLabel) {
                            Button("Voeg toe") { store.importActivity(activity, using: mapping) }
                        } else {
                            Text("Niet gekoppeld").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }.cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        self.padding(18).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }
}
