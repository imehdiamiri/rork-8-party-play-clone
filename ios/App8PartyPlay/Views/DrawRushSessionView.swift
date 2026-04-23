import SwiftUI

struct DrawRushSessionView: View {
    let playerNames: [String]
    let conceptMode: DRConceptMode
    @State private var viewModel: DrawRushViewModel
    @Environment(\.dismiss) private var dismiss

    init(playerNames: [String], conceptMode: DRConceptMode = .preset) {
        self.playerNames = playerNames
        self.conceptMode = conceptMode
        let players = playerNames.map { DRPlayer(name: $0) }
        _viewModel = State(initialValue: DrawRushViewModel(players: players, isMultiDevice: false, conceptMode: conceptMode))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationTitle("Draw & Rush")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onDisappear { viewModel.cleanup() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .turnIntro:
            turnIntroView
        case .drawerReveal:
            drawerRevealView
        case .drawing:
            drawingView
        case .passForGuesses:
            passForGuessesView
        case .guessing:
            guessingView
        case .drawerJudging:
            drawerJudgingView
        case .roundResults:
            roundResultsView
        case .finalLeaderboard:
            finalLeaderboardView
        }
    }

    // MARK: - Phases

    private var turnIntroView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.cyan)
            VStack(spacing: 10) {
                Text("Turn \(viewModel.currentRoundNumber) of \(viewModel.players.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                CurrentTurnPill(playerName: viewModel.currentDrawer.name, prefix: "Drawer", accent: .green)
                Text("Pass the phone to \(viewModel.currentDrawer.name).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            Spacer()
            Button("\(viewModel.currentDrawer.name) is Ready") {
                viewModel.advanceFromIntro()
            }
            .buttonStyle(GameActionButtonStyle(color: .cyan))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawerRevealView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 10) {
                Text(viewModel.conceptMode == .preset ? "Your secret concept" : "Free draw")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.conceptMode == .preset ? viewModel.concept : "Draw anything you want!")
                    .font(.system(size: viewModel.conceptMode == .preset ? 42 : 28, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(.cyan.opacity(0.18), in: .rect(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.cyan.opacity(0.4)) }
                    .padding(.horizontal, 24)
                if viewModel.conceptMode == .freeDraw {
                    Text("Only you know what it is. After guessing, you decide who got it right.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            VStack(spacing: 6) {
                Label("60 seconds to draw", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("No words, no numbers, no letters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Start Drawing") {
                viewModel.startDrawingPhase()
            }
            .buttonStyle(GameActionButtonStyle(color: .cyan))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawingView: some View {
        VStack(spacing: 10) {
            drawingHeader
            DRCanvasView(
                strokes: $viewModel.strokes,
                isEnabled: true,
                onStrokeStart: { stroke in viewModel.addStroke(stroke) },
                onPointAppend: { point in viewModel.appendPoint(point) }
            )
            .padding(.horizontal, 12)

            DRBrushBar(viewModel: viewModel)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Button {
                    viewModel.clearCanvas()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.finishDrawing()
                } label: {
                    Label("Finish", systemImage: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.cyan, in: .rect(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var drawingHeader: some View {
        HStack(spacing: 10) {
            Label("\(viewModel.secondsRemaining)s", systemImage: "timer")
                .font(.headline.weight(.heavy))
                .foregroundStyle(viewModel.secondsRemaining <= 10 ? .red : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: .capsule)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Drawing")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.conceptMode == .preset ? viewModel.concept : "Free draw")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var passForGuessesView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.yellow)
            VStack(spacing: 8) {
                Text("Drawing complete!")
                    .font(.title2.weight(.bold))
                Text("Pass the phone around — each guesser types one answer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            VStack(spacing: 6) {
                Text("First up:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.guessersForSingleDevice.first?.name ?? "")
                    .font(.title3.weight(.heavy))
            }
            Button("Start Guessing") {
                viewModel.phase = .guessing
            }
            .buttonStyle(GameActionButtonStyle(color: .yellow))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @State private var currentGuessText: String = ""

    private var guessingView: some View {
        VStack(spacing: 12) {
            if let guesser = viewModel.currentSingleDeviceGuesser {
                VStack(spacing: 8) {
                    Text("Guess \(viewModel.singleDeviceGuessIndex + 1) of \(viewModel.guessersForSingleDevice.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CurrentTurnPill(playerName: guesser.name, prefix: "Now guessing", accent: .green)
                }
                .padding(.top, 10)

                DRCanvasView(strokes: .constant(viewModel.strokes), isEnabled: false, onStrokeStart: { _ in }, onPointAppend: { _ in })
                    .padding(.horizontal, 12)

                TextField("Type your guess", text: $currentGuessText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                    .padding(.horizontal, 16)

                Button("Submit (locked after)") {
                    viewModel.submitAnswerSingleDevice(currentGuessText)
                    currentGuessText = ""
                }
                .buttonStyle(GameActionButtonStyle(color: .yellow))
                .padding(.horizontal, 16)
                .disabled(currentGuessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 16)
            } else {
                Spacer()
                ProgressView()
                Spacer()
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
                    Text("\(viewModel.currentDrawer.name), judge the guesses")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                    if viewModel.conceptMode == .preset {
                        Text("Concept: \(viewModel.concept)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.cyan)
                    }
                    Text("Tap ✓ for correct guesses and ✗ for wrong ones.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 16)

                SurfaceCard {
                    VStack(spacing: 8) {
                        let ordered = viewModel.submittedAnswers.sorted { $0.submittedAt < $1.submittedAt }
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, answer in
                            DRJudgeRow(answer: answer, rank: index + 1) { correct in
                                viewModel.setJudgement(for: answer.id, isCorrect: correct)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                Button(viewModel.allAnswersJudged ? "Show Results" : "Judge all answers to continue") {
                    viewModel.finalizeJudging()
                }
                .buttonStyle(GameActionButtonStyle(color: .cyan))
                .disabled(!viewModel.allAnswersJudged)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private var roundResultsView: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.conceptMode == .preset {
                    VStack(spacing: 6) {
                        Text("The concept was")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(viewModel.concept)
                            .font(.title.weight(.heavy))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.top, 16)
                } else {
                    VStack(spacing: 6) {
                        Text("Round complete")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Judged by \(viewModel.currentDrawer.name)")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.top, 16)
                }

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

                Button(viewModel.currentDrawerIndex + 1 >= viewModel.players.count ? "Show Final Leaderboard" : "Next Drawer") {
                    viewModel.continueToNextTurn()
                }
                .buttonStyle(GameActionButtonStyle(color: .cyan))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
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

            HStack(spacing: 10) {
                Button("Restart") {
                    viewModel.restart()
                }
                .buttonStyle(GameActionButtonStyle(color: .orange))

                Button("Continue") {
                    viewModel.continueCycle()
                }
                .buttonStyle(GameActionButtonStyle(color: .cyan))
            }
            .padding(.horizontal, 16)

            Button("Exit") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Answer Row

struct DRAnswerRow: View {
    let answer: DRAnswer
    let rank: Int
    let points: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(answer.playerName)
                        .font(.subheadline.weight(.semibold))
                    if answer.wasDuringDrawing {
                        Label("Early", systemImage: "bolt.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.yellow.opacity(0.18), in: .capsule)
                    }
                }
                Text(answer.text)
                    .font(.footnote)
                    .foregroundStyle(answer.isCorrect ? Color.green : Color.red)
                    .lineLimit(2)
            }
            Spacer()
            if points > 0 {
                Text("+\(points)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(10)
        .background((answer.isCorrect ? Color.green : Color.red).opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder((answer.isCorrect ? Color.green : Color.red).opacity(answer.wasDuringDrawing ? 0.6 : 0.18), lineWidth: answer.wasDuringDrawing ? 2 : 1)
        }
    }
}

struct DRJudgeRow: View {
    let answer: DRAnswer
    let rank: Int
    let onJudge: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(answer.playerName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(answer.text)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    onJudge(false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(answer.isJudged && !answer.isCorrect ? .white : .red)
                        .frame(width: 40, height: 40)
                        .background(answer.isJudged && !answer.isCorrect ? Color.red : Color.red.opacity(0.15), in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Button {
                    onJudge(true)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(answer.isJudged && answer.isCorrect ? .white : .green)
                        .frame(width: 40, height: 40)
                        .background(answer.isJudged && answer.isCorrect ? Color.green : Color.green.opacity(0.15), in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(answer.isJudged ? (answer.isCorrect ? Color.green.opacity(0.4) : Color.red.opacity(0.4)) : Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - Canvas

struct DRCanvasView: View {
    @Binding var strokes: [DRStroke]
    let isEnabled: Bool
    let onStrokeStart: (DRStroke) -> Void
    let onPointAppend: (DRPoint) -> Void

    @State private var currentStrokeID: UUID?

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for stroke in strokes {
                    guard stroke.points.count > 0 else { continue }
                    var path = Path()
                    let first = stroke.points[0]
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for p in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height))
                    }
                    context.stroke(path, with: .color(stroke.uiColor), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                }
            }
            .background(Color(white: 0.98))
            .clipShape(.rect(cornerRadius: 16))
            .gesture(isEnabled ? drawGesture(size: geo.size) : nil)
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(isEnabled)
    }

    private func drawGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let nx = max(0, min(1, value.location.x / size.width))
                let ny = max(0, min(1, value.location.y / size.height))
                let point = DRPoint(x: nx, y: ny)
                if currentStrokeID == nil {
                    let brush = DRBrushState.shared
                    let stroke = DRStroke(color: brush.color.rawValue, width: brush.width, points: [point])
                    currentStrokeID = stroke.id
                    onStrokeStart(stroke)
                } else {
                    onPointAppend(point)
                }
            }
            .onEnded { _ in
                currentStrokeID = nil
            }
    }
}

@Observable
@MainActor
final class DRBrushState {
    static let shared = DRBrushState()
    var color: DRBrushColor = .black
    var width: Double = 4
}

struct DRBrushBar: View {
    let viewModel: DrawRushViewModel
    @State private var brushState = DRBrushState.shared

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DRBrushColor.allCases) { color in
                        Button {
                            brushState.color = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle()
                                        .strokeBorder(brushState.color == color ? Color.cyan : Color.white.opacity(0.2), lineWidth: brushState.color == color ? 3 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            HStack(spacing: 10) {
                Image(systemName: "pencil.tip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $brushState.width, in: 2...18, step: 1)
                Text("\(Int(brushState.width))")
                    .font(.caption.weight(.semibold))
                    .frame(width: 24)
            }
        }
    }
}
