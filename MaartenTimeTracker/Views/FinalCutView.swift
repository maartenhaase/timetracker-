import SwiftUI

extension View {
    func flowCard() -> some View {
        self
            .padding(18)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 16))
    }
}

func durationText(_ minutes: Int) -> String {
    switch minutes {
    case 15: return "15 min"
    case 30: return "30 min"
    case 45: return "45 min"
    case 60: return "1 uur"
    case 90: return "1,5 uur"
    default:
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) uur" : "\(h)u \(m)m"
    }
}

func minutesText(_ seconds: TimeInterval) -> String {
    let minutes = max(1, Int(ceil(seconds / 60)))
    return durationText(minutes)
}


struct HealthView: View {
    @EnvironmentObject var store: AppStore

    @State private var medicationName = ""
    @State private var medicationDose: Double = 0
    @State private var medicationUnit = "mg"
    @State private var medicationNote = ""

    @State private var calm = 3
    @State private var focus = 3
    @State private var energy = 3
    @State private var mood = 3
    @State private var wellbeingNote = ""

    @State private var sleepHours: Double = 7.5
    @State private var fallAsleepMinutes = 15
    @State private var rested = 3
    @State private var sleepNote = ""

    @State private var reportDays = 14
    @State private var showReport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Gezondheid")
                        .font(.largeTitle.bold())
                    Text("Loggen om patronen te kunnen bespreken en vergelijken — niet om zelf doseringen te berekenen.")
                        .foregroundStyle(.secondary)
                }

                coffeeCard
                medicationCard
                checkInCard
                sleepCard
                todayLogCard
                reportCard
            }
            .padding(28)
        }
    }

    private var coffeeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Koffie", systemImage: "cup.and.saucer.fill")
                    .font(.title3.bold())
                Spacer()
                Text("Vandaag: \(store.coffeeTodayCount)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    store.logCoffee()
                } label: {
                    Label("☕  +1 KOFFIE", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)

                Button("Laatste ongedaan") {
                    store.undoLastCoffee()
                }
                .disabled(store.coffeeTodayCount == 0)
            }

            Text("Meerdere koppen achter elkaar? Druk gewoon meerdere keren.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .flowCard()
    }

    private var medicationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Medicatie", systemImage: "pills.fill")
                .font(.title3.bold())

            if !store.recentMedicationPresets.isEmpty {
                Text("Recent gebruikt")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(store.recentMedicationPresets) { preset in
                        Button("\(preset.name) · \(doseText(preset.dose)) \(preset.unit)") {
                            store.logMedication(
                                name: preset.name,
                                dose: preset.dose,
                                unit: preset.unit
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            HStack {
                TextField("Naam medicatie", text: $medicationName)

                TextField(
                    "Dosis",
                    value: $medicationDose,
                    format: .number
                )
                .frame(width: 90)

                TextField("Eenheid", text: $medicationUnit)
                    .frame(width: 70)
            }

            TextField("Notitie (optioneel)", text: $medicationNote)

            Button {
                store.logMedication(
                    name: medicationName,
                    dose: medicationDose,
                    unit: medicationUnit,
                    note: medicationNote
                )
                medicationNote = ""
            } label: {
                Label("Medicatie ingenomen", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                medicationDose <= 0
            )
        }
        .flowCard()
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hoe voel ik mij nu?", systemImage: "waveform.path.ecg")
                .font(.title3.bold())

            scorePicker("Rust in hoofd", selection: $calm)
            scorePicker("Focus", selection: $focus)
            scorePicker("Energie", selection: $energy)
            scorePicker("Stemming", selection: $mood)

            TextField("Bijzonderheden / bijwerkingen / context (optioneel)", text: $wellbeingNote)

            Button {
                store.logWellbeing(
                    calm: calm,
                    focus: focus,
                    energy: energy,
                    mood: mood,
                    note: wellbeingNote
                )
                wellbeingNote = ""
            } label: {
                Label("Check-in opslaan", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)

            Text("1 = laag / onrustig, 5 = sterk / rustig. Gebruik vooral steeds dezelfde betekenis voor jezelf.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .flowCard()
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nachtrust", systemImage: "moon.zzz.fill")
                .font(.title3.bold())

            Stepper(
                "Geslapen: \(String(format: "%.1f", sleepHours)) uur",
                value: $sleepHours,
                in: 0...14,
                step: 0.5
            )

            Stepper(
                "In slaap vallen: ongeveer \(fallAsleepMinutes) min",
                value: $fallAsleepMinutes,
                in: 0...180,
                step: 5
            )

            scorePicker("Uitgerust bij wakker worden", selection: $rested)

            TextField("Notitie (optioneel)", text: $sleepNote)

            Button {
                store.logSleep(
                    sleepHours: sleepHours,
                    fallAsleepMinutes: fallAsleepMinutes,
                    rested: rested,
                    note: sleepNote
                )
                sleepNote = ""
            } label: {
                Label("Nachtrust opslaan", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
        .flowCard()
    }

    private var todayLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Vandaag gelogd", systemImage: "clock")
                .font(.title3.bold())

            let meds = store.medicationEntries
                .filter { Calendar.current.isDateInToday($0.date) }
                .sorted { $0.date > $1.date }

            let checks = store.wellbeingEntries
                .filter { Calendar.current.isDateInToday($0.date) }
                .sorted { $0.date > $1.date }

            let sleeps = store.sleepEntries
                .filter { Calendar.current.isDateInToday($0.date) }
                .sorted { $0.date > $1.date }

            if meds.isEmpty && checks.isEmpty && sleeps.isEmpty && store.coffeeTodayCount == 0 {
                Text("Nog niets gelogd.")
                    .foregroundStyle(.secondary)
            }

            if store.coffeeTodayCount > 0 {
                Label("\(store.coffeeTodayCount) koffie", systemImage: "cup.and.saucer")
            }

            ForEach(meds) { entry in
                HStack {
                    Label(
                        "\(entry.date.formatted(date: .omitted, time: .shortened)) · \(entry.name) \(doseText(entry.dose)) \(entry.unit)",
                        systemImage: "pills"
                    )
                    Spacer()
                    Button(role: .destructive) {
                        store.deleteMedication(entry)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            ForEach(checks) { entry in
                HStack {
                    Label(
                        "\(entry.date.formatted(date: .omitted, time: .shortened)) · rust \(entry.calm) · focus \(entry.focus) · energie \(entry.energy) · stemming \(entry.mood)",
                        systemImage: "heart.text.clipboard"
                    )
                    Spacer()
                    Button(role: .destructive) {
                        store.deleteWellbeing(entry)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            ForEach(sleeps) { entry in
                HStack {
                    Label(
                        "\(String(format: "%.1f", entry.sleepHours))u slaap · \(entry.fallAsleepMinutes) min inslapen · uitgerust \(entry.rested)/5",
                        systemImage: "moon.zzz"
                    )
                    Spacer()
                    Button(role: .destructive) {
                        store.deleteSleep(entry)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .flowCard()
    }

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Rapport", systemImage: "doc.text")
                .font(.title3.bold())

            Picker("Periode", selection: $reportDays) {
                Text("7 dagen").tag(7)
                Text("14 dagen").tag(14)
                Text("30 dagen").tag(30)
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    store.copyHealthReport(days: reportDays)
                } label: {
                    Label("Kopieer rapport", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                Button(showReport ? "Verberg voorbeeld" : "Bekijk voorbeeld") {
                    showReport.toggle()
                }
            }

            if showReport {
                ScrollView {
                    Text(store.healthReport(days: reportDays))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 320)
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }

            Text("Het rapport zet medicatie, koffie, slaap en check-ins naast elkaar. Het trekt bewust geen medische conclusies.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .flowCard()
    }

    private func scorePicker(_ title: String, selection: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .frame(width: 170, alignment: .leading)

            Picker(title, selection: selection) {
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func doseText(_ dose: Double) -> String {
        if dose.rounded() == dose {
            return String(Int(dose))
        }
        return String(format: "%.2f", dose)
            .replacingOccurrences(of: "0$", with: "")
    }
}
