import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection: Section = .timer

    enum Section: String, CaseIterable, Identifiable {
        case timer = "Timer"
        case projects = "Klanten & projecten"
        case finalCut = "Final Cut"
        case history = "Uren"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .timer: return "timer"
            case .projects: return "folder"
            case .finalCut: return "film"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }
            .navigationTitle("Maarten Time")
        } detail: {
            Group {
                switch selection {
                case .timer: TimerDashboardView()
                case .projects: ProjectsView()
                case .finalCut: FinalCutView()
                case .history: HistoryView()
                }
            }
            .frame(minWidth: 700, minHeight: 520)
        }
    }
}
