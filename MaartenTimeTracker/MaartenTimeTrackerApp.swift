import SwiftUI

@main
struct MaartenTimeTrackerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 980, height: 720)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            if store.isDistracted {
                Label("Afgeleid", systemImage: "exclamationmark.circle.fill")
            } else if store.activeBlock != nil {
                Label("Flow", systemImage: "play.circle.fill")
            } else if !store.parkedItems.isEmpty {
                Label("Geparkeerd", systemImage: "pause.circle.fill")
            } else if store.isTodayClosed {
                Label("Gesloten", systemImage: "checkmark.seal")
            } else {
                Label("Flow", systemImage: "circle")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
