import SwiftUI

struct AnimatedNumberView: View {
    let value: Int
    let font: Font
    var isSkeleton: Bool = false

    @State private var displayedValue: Int = 0
    @State private var shimmerPhase: CGFloat = 0

    private let animationDuration: Double = 0.5
    private let steps: Int = 12

    var body: some View {
        if isSkeleton {
            skeletonView
        } else {
            Text(displayedValue.formatted())
                .font(font)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .onChange(of: value, initial: true) { _, newValue in
                    animateToValue(newValue)
                }
        }
    }

    private func animateToValue(_ target: Int) {
        let startValue = displayedValue
        let delta = target - startValue

        guard delta != 0 else { return }

        let stepDuration = animationDuration / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                // Ease-out curve: faster at start, slower at end
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3)
                displayedValue = startValue + Int(Double(delta) * easedProgress)
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
            .frame(width: 100, height: 32)
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
    HStack(spacing: 20) {
        AnimatedNumberView(value: 12345, font: .title, )
        AnimatedNumberView(value: 0, font: .title,  isSkeleton: true)
    }
    .padding()
}
