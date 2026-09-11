import SwiftUI

struct MoodBar: View {
    let title: String
    let emoji: String
    let value: Int        // 0...100
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(emoji) \(title)")
                    .font(.cute(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(value)")
                    .font(.cute(14))
                    .foregroundStyle(Theme.soft)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: max(14, geo.size.width * CGFloat(value) / 100))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
                }
            }
            .frame(height: 14)
        }
    }
}
