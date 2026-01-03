import SwiftUI

struct AccountRow<Icon: View>: View {
    let icon: () -> Icon
    let title: String
    let subtitle: String
    let accentColor: Color
    let isConnected: Bool
    let isConnecting: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon container
            ZStack {
                Circle()
                    .fill(accentColor.opacity(Theme.Opacity.medium))
                    .frame(width: Theme.Size.iconContainer, height: Theme.Size.iconContainer)
                
                icon()
            }
            
            // Text content
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            if isConnecting {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isConnected {
                Text("Disconnect")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                Text("Connect")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.md + Theme.Spacing.xxs)
                    .padding(.vertical, 6)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}