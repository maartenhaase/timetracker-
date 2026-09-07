import SwiftUI

struct ContentView: View {
    @State private var selection: Section = .work

    enum Section: String, CaseIterable, Identifiable {
        case work = "Werk"
        case clients = "Klanten"
        case billing = "Factureren"
        case history = "Gedaan"
        case distraction = "Afleiding"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .work: return "play.circle"
            case .clients: return "person.2"
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
                case .work:
                    WorkView()
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
            .frame(minWidth: 700, minHeight: 540)
        }
    }
}
