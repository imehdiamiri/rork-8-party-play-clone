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

    @State private var showRematchReadyPrompt: Bool = false
    @State private var didAutoPromptForThisRequest: Bool = false

    private var me: UUID? { appModel.sessionPlayerID }

    private var isHost: Bool {
        guard let pid = me else { return false }
        return session.players.first(where: { $0.id == pid })?.isHost ?? false
    }

    private var hasVoted: Bool { appModel.hasVotedRematch }

    private var hostPlayer: PlayerProfile? {
        session.players.first(where: { $0.isHost })
    }

    private var hostHasRequested: Bool {
        guard let host = hostPlayer else { return false }
        return session.rematchPlayerIDs.contains(host.id)
    }

    private var exitedIDs: Set<UUID> { appModel.sessionExitedPlayerIDs }
    private var onlineIDs: Set<UUID> { appModel.sessionOnlinePlayerIDs }

    private var exitedOpponents: [PlayerProfile] {
        session.players.filter { $0.id != me && exitedIDs.contains($0.id) }
    }

    private var canRematch: Bool { exitedOpponents.isEmpty }

    private var remainingOpponents: [PlayerProfile] {
        session.players.filter { !$0.isHost && !exitedIDs.contains($0.id) }
    }

    private var readyOpponentsCount: Int {
        let set = Set(session.rematchPlayerIDs)
        return remainingOpponents.filter { set.contains($0.id) }.count
    }

    private func connectionStatus(for player: PlayerProfile) -> (color: Color, text: String, icon: String) {
        if exitedIDs.contains(player.id) {
            return (.red, "Exited", "rectangle.portrait.and.arrow.right")
        }
        if onlineIDs.isEmpty || onlineIDs.contains(player.id) {
            return (.green, "Online", "dot.radiowaves.left.and.right")
        }
        return (.orange, "Reconnecting…", "wifi.exclamationmark")
    }

    var body: some View {
        VStack(spacing: 14) {
            playerStatusCard

            if !canRematch {
                exitedBanner
                exitButton
            } else {
                actionButtons
                rematchProgressSection
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: hostHasRequested) { _, requested in
            if requested, !isHost, !hasVoted, !didAutoPromptForThisRequest {
                didAutoPromptForThisRequest = true
                showRematchReadyPrompt = true
            }
            if !requested { didAutoPromptForThisRequest = false }
        }
        .alert("Rematch?", isPresented: $showRematchReadyPrompt) {
            Button("Ready up") { appModel.voteForRematch() }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("The host wants a rematch. Ready up to start the next round.")
        }
    }

    private var playerStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Players", systemImage: "person.2.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(session.players) { p in
                let status = connectionStatus(for: p)
                let isReadyForRematch = session.rematchPlayerIDs.contains(p.id)
                HStack(spacing: 10) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    Text(p.username)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if p.isHost {
                        Text("Host")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.yellow.opacity(0.2), in: .capsule)
                            .foregroundStyle(.yellow)
                    }
                    Spacer(minLength: 0)
                    if exitedIDs.contains(p.id) {
                        Label("Exited", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    } else if isReadyForRematch {
                        Label("Ready", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Label(status.text, systemImage: status.icon)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(status.color)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.035), in: .rect(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 14))
    }

    private var exitedBanner: some View {
        let names = exitedOpponents.map(\.username).joined(separator: ", ")
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.fill.xmark")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(exitedOpponents.count > 1 ? "Players exited" : "Player exited")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                Text("\(names) left the game. Rematch is no longer available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.red.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.red.opacity(0.25))
        }
    }

    private var exitButton: some View {
        Button {
            onExit()
            Task { await appModel.exitActiveSession() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Exit Room").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.22), in: .rect(cornerRadius: 14))
            .foregroundStyle(.red)
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(.red.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if !hasVoted { appModel.voteForRematch() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasVoted ? "checkmark.circle.fill" : "arrow.clockwise")
                    Text(rematchButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: hasVoted ? [.green.opacity(0.5), .mint.opacity(0.5)] : [.green, .mint], startPoint: .leading, endPoint: .trailing),
                    in: .rect(cornerRadius: 14)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(hasVoted)

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
    }

    private var rematchButtonTitle: String {
        if isHost {
            return hasVoted ? "Waiting for players…" : "Rematch"
        }
        if hasVoted { return "Ready…" }
        if hostHasRequested { return "Ready up" }
        return "Request Rematch"
    }

    @ViewBuilder
    private var rematchProgressSection: some View {
        if hasVoted || hostHasRequested {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if !remainingOpponents.isEmpty {
                    ProgressView(value: Double(readyOpponentsCount), total: Double(remainingOpponents.count))
                        .tint(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
        }
    }

    private var progressText: String {
        if isHost {
            return "Waiting for players to ready up • \(readyOpponentsCount)/\(remainingOpponents.count)"
        }
        if hasVoted {
            return "Waiting for other players… \(readyOpponentsCount)/\(remainingOpponents.count)"
        }
        return "Host wants a rematch • tap Ready up to join"
    }
}
