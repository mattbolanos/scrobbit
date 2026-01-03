import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
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
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                appeared = true
            }
        }
    }
}

#Preview {
    StatCard(
        title: "Scrobbles",
        value: 70494,
        icon: "music.note",
        color: .red
    )
    .frame(width: 180)
    .padding()
}

