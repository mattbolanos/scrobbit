import SwiftUI

// MARK: - Sync State

enum SyncState: Equatable, Hashable {
    case idle
    case syncing
    case success(count: Int)
    case empty
    case error(message: String)
}

// MARK: - Sync Button (Morphing)

struct SyncButton: View {
    @Binding var state: SyncState
    let action: () async -> Void

    @State private var discRotation: Double = 0
    @State private var resultScale: CGFloat = 0.5

    private var isDisabled: Bool {
        state != .idle
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            ZStack {
                switch state {
                case .idle:
                    idleView
                case .syncing:
                    vinylDisc
                case .success(let count):
                    resultBadge(count: count)
                case .empty:
                    emptyBadge
                case .error:
                    errorBadge
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.3), value: state)
        }
        .disabled(isDisabled)
        .onChange(of: state) { _, newState in
            // Auto-dismiss results
            switch newState {
            case .success, .empty, .error:
                resultScale = 0.5
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
                    resultScale = 1
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.0))
                    if state == newState {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            state = .idle
                        }
                    }
                }
            case .syncing:
                discRotation = 0
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    discRotation = 360
                }
            default:
                break
            }
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        Text("Sync")
            .font(.headline)
            .foregroundStyle(Theme.Colors.accent)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Vinyl Disc

    private var vinylDisc: some View {
        ZStack {
            // Outer disc with gradient
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(.systemGray2),
                            Color(.systemGray4),
                            Color(.systemGray3),
                            Color(.systemGray2)
                        ],
                        center: .center
                    )
                )
                .frame(width: 26, height: 26)

            // Grooves
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                .frame(width: 20, height: 20)

            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                .frame(width: 14, height: 14)

            // Label area (red center)
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 10, height: 10)

            // Spindle hole
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 3, height: 3)
        }
        .rotationEffect(.degrees(discRotation))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Result Badge

    private func resultBadge(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Colors.success)

            Text("\(count) tracks scrobbled")
                .font(.system(size: 14))
                .foregroundStyle(.foreground)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .scaleEffect(resultScale)
        .transition(.scale.combined(with: .opacity))
    }

    private var emptyBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .scaleEffect(resultScale)
            .transition(.scale.combined(with: .opacity))
    }

    private var errorBadge: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14))
            .foregroundStyle(.orange)
            .scaleEffect(resultScale)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("Sync Button States") {
    struct PreviewWrapper: View {
        @State private var state: SyncState = .idle

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Sync Button Preview")
                            .font(.title2)
                            .padding()
                        
                        Text("The sync button appears in the toolbar when both accounts are connected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        SyncButton(state: $state) {
                            state = .syncing
                            try? await Task.sleep(for: .seconds(2))
                            state = .success(count: Int.random(in: 1...8))
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 12) {
                        Text("Test States:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Button("Idle") { state = .idle }
                            Button("Syncing") { state = .syncing }
                            Button("Success") { state = .success(count: 5) }
                            Button("Empty") { state = .empty }
                            Button("Error") { state = .error(message: "Failed") }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
        }
    }
    return PreviewWrapper()
}
