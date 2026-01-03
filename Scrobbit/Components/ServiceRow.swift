import SwiftUI

struct ServiceRow<Icon: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: () -> Icon
    let serviceName: String
    let statusText: String
    let isConnected: Bool
    let isConnecting: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon container
            ZStack {
                Circle()
                    .fill(accentColor.opacity(
                        colorScheme == .dark ? Theme.Opacity.medium : Theme.Opacity.subtle
                    ))
                    .frame(width: Theme.Size.iconContainer, height: Theme.Size.iconContainer)
                
                icon()
            }
            
            // Text content
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(serviceName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            if isConnecting {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.success)
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
        .serviceRowStyle(color: accentColor, colorScheme: colorScheme, isConnected: isConnected)
    }
}

#Preview {
    VStack(spacing: 16) {
        ServiceRow(
            icon: {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.accent)
            },
            serviceName: "Apple Music",
            statusText: "Not connected",
            isConnected: false,
            isConnecting: false,
            accentColor: Theme.Colors.accent
        )
        
        ServiceRow(
            icon: {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.accent)
            },
            serviceName: "Apple Music",
            statusText: "Connected",
            isConnected: true,
            isConnecting: false,
            accentColor: Theme.Colors.accent
        )
        
        ServiceRow(
            icon: {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.accent)
            },
            serviceName: "Apple Music",
            statusText: "Connecting...",
            isConnected: false,
            isConnecting: true,
            accentColor: Theme.Colors.accent
        )
    }
    .padding()
}

