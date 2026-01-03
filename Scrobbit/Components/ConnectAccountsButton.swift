import SwiftUI

struct ConnectAccountsButton: View {
    @Environment(\.colorScheme) var colorScheme
    
    let connectedCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(Theme.Opacity.medium))
                        .frame(width: Theme.Size.iconContainer, height: Theme.Size.iconContainer)
                    
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: Theme.Size.iconSmall, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Connect Accounts")
                        .font(.headline)
                    
                    Text("Link your music services")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(Theme.Opacity.border), lineWidth: Theme.StrokeWidth.thick)
                        .frame(width: Theme.Size.progressIndicator, height: Theme.Size.progressIndicator)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(connectedCount) / 2.0)
                        .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: Theme.StrokeWidth.thick, lineCap: .round))
                        .frame(width: Theme.Size.progressIndicator, height: Theme.Size.progressIndicator)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(connectedCount)/2")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.footnote.weight(.semibold))
            }
            .actionButtonStyle(color: Theme.Colors.accent, colorScheme: colorScheme)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        ConnectAccountsButton(connectedCount: 0) {
            print("Connect accounts")
        }
        
        ConnectAccountsButton(connectedCount: 1) {
            print("Connect accounts")
        }
        
        ConnectAccountsButton(connectedCount: 2) {
            print("Connect accounts")
        }
    }
    .padding()
}

