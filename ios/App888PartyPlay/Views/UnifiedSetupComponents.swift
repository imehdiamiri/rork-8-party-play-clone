import SwiftUI

struct SetupPlayersSection: View {
    @Binding var playerCount: Int
    @Binding var playerNames: [String]
    let minPlayers: Int
    let maxPlayers: Int
    let offlineFriends: [Friend]

    private func updatePlayerCount(_ newCount: Int) {
        withAnimation(.spring(duration: 0.2)) {
            playerCount = newCount
            if newCount > playerNames.count {
                playerNames.append(contentsOf: Array(repeating: "", count: newCount - playerNames.count))
            } else {
                playerNames = Array(playerNames.prefix(newCount))
            }
        }
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("Players", systemImage: "person.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                    Spacer(minLength: 0)
                    Button {
                        FeedbackService.shared.playClick()
                        if playerCount > minPlayers { updatePlayerCount(playerCount - 1) }
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(.green.opacity(0.12), in: .circle)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(playerCount <= minPlayers)
                    .opacity(playerCount <= minPlayers ? 0.3 : 1)

                    Text("\(playerCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                        .frame(minWidth: 28)

                    Button {
                        FeedbackService.shared.playClick()
                        if playerCount < maxPlayers { updatePlayerCount(playerCount + 1) }
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(.green.opacity(0.12), in: .circle)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(playerCount >= maxPlayers)
                    .opacity(playerCount >= maxPlayers ? 0.3 : 1)
                }

                VStack(spacing: 6) {
                    ForEach(Array(playerNames.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(GamePlayerColor.color(for: index))
                                .frame(width: 20, height: 20)
                                .background(GamePlayerColor.color(for: index).opacity(0.15), in: .circle)

                            TextField("Player \(index + 1)", text: Binding(
                                get: { playerNames[index] },
                                set: { playerNames[index] = $0 }
                            ))
                            .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.05), in: .rect(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.white.opacity(0.05))
                        }
                    }
                }

                if !offlineFriends.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(offlineFriends) { friend in
                                Button {
                                    FeedbackService.shared.playClick()
                                    addOfflineFriend(friend.name)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "person.fill")
                                            .font(.caption2)
                                        Text(friend.name)
                                            .font(.caption.weight(.medium))
                                        if friend.status == "Me" {
                                            Text("me")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.blue)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(.blue.opacity(0.18), in: .capsule)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(.white.opacity(0.06), in: .capsule)
                                    .overlay {
                                        Capsule().strokeBorder(.white.opacity(0.08))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)
                }
            }
        }
    }

    private func addOfflineFriend(_ name: String) {
        if let emptyIndex = playerNames.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            playerNames[emptyIndex] = name
        } else if playerCount < maxPlayers {
            playerCount += 1
            playerNames.append(name)
        }
    }
}

struct SetupRoundsSection: View {
    @Binding var roundCount: Int
    let range: ClosedRange<Int>

    init(roundCount: Binding<Int>, range: ClosedRange<Int> = 1...10) {
        _roundCount = roundCount
        self.range = range
    }

    var body: some View {
        SurfaceCard {
            HStack(spacing: 10) {
                Label("Rounds", systemImage: "repeat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer(minLength: 0)
                Button {
                    FeedbackService.shared.playClick()
                    if roundCount > range.lowerBound { withAnimation(.spring(duration: 0.2)) { roundCount -= 1 } }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(.orange.opacity(0.12), in: .circle)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(roundCount <= range.lowerBound)
                .opacity(roundCount <= range.lowerBound ? 0.3 : 1)

                Text("\(roundCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                    .frame(minWidth: 28)

                Button {
                    FeedbackService.shared.playClick()
                    if roundCount < range.upperBound { withAnimation(.spring(duration: 0.2)) { roundCount += 1 } }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(.orange.opacity(0.12), in: .circle)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(roundCount >= range.upperBound)
                .opacity(roundCount >= range.upperBound ? 0.3 : 1)
            }
        }
    }
}

struct SetupTimerSection: View {
    let title: String
    let icon: String
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    let step: Int

    init(title: String, icon: String = "timer", seconds: Binding<Int>, range: ClosedRange<Int>, step: Int = 10) {
        self.title = title
        self.icon = icon
        _seconds = seconds
        self.range = range
        self.step = step
    }

    var body: some View {
        SurfaceCard {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.cyan)
                Spacer(minLength: 0)
                Button {
                    FeedbackService.shared.playClick()
                    let newVal = seconds - step
                    if newVal >= range.lowerBound { withAnimation(.spring(duration: 0.2)) { seconds = newVal } }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(.cyan.opacity(0.12), in: .circle)
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .disabled(seconds <= range.lowerBound)
                .opacity(seconds <= range.lowerBound ? 0.3 : 1)

                HStack(spacing: 3) {
                    Text("\(seconds)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.cyan)
                        .contentTransition(.numericText())
                    Text("s")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan.opacity(0.7))
                }
                .frame(minWidth: 42)

                Button {
                    FeedbackService.shared.playClick()
                    let newVal = seconds + step
                    if newVal <= range.upperBound { withAnimation(.spring(duration: 0.2)) { seconds = newVal } }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(.cyan.opacity(0.12), in: .circle)
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .disabled(seconds >= range.upperBound)
                .opacity(seconds >= range.upperBound ? 0.3 : 1)
            }
        }
    }
}

struct HowToPlayButton: View {
    let game: GameType
    let language: AppLanguage
    @State private var isShowing: Bool = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                Text("How to Play")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.blue.opacity(0.12), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.blue.opacity(0.25))
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowing) {
            HowToPlaySheet(game: game, language: language)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }
}

struct HowToPlaySheet: View {
    let game: GameType
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: game.symbolName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.blue, in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(game.name)
                                .font(.title3.weight(.bold))
                            Text(game.playerCountText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("How it works")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(GameLocalizer.gameInstructions(game, language: language).enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 26, height: 26)
                                    .background(.blue.opacity(0.14), in: .circle)
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct SetupStartButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let disabled: Bool
    let action: () -> Void

    init(title: String = "Start Game", subtitle: String = "", icon: String = "play.fill", tint: Color = .blue, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button {
            FeedbackService.shared.playRoundStart()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint.opacity(disabled ? 0.3 : 0.88), in: .rect(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct SetupChipPicker<T: Identifiable & Hashable>: View {
    let title: String
    let icon: String
    let items: [T]
    @Binding var selected: T
    let label: (T) -> String
    let tint: Color

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.purple)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.25)) { selected = item }
                            } label: {
                                Text(label(item))
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(selected == item ? tint.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                    .foregroundStyle(selected == item ? tint : .secondary)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selected == item ? tint.opacity(0.5) : .white.opacity(0.06))
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }
}
