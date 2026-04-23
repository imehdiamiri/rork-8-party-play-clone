import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.45, 0.45], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    .black, .indigo.opacity(0.68), .black,
                    .purple.opacity(0.42), .blue.opacity(0.28), .mint.opacity(0.18),
                    .black, .black, .teal.opacity(0.12)
                ]
            )
            .opacity(0.82)
            .blur(radius: 52)
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.05))
            }
    }
}

struct SectionHeaderView: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .viralTitleStyle(size: 20, weight: .black)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MetricChipView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.045), in: .capsule)
    }
}

struct StatusPillView: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: .capsule)
    }
}

struct InlineActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.blue.opacity(configuration.isPressed ? 0.7 : 0.88), in: .rect(cornerRadius: 14))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.smooth, value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.04 : 0.065), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.05))
            }
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.smooth, value: configuration.isPressed)
    }
}

struct ProfileToolbarButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var imageData: Data? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 34, height: 34)
                .overlay {
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(.circle)
                            .allowsHitTesting(false)
                    } else {
                        Image(systemName: systemImage)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct GameOverflowMenuLabel: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.08))
            }
            .overlay {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
            }
    }
}

struct GameTopBarMenu: View {
    let primaryTitle: String
    let primarySystemImage: String
    let confirmButtonTitle: String
    let onPrimaryAction: (() -> Void)?
    let onConfirmExit: () -> Void

    var body: some View {
        Menu {
            if let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                }
            }

            Button(role: .destructive, action: onConfirmExit) {
                Label(confirmButtonTitle, systemImage: "xmark.circle")
            }
        } label: {
            GameOverflowMenuLabel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Game menu")
    }
}

extension View {
    func gameTopBarMenu(
        primaryTitle: String,
        primarySystemImage: String,
        confirmationTitle: String,
        confirmationMessage: String,
        confirmButtonTitle: String,
        onPrimaryAction: (() -> Void)? = nil,
        onConfirmExit: @escaping () -> Void
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GameTopBarMenu(
                    primaryTitle: primaryTitle,
                    primarySystemImage: primarySystemImage,
                    confirmButtonTitle: confirmButtonTitle,
                    onPrimaryAction: onPrimaryAction,
                    onConfirmExit: onConfirmExit
                )
            }
        }
    }
}


struct PlayerBadgeView: View {
    let player: PlayerProfile

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                Text(String(player.username.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(player.isOnline ? .green : .gray)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.6), lineWidth: 2)
                    }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(player.username)
                        .font(.subheadline.weight(.semibold))
                    if player.isHost {
                        StatusPillView(title: "Host", systemImage: "crown.fill", tint: .blue)
                    }
                }
                HStack(spacing: 6) {
                    StatusPillView(title: player.isReady ? "Ready" : "Waiting", systemImage: player.isReady ? "checkmark.circle.fill" : "clock.fill", tint: player.isReady ? .green : .orange)
                    if !player.isOnline {
                        StatusPillView(title: "Offline", systemImage: "moon.fill", tint: .gray)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: player.isReady ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundStyle(player.isReady ? .green : .secondary)
        }
        .padding(10)
        .background(.white.opacity(0.035), in: .rect(cornerRadius: 14))
    }
}
