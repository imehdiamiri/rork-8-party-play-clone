import SwiftUI

// MARK: - Shared Multiplayer UI Contract
// Reusable components used by ALL multiplayer game screens for consistent UX.

struct MultiplayerConnectionBanner: View {
    let state: MultiplayerConnectionState

    var body: some View {
        Group {
            switch state {
            case .connecting:
                banner(icon: "dot.radiowaves.left.and.right", text: "Connecting…", tint: .blue)
            case .reconnecting:
                banner(icon: "arrow.triangle.2.circlepath", text: "Reconnecting…", tint: .orange)
            case .disconnected:
                banner(icon: "wifi.slash", text: "Disconnected", tint: .red)
            case .stale:
                banner(icon: "exclamationmark.triangle.fill", text: "Connection unstable", tint: .yellow)
            case .connected, .idle:
                EmptyView()
            }
        }
        .animation(.snappy, value: state)
    }

    private func banner(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15), in: .capsule)
        .foregroundStyle(tint)
    }
}

struct MultiplayerReadyCheckModal: View {
    let readyCount: Int
    let totalCount: Int
    let localConfirmed: Bool
    let isHost: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Ready Check")
                .font(.title2.bold())
            Text("\(readyCount) / \(totalCount) ready")
                .font(.headline)
                .foregroundStyle(.secondary)
            ProgressView(value: totalCount == 0 ? 0 : Double(readyCount) / Double(totalCount))
                .tint(.green)
                .padding(.horizontal)

            if !localConfirmed {
                Button(action: onConfirm) {
                    Text("I'm Ready")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green, in: .rect(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            } else {
                Label("You are ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            }

            if isHost {
                Button("Cancel", role: .destructive, action: onCancel)
                    .font(.subheadline)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .shadow(radius: 20)
    }
}

struct MultiplayerHostChangedBanner: View {
    let newHostName: String
    var body: some View {
        Label("\(newHostName) is now the host", systemImage: "crown.fill")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.yellow.opacity(0.2), in: .capsule)
            .foregroundStyle(.orange)
    }
}

struct MultiplayerClosedRoomDialog: View {
    let reason: String
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Room Closed").font(.title3.bold())
            Text(reason).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("OK", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }
}

struct MultiplayerActivePlayerIndicator: View {
    let playerName: String
    let isLocal: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill.badge.plus")
            Text(isLocal ? "Your Turn" : "\(playerName)'s Turn")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((isLocal ? Color.green : Color.blue).opacity(0.2), in: .capsule)
        .foregroundStyle(isLocal ? .green : .blue)
    }
}

struct MultiplayerSpectatorOverlay: View {
    let activePlayerName: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "eye.fill").foregroundStyle(.secondary)
            Text("Watching \(activePlayerName)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
    }
}

struct MultiplayerDesyncRecoveryLoader: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Syncing with room…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }
}
