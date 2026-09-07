import Foundation
import SwiftUI

struct WorkView: View {
    @EnvironmentObject var store: AppStore

    @State private var clientID: UUID?
    @State private var task = ""
    @State private var isRecovery = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let block = store.activeBlock {
                    activeCard(block)
                } else {
                    startCard

                    if let last = store.workBlocks.first {
                        Button {
                            clientID = last.clientID
                            task = last.task
                            isRecovery = false
                            store.startBlock(clientID: clientID, task: task)
                        } label: {
                            Label("Nog een blok: \(last.task)", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let message = store.lastRewardMessage {
                    Label(message, systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Waar begin je nu aan?")
                .font(.largeTitle.bold())
            Text("Eén korte taak. Een normaal werkblok is ongeveer een half uur.")
                .foregroundStyle(.secondary)
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Klant", selection: $clientID) {
                Text("Intern / niet facturabel").tag(UUID?.none)
                ForEach(store.clients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }

            TextField("Wat ga je nu doen?", text: $task)
                .font(.title3)
                .onSubmit(start)

            if store.recoveryBalanceSeconds > 30 {
                HStack {
                    Toggle("Dit blok telt als inhalen", isOn: $isRecovery)
                    Spacer()
                    Text("Er staat ongeveer \(softMinutes(store.recoveryBalanceSeconds)) in je inhaalpotje.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: start) {
                Label("BEGIN", systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Voor facturatie rondt elk klantblok later automatisch omhoog af op kwartieren, met minimaal 15 minuten.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func activeCard(_ block: ActiveWorkBlock) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let focused = focusedSeconds(block, at: context.date)
            let progress = min(1, focused / (30 * 60))

            VStack(alignment: .leading, spacing: 18) {
                if let client = store.activeClient {
                    Text(client.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Niet facturabel")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(block.task)
                    .font(.title.bold())

                if store.isDistracted {
                    Label("Je bent even afgeleid. Dat is nu apart geregistreerd.", systemImage: "pause.circle.fill")
                        .font(.headline)

                    Button {
                        store.endDistraction()
                    } label: {
                        Label("TERUG NAAR TAAK", systemImage: "arrow.uturn.backward")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Text("De afleiding gaat in je inhaalpotje; je gewone werktijd loopt hiervoor niet door.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)

                        Text(blockStatus(focused))
                            .font(.headline)
                        Text("30 minuten is een richtpunt, geen verplichting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            store.finishBlock(done: true)
                        } label: {
                            Label("KLAAR", systemImage: "checkmark")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            store.startDistraction()
                        } label: {
                            Label("AFGELEID", systemImage: "exclamationmark")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    Button("Stop dit blok zonder 'klaar'") {
                        store.finishBlock(done: false)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                if block.isRecovery {
                    Label("Dit blok telt ook als inhaaltijd.", systemImage: "arrow.counterclockwise.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func start() {
        store.startBlock(clientID: clientID, task: task, isRecovery: isRecovery)
        task = ""
        isRecovery = false
    }

    private func focusedSeconds(_ block: ActiveWorkBlock, at date: Date) -> TimeInterval {
        var distraction = block.distractionSeconds
        if let current = store.activeDistraction {
            distraction += max(0, date.timeIntervalSince(current.startedAt))
        }
        return max(0, date.timeIntervalSince(block.startedAt) - distraction)
    }

    private func blockStatus(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<8 * 60:
            return "Je bent begonnen. Dat is genoeg voor nu."
        case ..<20 * 60:
            return "Je zit in je blok."
        case ..<30 * 60:
            return "Lekker bezig — houd dit ene ding vast."
        default:
            return "Volwaardig werkblok neergezet."
        }
    }

    private func softMinutes(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(seconds / 60)))
        return "\(minutes) min"
    }
}
