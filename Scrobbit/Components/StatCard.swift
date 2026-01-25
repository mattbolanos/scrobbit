import SwiftUI

struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let value: Int
    let icon: String
    var isSkeleton: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? .gray.opacity(0.08) : Color(.systemGray5).opacity(0.3))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.accent)
                }

                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                AnimatedNumberView(
                    value: value,
                    font: .title,
                    color: .primary,
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
        icon: "music.quarternote.3"
    )
    .frame(width: 180)
    .padding()
    
    StatCard(
        title: "Scrobbles",
        value: 0,
        icon: "music.quarternote.3",
        isSkeleton: true
    )
    .frame(width: 180)
    .padding()
}
