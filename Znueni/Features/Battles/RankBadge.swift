import SwiftUI

/// Medal for ranks 1-3, plain number for the rest.
struct RankBadge: View {
    let rank: Int

    var body: some View {
        if rank <= 3 {
            Image(systemName: "medal.fill")
                .font(.title3)
                .foregroundStyle(medalColor)
        } else {
            Text("\(rank).")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var medalColor: Color {
        switch rank {
        case 1: return Color(red: 0.95, green: 0.75, blue: 0.1)
        case 2: return Color(red: 0.65, green: 0.66, blue: 0.69)
        default: return Color(red: 0.72, green: 0.46, blue: 0.25)
        }
    }
}
