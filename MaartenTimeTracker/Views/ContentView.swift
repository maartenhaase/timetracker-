import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection: Section = .today

    enum Section: String, CaseIterable, Identifiable {
        case today = "Vandaag"
        case timer = "Timer"
        case focus = "Focus"
        case activity = "Appgebruik"
        case projects = "Klanten & projecten"
        case history = "Uren"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .timer: return "timer"
            case .focus: return "scope"
            case .activity: return "macwindow"
            case .projects: return "folder"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Maarten Time")
        } detail: {
            Group {
                switch selection {
                case .today:
                    TodayView()
                case .timer:
                    TimerDashboardView()
                case .focus:
                    FocusView()
                case .activity:
                    ActivityView()
                case .projects:
                    ProjectsView()
                case .history:
                    HistoryView()
                }
            }
            .frame(minWidth: 740, minHeight: 560)
        }
    }
}
