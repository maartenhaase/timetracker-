import SwiftUI

struct ContentView: View {
    @State private var selection: Section = .today

    enum Section: String, CaseIterable, Identifiable {
        case today = "Vandaag"
        case clients = "Klanten & projecten"
        case billing = "Factureren"
        case done = "Gedaan"
        case health = "Gezondheid"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .clients: return "folder"
            case .billing: return "bag"
            case .done: return "checkmark.circle"
            case .health: return "heart.text.clipboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Maarten Flow")
        } detail: {
            Group {
                switch selection {
                case .today:
                    TodayView()
                case .clients:
                    ClientsProjectsView()
                case .billing:
                    BillingView()
                case .done:
                    DoneView()
                case .health:
                    HealthView()
                }
            }
            .frame(minWidth: 780, minHeight: 620)
        }
    }
}
