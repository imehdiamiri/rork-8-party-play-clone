import SwiftUI

struct OtherFunListView: View {
    @State private var expandedID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(
                title: "Party Game Ideas",
                subtitle: nil
            )

            ForEach(Array(PartyGameTutorial.allGames.enumerated()), id: \.element.id) { index, game in
                PartyGameCard(
                    game: game,
                    isExpanded: expandedID == game.id,
                    toggle: {
                        withAnimation(.spring(duration: 0.32, bounce: 0.14)) {
                            expandedID = expandedID == game.id ? nil : game.id
                        }
                    }
                )
                .slideUpOnAppear(delay: Double(index) * 0.035)
            }
        }
    }
}

struct PartyGameCard: View {
    let game: PartyGameTutorial
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: game.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(game.tint)
                        .frame(width: 48, height: 48)
                        .background(game.tint.opacity(0.15), in: .rect(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(game.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(game.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                if isExpanded {
                    expandedContent
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isExpanded ? game.tint.opacity(0.2) : .white.opacity(0.05))
            }
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("How to Play", systemImage: "play.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(game.tint)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(game.howToPlay.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(game.tint)
                                .frame(width: 20, height: 20)
                                .background(game.tint.opacity(0.12), in: .circle)
                            Text(step)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }

            if !game.rules.isEmpty {
                Divider().overlay(.white.opacity(0.06))

                VStack(alignment: .leading, spacing: 6) {
                    Label("Rules", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)

                    ForEach(game.rules, id: \.self) { rule in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange.opacity(0.7))
                                .frame(width: 20, height: 16)
                            Text(rule)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
}
