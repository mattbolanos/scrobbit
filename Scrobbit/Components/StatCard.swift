import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    var isSkeleton: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                AnimatedNumberView(
                    value: value,
                    font: .title,
                    color: color,
                    isSkeleton: isSkeleton
                )

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: Theme.Size.cardMinHeight)
        .neutralCardStyle()
    }
}

#Preview {
    StatCard(
        title: "Scrobbles",
        value: 70494,
        icon: "music.quarternote.3",
        color: Theme.Colors.scrobbles
    )
    .frame(width: 180)
    .padding()
    
    StatCard(
        title: "Scrobbles",
        value: 0,
        icon: "music.quarternote.3",
        color: Theme.Colors.scrobbles,
        isSkeleton: true
    )
    .frame(width: 180)
    .padding()
}
