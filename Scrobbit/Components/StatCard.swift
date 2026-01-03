import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    @State private var appeared = false
    
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
                    value: appeared ? value : 0,
                    font: .title,
                    color: .primary
                )
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle(color: color)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Theme.Animation.lively) {
                appeared = true
            }
        }
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
}
