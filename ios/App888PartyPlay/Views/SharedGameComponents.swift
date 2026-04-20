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
