import SwiftUI

struct DrawRushMultiDeviceSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @State private var viewModel: DrawRushViewModel
    @State private var guessText: String = ""
    @FocusState private var isInputFocused: Bool

    init(appModel: AppViewModel, session: GameSession, onExit: @escaping () -> Void) {
        self.appModel = appModel
        self.session = session
        self.onExit = onExit
        let players = session.players.map { DRPlayer(id: $0.id, name: $0.username) }
        _viewModel = State(initialValue: DrawRushViewModel(
            players: players,
            isMultiDevice: true,
            roomCode: session.roomCode,
            localPlayerID: appModel.sessionPlayerID,
            conceptMode: .preset
        ))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationTitle("Draw & Rush")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.joinRealtimeChannel()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .turnIntro, .drawerReveal:
            introView
        case .drawing:
            if viewModel.isLocalPlayerDrawer {
                drawerView
            } else {
                guesserView
            }
        case .passForGuesses, .guessing:
            guesserView
        case .drawerJudging:
            if viewModel.isLocalPlayerDrawer {
                drawerJudgingView
            } else {
                waitingForJudgeView
            }
        case .roundResults:
            roundResultsView
        case .finalLeaderboard:
            finalLeaderboardView
        }
    }

    private var introView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.cyan)
            VStack(spacing: 10) {
                Text("Turn \(viewModel.currentRoundNumber) of \(viewModel.players.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                CurrentTurnPill(playerName: viewModel.currentDrawer.name, prefix: "Drawer", accent: .green)
                if viewModel.isLocalPlayerDrawer {
                    Text("You are the drawer. Tap below to see your concept.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("Get ready to guess!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.isLocalPlayerDrawer {
                Button("Reveal Concept & Start") {
                    viewModel.advanceFromIntro()
                }
                .buttonStyle(GameActionButtonStyle(color: .cyan))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else {
                HStack(spacing: 8) {
                    ProgressView().tint(.secondary)
                    Text("Waiting for \(viewModel.currentDrawer.name)…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawerView: some View {
        VStack(spacing: 10) {
            header
            Text(viewModel.conceptMode == .preset ? "Concept: \(viewModel.concept)" : "Free draw")
                .font(.headline.weight(.bold))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 16)
            CurrentTurnPill(playerName: viewModel.currentDrawer.name, prefix: "Drawer", accent: .green)

            DRCanvasView(
                strokes: $viewModel.strokes,
                isEnabled: true,
                onStrokeStart: { stroke in viewModel.addStroke(stroke) },
                onPointAppend: { point in viewModel.appendPoint(point) }
            )
            .padding(.horizontal, 12)

            DRBrushBar(viewModel: viewModel)
                .padding(.horizontal, 12)

            submissionsStrip
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Button("Clear") { viewModel.clearCanvas() }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                Button("Undo") { viewModel.undo() }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var guesserView: some View {
        VStack(spacing: 10) {
            header
            DRCanvasView(
                strokes: .constant(viewModel.strokes),
                isEnabled: false,
                onStrokeStart: { _ in },
                onPointAppend: { _ in }
            )
            .padding(.horizontal, 12)

            if viewModel.hasLocalPlayerSubmitted {
                Label("Answer locked — waiting for round to end…", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
                    .padding(.horizontal, 16)
            } else if viewModel.phase == .drawing {
                HStack(spacing: 8) {
                    TextField("Your guess", text: $guessText)
                        .focused($isInputFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                    Button("Submit") {
                        viewModel.submitAnswerMultiDevice(guessText)
                        guessText = ""
                        isInputFocused = false
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(guessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.cyan, in: .rect(cornerRadius: 12))
                    .disabled(guessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
            }

            submissionsStrip
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("\(viewModel.secondsRemaining)s", systemImage: "timer")
                .font(.headline.weight(.heavy))
                .foregroundStyle(viewModel.secondsRemaining <= 10 ? .red : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: .capsule)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Drawer")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.currentDrawer.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var submissionsStrip: some View {
        let guessers = viewModel.players.filter { $0.id != viewModel.currentDrawer.id }
        return HStack(spacing: 6) {
            ForEach(guessers) { player in
                let submitted = viewModel.submittedAnswers.contains(where: { $0.playerID == player.id })
                HStack(spacing: 4) {
                    Image(systemName: submitted ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(submitted ? .green : .secondary)
                    Text(player.name)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white.opacity(0.06), in: .capsule)
            }
        }
    }

    private var roundResultsView: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(viewModel.conceptMode == .preset ? "The concept was" : "Round complete")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.conceptMode == .preset ? viewModel.concept : "Judged by \(viewModel.currentDrawer.name)")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.cyan)
                }
                .padding(.top, 16)

                DRCanvasView(strokes: .constant(viewModel.strokes), isEnabled: false, onStrokeStart: { _ in }, onPointAppend: { _ in })
                    .padding(.horizontal, 16)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeaderView(title: "Answers", subtitle: "Ranked by submission time")
                        let ordered = viewModel.submittedAnswers.sorted { $0.submittedAt < $1.submittedAt }
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, answer in
                            DRAnswerRow(answer: answer, rank: index + 1, points: viewModel.pointsAwarded(for: answer))
                        }
                        if ordered.isEmpty {
                            Text("No answers submitted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeaderView(title: "Standings", subtitle: "Current scores")
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, player in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                Text(player.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(player.score)")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                if isHost {
                    Button(viewModel.currentDrawerIndex + 1 >= viewModel.players.count ? "Show Final Leaderboard" : "Next Drawer") {
                        viewModel.continueToNextTurn()
                    }
                    .buttonStyle(GameActionButtonStyle(color: .cyan))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                } else {
                    Text("Waiting for host…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private var drawerJudgingView: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.cyan)
                    Text("Judge the guesses")
                        .font(.title3.weight(.bold))
                    if viewModel.conceptMode == .preset {
                        Text("Concept: \(viewModel.concept)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.cyan)
                    }
                    Text("Tap ✓ for correct and ✗ for wrong.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                SurfaceCard {
                    VStack(spacing: 8) {
                        let ordered = viewModel.submittedAnswers.sorted { $0.submittedAt < $1.submittedAt }
                        if ordered.isEmpty {
                            Text("No answers submitted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, answer in
                            DRJudgeRow(answer: answer, rank: index + 1) { correct in
                                viewModel.setJudgement(for: answer.id, isCorrect: correct)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                Button(viewModel.submittedAnswers.isEmpty || viewModel.allAnswersJudged ? "Show Results" : "Judge all answers to continue") {
                    viewModel.finalizeJudging()
                }
                .buttonStyle(GameActionButtonStyle(color: .cyan))
                .disabled(!viewModel.submittedAnswers.isEmpty && !viewModel.allAnswersJudged)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private var waitingForJudgeView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(.secondary)
            Text("\(viewModel.currentDrawer.name) is judging the guesses…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var finalLeaderboardView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.yellow)
                Text("Final Leaderboard")
                    .font(.title.weight(.heavy))
            }
            .padding(.top, 20)

            SurfaceCard {
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 12) {
                            Text(rankEmoji(index))
                                .font(.title3)
                                .frame(width: 36)
                            Text(player.name)
                                .font(.headline.weight(.bold))
                            Spacer()
                            Text("\(player.score)")
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(index == 0 ? .yellow : .cyan)
                        }
                        if index < viewModel.leaderboard.count - 1 {
                            Divider().overlay(.white.opacity(0.08))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            if isHost {
                HStack(spacing: 10) {
                    Button("Restart") { viewModel.restart() }
                        .buttonStyle(GameActionButtonStyle(color: .orange))
                    Button("Continue") { viewModel.continueCycle() }
                        .buttonStyle(GameActionButtonStyle(color: .cyan))
                }
                .padding(.horizontal, 16)
            }

            Button("Exit") { onExit() }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isHost: Bool {
        session.players.first(where: { $0.isHost })?.id == appModel.sessionPlayerID
    }

    private func rankEmoji(_ index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "#\(index + 1)"
        }
    }
}
