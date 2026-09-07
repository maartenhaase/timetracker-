import SwiftUI

@main
struct MaartenTimeTrackerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 920, height: 640)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            if store.isDistracted {
                Label("Afgeleid", systemImage: "exclamationmark.circle.fill")
            } else if store.activeBlock != nil {
                Label("Bezig", systemImage: "play.circle.fill")
            } else {
                Label("Werk", systemImage: "circle")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
