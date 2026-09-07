import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppStore: ObservableObject {
    @Published var clients: [Client] = []
    @Published var workBlocks: [WorkBlock] = []
    @Published var activeBlock: ActiveWorkBlock?
    @Published var activeDistraction: ActiveDistraction?
    @Published var distractionPeriods: [DistractionPeriod] = []
    @Published var lastRewardMessage: String?

    init() {
        let state = PersistenceController.shared.load()
        clients = state.clients
        workBlocks = state.workBlocks
        activeBlock = state.activeBlock
        activeDistraction = state.activeDistraction
        distractionPeriods = state.distractionPeriods
    }

    var isDistracted: Bool {
        activeDistraction != nil
    }

    var activeClient: Client? {
        guard let id = activeBlock?.clientID else { return nil }
        return clients.first(where: { $0.id == id })
    }

    var todayBlocks: [WorkBlock] {
        workBlocks.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var todayDistractions: [DistractionPeriod] {
        distractionPeriods.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var distractionSecondsToday: TimeInterval {
        todayDistractions.reduce(0) { $0 + $1.duration } + currentDistractionSeconds
    }

    var recoverySecondsToday: TimeInterval {
        todayBlocks
            .filter { $0.isRecovery }
            .reduce(0) { $0 + $1.focusedSeconds }
    }

    var recoveryBalanceSeconds: TimeInterval {
        max(0, distractionSecondsToday - recoverySecondsToday)
    }

    var currentDistractionSeconds: TimeInterval {
        guard let activeDistraction else { return 0 }
        return max(0, Date().timeIntervalSince(activeDistraction.startedAt))
    }

    var uninvoicedByClient: [(client: Client, blocks: [WorkBlock], billableMinutes: Int)] {
        clients.compactMap { client in
            let blocks = workBlocks.filter {
                $0.clientID == client.id && !$0.invoiced && $0.billableMinutes > 0
            }
            guard !blocks.isEmpty else { return nil }
            return (
                client,
                blocks,
                blocks.reduce(0) { $0 + $1.billableMinutes }
            )
        }
        .sorted { $0.client.name.localizedCaseInsensitiveCompare($1.client.name) == .orderedAscending }
    }

    func addClient(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        clients.append(Client(name: cleaned))
        save()
    }

    func deleteClient(_ client: Client) {
        guard activeBlock?.clientID != client.id else { return }
        clients.removeAll { $0.id == client.id }
        save()
    }

    func startBlock(clientID: UUID?, task: String, isRecovery: Bool = false) {
        guard activeBlock == nil else { return }
        let cleaned = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        activeBlock = ActiveWorkBlock(
            clientID: clientID,
            task: cleaned,
            startedAt: Date(),
            distractionSeconds: 0,
            isRecovery: isRecovery
        )
        activeDistraction = nil
        lastRewardMessage = nil
        save()
    }

    func startDistraction() {
        guard activeBlock != nil, activeDistraction == nil else { return }
        activeDistraction = ActiveDistraction(startedAt: Date())
        save()
    }

    func endDistraction() {
        guard var block = activeBlock,
              let distraction = activeDistraction else { return }

        let now = Date()
        let duration = max(0, now.timeIntervalSince(distraction.startedAt))
        block.distractionSeconds += duration
        activeBlock = block

        distractionPeriods.insert(
            DistractionPeriod(
                startedAt: distraction.startedAt,
                endedAt: now,
                task: block.task
            ),
            at: 0
        )

        activeDistraction = nil
        save()
    }

    func finishBlock(done: Bool) {
        guard var block = activeBlock else { return }

        if activeDistraction != nil {
            endDistraction()
            guard let refreshed = activeBlock else { return }
            block = refreshed
        }

        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(block.startedAt))
        let focused = max(0, elapsed - block.distractionSeconds)
        let billable = block.clientID == nil ? 0 : billableMinutes(for: focused)

        workBlocks.insert(
            WorkBlock(
                id: block.id,
                clientID: block.clientID,
                task: block.task,
                startedAt: block.startedAt,
                endedAt: now,
                distractionSeconds: block.distractionSeconds,
                focusedSeconds: focused,
                billableMinutes: billable,
                result: done ? .done : .stopped,
                invoiced: false,
                isRecovery: block.isRecovery
            ),
            at: 0
        )

        activeBlock = nil
        activeDistraction = nil

        if done {
            lastRewardMessage = "Klaar. Mooi gedaan."
            playRewardSound()
        } else if focused >= 25 * 60 {
            lastRewardMessage = "Goed blok gewerkt. Ook zonder afronden telt dat."
            playRewardSound()
        }

        save()
    }

    func markClientInvoiced(_ client: Client) {
        for index in workBlocks.indices where workBlocks[index].clientID == client.id && !workBlocks[index].invoiced {
            workBlocks[index].invoiced = true
        }
        lastRewardMessage = "Gefactureerd. Uit je hoofd."
        playRewardSound()
        save()
    }

    func deleteBlock(_ block: WorkBlock) {
        workBlocks.removeAll { $0.id == block.id }
        save()
    }

    func clientName(for id: UUID?) -> String {
        guard let id else { return "Niet facturabel" }
        return clients.first(where: { $0.id == id })?.name ?? "Onbekende klant"
    }

    func billableMinutes(for focusedSeconds: TimeInterval) -> Int {
        let minutes = focusedSeconds / 60
        let rounded = Int(ceil(minutes / 15.0)) * 15
        return max(15, rounded)
    }

    private func playRewardSound() {
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func save() {
        PersistenceController.shared.save(
            PersistedState(
                clients: clients,
                workBlocks: workBlocks,
                activeBlock: activeBlock,
                activeDistraction: activeDistraction,
                distractionPeriods: distractionPeriods
            )
        )
    }
}
