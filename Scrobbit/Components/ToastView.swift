import SwiftUI

/// A toast notification that appears from the top of the screen
struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.success)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.Colors.success.opacity(Theme.Opacity.border), lineWidth: Theme.StrokeWidth.thin)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

/// A view modifier that shows a toast notification
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ToastView(message: message, icon: icon)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(Theme.Animation.standard) {
                                    isPresented = false
                                }
                            }
                        }
                }
            }
            .animation(Theme.Animation.standard, value: isPresented)
    }
}

extension View {
    /// Shows a toast notification
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", duration: TimeInterval = 2.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, duration: duration))
    }
}

#Preview {
    VStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(isPresented: .constant(true), message: "Scrobbled 5 new tracks")
}
