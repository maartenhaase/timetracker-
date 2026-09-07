import SwiftUI

extension View {
    func flowCard() -> some View {
        self
            .padding(18)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 16))
    }
}

func durationText(_ minutes: Int) -> String {
    switch minutes {
    case 15: return "15 min"
    case 30: return "30 min"
    case 45: return "45 min"
    case 60: return "1 uur"
    case 90: return "1,5 uur"
    default:
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) uur" : "\(h)u \(m)m"
    }
}

func minutesText(_ seconds: TimeInterval) -> String {
    let minutes = max(1, Int(ceil(seconds / 60)))
    return durationText(minutes)
}
