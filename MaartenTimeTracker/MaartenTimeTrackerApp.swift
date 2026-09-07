import SwiftUI

@main
struct MaartenTimeTrackerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 980, height: 650)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            if let timer = store.runningTimer {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Label(shortDuration(context.date.timeIntervalSince(timer.startedAt)), systemImage: "timer")
                }
            } else {
                Label("Time", systemImage: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func shortDuration(_ value: TimeInterval) -> String {
        let totalMinutes = max(0, Int(value) / 60)
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }
}
