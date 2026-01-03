import SwiftUI

struct AnimatedNumberView: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var displayedValue: Int = 0
    
    var body: some View {
        Text(displayedValue.formatted())
            .font(font)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(displayedValue)))
            .onChange(of: value, initial: true) { _, newValue in
                withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                    displayedValue = newValue
                }
            }
    }
}

#Preview {
    AnimatedNumberView(value: 12345, font: .title, color: .primary)
}

