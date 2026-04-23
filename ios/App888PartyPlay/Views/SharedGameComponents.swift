import SwiftUI

nonisolated enum GamePlayerColor {
    static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .cyan, .mint, .yellow, .red, .indigo, .teal, .brown
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func color(for playerName: String, in players: [PlayerProfile]) -> Color {
        guard let idx = players.firstIndex(where: { $0.username == playerName }) else { return .primary }
        return color(for: idx)
    }

    static func color(for playerID: UUID, in players: [PlayerProfile]) -> Color {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else { return .primary }
        return color(for: idx)
    }
}

struct GamePassPhoneView: View {
    let playerName: String
    let subtitle: String
    let accentColor: Color
    let buttonTitle: String
    let onReady: () -> Void

    init(
        playerName: String,
        subtitle: String = "Make sure no one else is looking!",
        accentColor: Color = .yellow,
        buttonTitle: String = "I'm Ready",
        onReady: @escaping () -> Void
    ) {
        self.playerName = playerName
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.buttonTitle = buttonTitle
        self.onReady = onReady
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 96, height: 96)
                    .background(accentColor.opacity(0.14), in: .rect(cornerRadius: 28))

                VStack(spacing: 10) {
                    Text("Pass the phone to")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    CurrentTurnPill(playerName: playerName, accent: .green)
                        .scaleEffect(1.2)
                        .padding(.vertical, 4)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            Spacer()
            Button(buttonTitle) {
                onReady()
            }
            .buttonStyle(GameActionButtonStyle(color: accentColor))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: playerName)
    }
}

struct GameActivePlayerBanner: View {
    let playerName: String
    let playerColor: Color
    let roundText: String
    let statusText: String
    let statusIcon: String
    let statusTint: Color

    var body: some View {
        SurfaceCard {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 7, height: 7)
                    Text(roundText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(playerName)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(playerColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                StatusPillView(title: statusText, systemImage: statusIcon, tint: statusTint)
            }
        }
    }
}

struct GamePlayerAvatar: View {
    let name: String
    let color: Color
    let size: CGFloat

    init(name: String, color: Color = .white.opacity(0.08), size: CGFloat = 34) {
        self.name = name
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

struct GamePlayerRow: View {
    let name: String
    let color: Color
    let trailing: String?

    init(name: String, color: Color, trailing: String? = nil) {
        self.name = name
        self.color = color
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            GamePlayerAvatar(name: name, color: color, size: 32)
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GameActionButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = .blue) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.65 : 0.88), in: .rect(cornerRadius: 16))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct CurrentTurnPill: View {
    let playerName: String
    var prefix: String? = nil
    var accent: Color = .green

    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .opacity(pulse ? 0.3 : 1.0)
            if let prefix {
                Text(prefix)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(playerName)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(accent.opacity(pulse ? 0.55 : 0.85))
        )
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: accent.opacity(pulse ? 0.0 : 0.55), radius: pulse ? 2 : 10, y: 0)
        .scaleEffect(pulse ? 0.98 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .sensoryFeedback(.selection, trigger: playerName)
    }
}

struct GameRoundBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.08), in: .capsule)
            .foregroundStyle(.secondary)
    }
}

struct MultiplayerResultActionsBar: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    private var isHost: Bool {
        guard let pid = appModel.sessionPlayerID else { return false }
        return session.players.first(where: { $0.id == pid })?.isHost ?? false
    }

    private var hasVoted: Bool { appModel.hasVotedRematch }

    private var voters: [PlayerProfile] {
        session.players.filter { session.rematchPlayerIDs.contains($0.id) }
    }

    private var nonHostVoters: [PlayerProfile] {
        voters.filter { !$0.isHost }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if isHost {
                        appModel.startRematch()
                    } else if !hasVoted {
                        appModel.voteForRematch()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(isHost ? "Rematch" : (hasVoted ? "Waiting for host…" : "Rematch"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing),
                        in: .rect(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!isHost && hasVoted)

                Button {
                    onExit()
                    Task { await appModel.exitActiveSession() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Exit").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red.opacity(0.18), in: .rect(cornerRadius: 14))
                    .foregroundStyle(.red)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(.red.opacity(0.35))
                    }
                }
                .buttonStyle(.plain)
            }

            if isHost, !nonHostVoters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ready for rematch", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    ForEach(nonHostVoters) { p in
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.green)
                            Text(p.username)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.08), in: .rect(cornerRadius: 10))
                    }
                }
                .padding(12)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 14))
            } else if !isHost, hasVoted {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Waiting for host to start rematch…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
    }
}
