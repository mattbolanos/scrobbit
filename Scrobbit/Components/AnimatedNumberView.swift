import SwiftUI

struct AnimatedNumberView: View {
    let value: Int
    let font: Font
    var isSkeleton: Bool = false
    
    @State private var displayedValue: Int = 0
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        if isSkeleton {
            skeletonView
        } else {
            Text(displayedValue.formatted())
                .font(font)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: Double(displayedValue)))
                .onChange(of: value, initial: true) { _, newValue in
                    withAnimation(Theme.Animation.numberCount) {
                        displayedValue = newValue
                    }
                }
        }
    }
    
    private var skeletonView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(
                            color: Color.gray.opacity(0.2),
                            location: max(0, shimmerPhase - 0.3)
                        ),
                        .init(
                            color: Color.gray.opacity(0.4),
                            location: shimmerPhase
                        ),
                        .init(
                            color: Color.gray.opacity(0.2),
                            location: min(1, shimmerPhase + 0.3)
                        )
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 100, height: 28)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = 1
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedNumberView(value: 12345, font: .title, )
        AnimatedNumberView(value: 0, font: .title,  isSkeleton: true)
    }
    .padding()
}
