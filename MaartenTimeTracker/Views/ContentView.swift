import SwiftUI

struct ContentView: View {
    @State private var selection: Section = .today

    enum Section: String, CaseIterable, Identifiable {
        case today = "Vandaag"
        case clients = "Klanten & projecten"
        case billing = "Factureren"
        case history = "Gedaan"
        case distraction = "Afleiding"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .clients: return "folder"
            case .billing: return "bag"
            case .history: return "checkmark.circle"
            case .distraction: return "arrow.uturn.backward.circle"
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
                    TodayWorkView()
                case .clients:
                    ClientsView()
                case .billing:
                    BillingView()
                case .history:
                    DoneView()
                case .distraction:
                    DistractionView()
                }
            }
            .frame(minWidth: 760, minHeight: 580)
        }
    }
}
