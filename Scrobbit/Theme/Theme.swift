import SwiftUI

enum Theme {
    // MARK: - Colors
    
    enum Colors {
        /// Primary accent color used throughout the app
        static let accent = Color.red
        
        /// Success indicator color
        static let success = Color.green
        
        /// Stat card specific colors
        static let scrobbles = Color.red
        static let artists = Color.purple
        static let albums = Color.blue
        static let tracks = Color.green
    }
    
    // MARK: - Opacity
    
    enum Opacity {
        /// Ultra light background (0.05) - for light mode connected states
        static let ultraLight: Double = 0.05
        
        /// Light background (0.08) - for light mode hover/default states
        static let light: Double = 0.08
        
        /// Subtle background (0.1) - for stat card backgrounds
        static let subtle: Double = 0.1
        
        /// Medium background (0.15) - for dark mode backgrounds
        static let medium: Double = 0.15
        
        /// Border opacity (0.3) - for standard borders
        static let border: Double = 0.3
        
        /// Strong border opacity (0.4) - for emphasized borders
        static let borderStrong: Double = 0.4
        
        /// Highlight opacity (0.5) - for success states
        static let highlight: Double = 0.5
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        /// 2pt - Extra extra small spacing
        static let xxs: CGFloat = 2
        
        /// 4pt - Extra small spacing
        static let xs: CGFloat = 4
        
        /// 8pt - Small spacing
        static let sm: CGFloat = 8
        
        /// 12pt - Medium spacing
        static let md: CGFloat = 12
        
        /// 16pt - Large spacing (standard padding)
        static let lg: CGFloat = 16
        
        /// 20pt - Extra large spacing
        static let xl: CGFloat = 20
        
        /// 24pt - Extra extra large spacing
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        /// 8pt - Small radius
        static let sm: CGFloat = 8
        
        /// 14pt - Medium radius (service rows)
        static let md: CGFloat = 14
        
        /// 16pt - Large radius (cards, buttons)
        static let lg: CGFloat = 16
    }
    
    // MARK: - Size
    
    enum Size {
        /// 20pt - Small icon size
        static let iconSmall: CGFloat = 20
        
        /// 24pt - Medium icon size
        static let iconMedium: CGFloat = 24
        
        /// 32pt - Progress indicator size
        static let progressIndicator: CGFloat = 32
        
        /// 44pt - Icon container / touch target size
        static let iconContainer: CGFloat = 44
        
        /// 120pt - Minimum card height
        static let cardMinHeight: CGFloat = 120
        
        /// 50pt - Album artwork size
        static let artwork: CGFloat = 50
    }
    
    // MARK: - Stroke Width
    
    enum StrokeWidth {
        /// 1pt - Thin stroke for subtle borders
        static let thin: CGFloat = 1
        
        /// 1.5pt - Medium stroke for standard borders
        static let medium: CGFloat = 1.5
        
        /// 3pt - Thick stroke for progress indicators
        static let thick: CGFloat = 3
    }
    
    // MARK: - Animation
    
    enum Animation {
        /// Standard spring animation (0.6s, bounce: 0.3)
        static var standard: SwiftUI.Animation {
            .spring(duration: 0.6, bounce: 0.3)
        }
        
        /// Lively spring animation with more bounce (0.6s, bounce: 0.4)
        static var lively: SwiftUI.Animation {
            .spring(duration: 0.6, bounce: 0.4)
        }
        
        /// Number counting animation (0.8s, bounce: 0.3)
        static var numberCount: SwiftUI.Animation {
            .spring(duration: 0.8, bounce: 0.3)
        }
    }
}

// MARK: - Convenience Extensions

extension Color {
    /// Returns the appropriate background opacity for the given color scheme
    static func adaptiveBackground(
        for color: Color,
        colorScheme: ColorScheme,
        isHighlighted: Bool = false
    ) -> Color {
        let opacity = colorScheme == .dark
            ? (isHighlighted ? Theme.Opacity.subtle : Theme.Opacity.medium)
            : (isHighlighted ? Theme.Opacity.ultraLight : Theme.Opacity.light)
        return color.opacity(opacity)
    }
}

extension View {
    /// Applies standard card styling with the given accent color
    func cardStyle(color: Color) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, minHeight: Theme.Size.cardMinHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .fill(color.opacity(Theme.Opacity.subtle))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(color.opacity(Theme.Opacity.border), lineWidth: Theme.StrokeWidth.thin)
            )
    }
    
    /// Applies service row styling
    func serviceRowStyle(
        color: Color,
        colorScheme: ColorScheme,
        isConnected: Bool
    ) -> some View {
        self
            .padding()
            .background(
                colorScheme == .dark
                    ? color.opacity(isConnected ? Theme.Opacity.subtle : Theme.Opacity.medium)
                    : color.opacity(isConnected ? Theme.Opacity.ultraLight : Theme.Opacity.light)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                    .stroke(
                        isConnected ? Theme.Colors.success.opacity(Theme.Opacity.highlight) : color.opacity(Theme.Opacity.border),
                        lineWidth: Theme.StrokeWidth.medium
                    )
            )
    }
    
    /// Applies action button styling (like the connect accounts button)
    func actionButtonStyle(
        color: Color,
        colorScheme: ColorScheme
    ) -> some View {
        self
            .padding()
            .background(
                colorScheme == .dark
                    ? color.opacity(Theme.Opacity.medium)
                    : color.opacity(Theme.Opacity.light)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(color.opacity(Theme.Opacity.borderStrong), lineWidth: Theme.StrokeWidth.medium)
            )
    }
    
    /// Applies a shimmer loading effect
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.3 + phase * geometry.size.width * 1.6)
                    .blendMode(.sourceAtop)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

