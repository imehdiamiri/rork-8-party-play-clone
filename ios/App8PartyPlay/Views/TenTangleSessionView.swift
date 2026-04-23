import SwiftUI

struct TenTangleSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onDismiss: () -> Void

    @State private var vm: TenTangleViewModel
    @State private var numberRevealVisible: Bool = false
    @State private var scenarioRevealed: Bool = false

    init(appModel: AppViewModel, session: GameSession, onDismiss: @escaping () -> Void) {
        self.appModel = appModel
        self.session = session
        self.onDismiss = onDismiss
        _vm = State(initialValue: TenTangleViewModel(players: session.players))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            Group {
                switch vm.phase {
                case .setup:
                    EmptyView()
                case .guesserAnnounce:
                    guesserAnnounceView
                case .passToPlayer(let idx):
                    passToPlayerView(index: idx)
                case .showNumber(let idx):
                    showNumberView(index: idx)
                case .scenarioReveal:
                    scenarioRevealView
                case .acting:
                    actingView
                case .guesserGuessing:
                    guessingView
                case .roundReveal:
                    roundRevealView
                case .scoreboard:
                    scoreboardView
                case .finalResults:
                    finalResultsView
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: vm.phase)
        }
        .navigationTitle("Ten Tangle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            vm.startGame()
        }
    }

    // MARK: - Guesser Announce

    private var guesserAnnounceView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                roundBadge

                Text("🎯")
                    .font(.system(size: 64))

                Text("Guesser This Round")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                CurrentTurnPill(playerName: vm.currentGuesser.username, prefix: "Guesser", accent: .green)
                    .scaleEffect(1.2)

                Text("Look away while others get their secret numbers!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button("Ready — Start Passing") {
                FeedbackService.shared.playRoundStart()
                vm.proceedToNumberAssignment()
            }
            .buttonStyle(GameActionButtonStyle(color: .blue))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Pass to Player

    private func passToPlayerView(index: Int) -> some View {
        let nonGuessers = vm.nonGuesserPlayers
        let player = nonGuessers[index]
        let playerColor = GamePlayerColor.color(for: player.id, in: session.players)
        return GamePassPhoneView(
            playerName: player.username,
            subtitle: "Make sure the guesser isn't looking!",
            accentColor: playerColor,
            buttonTitle: "I'm \(player.username) — Show My Number"
        ) {
            numberRevealVisible = false
            vm.showPlayerNumber()
            withAnimation(.spring(duration: 0.4)) {
                numberRevealVisible = true
            }
        }
    }

    // MARK: - Show Number

    private func showNumberView(index: Int) -> some View {
        let nonGuessers = vm.nonGuesserPlayers
        let player = nonGuessers[index]
        let number = vm.assignedNumbers[player.id] ?? 5
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text(player.username)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(GamePlayerColor.color(for: player.id, in: session.players))

                Text("Your Number")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)

                Text("\(number)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(numberColor(number))
                    .scaleEffect(numberRevealVisible ? 1.0 : 0.3)
                    .opacity(numberRevealVisible ? 1.0 : 0)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("1")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.red)
                        Text("Disaster 😬")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 1, height: 28)
                    VStack(spacing: 4) {
                        Text("\(vm.maxNumber)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.green)
                        Text("Perfect 😍")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
            Button("Got it!") {
                FeedbackService.shared.playTap()
                numberRevealVisible = false
                vm.playerGotIt()
            }
            .buttonStyle(GameActionButtonStyle(color: .green))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Scenario Reveal

    private var scenarioRevealView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                roundBadge

                Text("📢")
                    .font(.system(size: 56))

                Text("The Scenario")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(vm.currentScenario.text)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(scenarioRevealed ? 1 : 0)
                    .offset(y: scenarioRevealed ? 0 : 20)

                Text("Everyone react based on your number!\n1 = Disaster 😬 → \(vm.maxNumber) = Perfect 😍")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Start Acting!") {
                FeedbackService.shared.playRoundStart()
                vm.startActing()
            }
            .buttonStyle(GameActionButtonStyle(color: .purple))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            scenarioRevealed = false
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.3)) {
                scenarioRevealed = true
            }
        }
    }

    // MARK: - Acting Phase

    private var actingView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("🎭")
                    .font(.system(size: 64))

                Text("Act It Out!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                SurfaceCard {
                    VStack(spacing: 10) {
                        Text("Scenario")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(vm.currentScenario.text)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)

                Text("Each player acts their reaction.\nThe guesser watches and observes!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    numberScalePill(label: "1 = 😬", color: .red)
                    if vm.maxNumber >= 3 {
                        let mid = (vm.maxNumber + 1) / 2
                        numberScalePill(label: "\(mid) = 😐", color: .yellow)
                    }
                    numberScalePill(label: "\(vm.maxNumber) = 😍", color: .green)
                }
            }
            Spacer()
            Button("Done Acting — Time to Guess") {
                FeedbackService.shared.playTap()
                vm.startGuessing()
            }
            .buttonStyle(GameActionButtonStyle(color: .indigo))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Guessing Phase

    private var guessingView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                roundBadge
                    .padding(.top, 12)
                HStack(spacing: 8) {
                    Text("🔮")
                    CurrentTurnPill(playerName: vm.currentGuesser.username, prefix: "Guessing", accent: .green)
                }
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.guesses) { guess in
                        guessRow(guess: guess)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Button("Submit Guesses") {
                FeedbackService.shared.playResultReveal()
                vm.submitGuesses()
            }
            .buttonStyle(GameActionButtonStyle(color: .blue))
            .disabled(!vm.allGuessesSubmitted)
            .opacity(vm.allGuessesSubmitted ? 1 : 0.5)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func guessRow(guess: TenTanglePlayerGuess) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    playerAvatar(name: guess.playerName)
                    Text(guess.playerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GamePlayerColor.color(for: guess.playerName, in: session.players))
                    Spacer()
                    if let g = guess.guessedNumber {
                        Text("\(g)")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(numberColor(g))
                    } else {
                        Text("?")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(1...vm.maxNumber, id: \.self) { num in
                            Button {
                                FeedbackService.shared.playTap()
                                vm.updateGuess(for: guess.playerID, number: num)
                            } label: {
                                Text("\(num)")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .frame(width: 38, height: 38)
                                    .background(
                                        guess.guessedNumber == num
                                            ? numberColor(num).opacity(0.85)
                                            : .white.opacity(0.07),
                                        in: .rect(cornerRadius: 10)
                                    )
                                    .foregroundStyle(guess.guessedNumber == num ? .white : .primary)
                                    .overlay {
                                        if guess.guessedNumber == num {
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(numberColor(num), lineWidth: 2)
                                        }
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

    // MARK: - Round Reveal

    private var roundRevealView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                roundBadge
                    .padding(.top, 12)
                Text("Results")
                    .font(.title2.weight(.bold))
            }
            .padding(.bottom, 8)

            let correctCount = vm.guesses.filter { $0.guessedNumber == $0.actualNumber }.count

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.guesses) { guess in
                        revealRow(guess: guess)
                    }

                    SurfaceCard {
                        HStack {
                            Text("\(vm.currentGuesser.username) scored")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("+\(correctCount)")
                                .font(.title.weight(.heavy).monospacedDigit())
                                .foregroundStyle(.green)
                            Text(correctCount == 1 ? "point" : "points")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Button("Scoreboard") {
                FeedbackService.shared.playPhaseTransition()
                vm.showScoreboard()
            }
            .buttonStyle(GameActionButtonStyle(color: .purple))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func revealRow(guess: TenTanglePlayerGuess) -> some View {
        let isCorrect = guess.guessedNumber == guess.actualNumber
        return SurfaceCard {
            HStack(spacing: 12) {
                playerAvatar(name: guess.playerName)
                Text(guess.playerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GamePlayerColor.color(for: guess.playerName, in: session.players))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Real:")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(guess.actualNumber)")
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(numberColor(guess.actualNumber))
                    }
                    HStack(spacing: 6) {
                        Text("Guess:")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(guess.guessedNumber ?? 0)")
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(numberColor(guess.guessedNumber ?? 5))
                    }
                }
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isCorrect ? .green : .red)
            }
        }
    }

    // MARK: - Scoreboard

    private var scoreboardView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                roundBadge
                    .padding(.top, 12)
                Text("Scoreboard")
                    .font(.title2.weight(.bold))
            }
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(vm.sortedScores.enumerated()), id: \.element.player.id) { index, entry in
                        scoreRow(rank: index + 1, player: entry.player, score: entry.score)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            let isLast = vm.currentRound >= vm.totalRounds
            Button(isLast ? "Final Results" : "Next Round") {
                FeedbackService.shared.playRoundStart()
                vm.nextRound()
            }
            .buttonStyle(GameActionButtonStyle(color: isLast ? .orange : .blue))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Final Results

    private var finalResultsView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("🏆")
                    .font(.system(size: 64))

                Text("Game Over!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                if let winner = vm.winner {
                    Text(winner.username)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(GamePlayerColor.color(for: winner.id, in: session.players))
                    Text("wins with \(vm.scores[winner.id] ?? 0) points!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(Array(vm.sortedScores.enumerated()), id: \.element.player.id) { index, entry in
                        scoreRow(rank: index + 1, player: entry.player, score: entry.score)
                    }
                }
                .padding(.horizontal, 16)
            }
            Spacer()
            VStack(spacing: 10) {
                Button("Play Again") {
                    vm.startGame()
                }
                .buttonStyle(GameActionButtonStyle(color: .green))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private var roundBadge: some View {
        Text("Round \(vm.currentRound) / \(vm.totalRounds)")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.08), in: .capsule)
            .foregroundStyle(.secondary)
    }

    private func numberColor(_ number: Int) -> Color {
        let max = Double(vm.maxNumber)
        guard max > 1 else { return .green }
        let ratio = Double(number - 1) / (max - 1)
        switch ratio {
        case ..<0.34: return .red
        case ..<0.67: return .yellow
        default: return .green
        }
    }

    private func numberScalePill(label: String, color: Color) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: .capsule)
            .foregroundStyle(color)
    }

    private func playerAvatar(name: String) -> some View {
        let color = GamePlayerColor.color(for: name, in: session.players)
        return GamePlayerAvatar(name: name, color: color, size: 34)
    }

    private func scoreRow(rank: Int, player: PlayerProfile, score: Int) -> some View {
        let playerColor = GamePlayerColor.color(for: player.id, in: session.players)
        return HStack(spacing: 12) {
            Text(rankEmoji(rank))
                .font(.title3)
                .frame(width: 30)

            playerAvatar(name: player.username)

            Text(player.username)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(playerColor)

            Spacer()

            Text("\(score)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(rank == 1 ? .orange : .primary)

            Text(score == 1 ? "pt" : "pts")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(rank == 1 ? 0.06 : 0.03), in: .rect(cornerRadius: 14))
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)."
        }
    }
}

