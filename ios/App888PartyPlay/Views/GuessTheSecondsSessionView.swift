import Observation
import SwiftUI

struct GuessTheSecondsSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: GuessTheSecondsSessionViewModel

    init(appModel: AppViewModel, session: GameSession, onExit: @escaping () -> Void) {
        self.appModel = appModel
        self.session = session
        self.onExit = onExit
        _viewModel = State(initialValue: GuessTheSecondsSessionViewModel(session: session))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            singleDeviceBody
        }
        .navigationTitle("Guess the Seconds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .firstTimeHint(
            key: "hint_seen_guess_seconds",
            icon: "timer",
            title: "Guess the Seconds",
            tip: "Pick a target time, hit Start, then Stop as close to it as you can — no peeking at the clock.",
            accent: .blue
        )
    }

    private var singleDeviceBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                if let latestTurn = viewModel.latestTurn {
                    lastResultBanner(
                        title: "\(latestTurn.playerName) • Round \(latestTurn.round)",
                        target: latestTurn.targetTime,
                        actual: latestTurn.actualTime,
                        diff: latestTurn.difference
                    )
                }
                controlCard
                scoreTableCard
                if viewModel.isFinished {
                    finalResultsCard
                    MultiplayerResultActionsBar(appModel: appModel, session: appModel.activeSession ?? session, onExit: onExit)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func lastResultBanner(title: String, target: Double, actual: Double, diff: Double) -> some View {
        let band = GuessTheSecondsSessionViewModel.AccuracyBand(difference: diff)
        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(band.tint)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    StatusPillView(
                        title: diff == 0 ? "Perfect!" : (diff < 1 ? "Close" : (diff <= 2 ? "Okay" : "Far")),
                        systemImage: diff == 0 ? "target" : "scope",
                        tint: band.tint
                    )
                }
                HStack(spacing: 10) {
                    resultMetric(label: "Target", value: formatSec(target), tint: .secondary)
                    resultMetric(label: "Stopped", value: formatSec(actual), tint: .primary)
                    resultMetric(label: "Diff", value: formatDiff(diff), tint: band.tint)
                }
            }
        }
    }

    private func resultMetric(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.05)) }
    }

    private func formatSec(_ value: Double) -> String {
        String(format: "%.2f", ((value * 100).rounded()) / 100)
    }

    private func formatDiff(_ value: Double) -> String {
        String(format: "%.2f", ((value * 100).rounded()) / 100)
    }

    private var headerCard: some View {
        SurfaceCard {
            HStack(spacing: 10) {
                if let currentPlayer = viewModel.currentPlayer {
                    HStack(spacing: 7) {
                        Text(viewModel.roundProgressText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        CurrentTurnPill(playerName: currentPlayer.username, prefix: "Now", accent: .green)
                    }
                } else {
                    Text(viewModel.roundProgressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                StatusPillView(
                    title: viewModel.statusText,
                    systemImage: viewModel.isRunning ? "timer" : (viewModel.isFinished ? "checkmark.seal.fill" : "figure.mind.and.body"),
                    tint: viewModel.isRunning ? .blue : (viewModel.isFinished ? .green : .secondary)
                )
            }
        }
    }

    private var controlCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderView(
                    title: "Target Time",
                    subtitle: viewModel.currentRoundTargetLocked ? "This round target is locked for all players." : "Choose the target for this round."
                )

                selectorArea

                VStack(spacing: 14) {
                    if !viewModel.isRunning {
                        Button {
                            viewModel.startTurn()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(GuessPrimaryButtonStyle(tint: .blue))
                        .disabled(!viewModel.canStart)
                    }

                    Button {
                        viewModel.stopTurn()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(GuessPrimaryButtonStyle(tint: .red))
                    .disabled(!viewModel.canStop)
                }
                .sensoryFeedback(.success, trigger: viewModel.completedTurnCount)
                .sensoryFeedback(.selection, trigger: viewModel.isRunning)
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy, value: viewModel.isRunning)
        .animation(reduceMotion ? .linear(duration: 0.01) : .smooth, value: viewModel.completedTurnCount)
    }

    private var selectorArea: some View {
        HStack(spacing: 12) {
            GuessStepperButton(systemImage: "minus", isEnabled: viewModel.canEditTargetTime) {
                viewModel.adjustTargetTime(by: -1)
            } onRepeat: { _ in
                viewModel.adjustTargetTime(by: -1)
            }

            VStack(spacing: 8) {
                Text(viewModel.isRunning ? "•••••" : viewModel.formatSeconds(viewModel.displayedTargetTime))
                    .font(.system(size: 52, weight: .heavy, design: .default).width(.compressed))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isRunning ? .secondary : .primary)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 18)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.06))
            }

            GuessStepperButton(systemImage: "plus", isEnabled: viewModel.canEditTargetTime) {
                viewModel.adjustTargetTime(by: 1)
            } onRepeat: { _ in
                viewModel.adjustTargetTime(by: 1)
            }
        }
    }

    private var scoreTableCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeaderView(title: "Progress", subtitle: "Each round uses one shared target for everyone.")

                roundTargetsHeader

                VStack(spacing: 10) {
                    ForEach(viewModel.scoreRows) { row in
                        scoreCompactRow(row)
                    }
                }
            }
        }
    }

    private var roundTargetsHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Time")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            ForEach(viewModel.roundHeaders, id: \.round) { header in
                VStack(spacing: 4) {
                    Text("R\(header.round)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(header.text)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
            }

            Text("Total")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56)
        }
        .padding(.horizontal, 2)
    }

    private func scoreCompactRow(_ row: GuessTheSecondsSessionViewModel.ScoreRow) -> some View {
        let backgroundFill: Color = row.isCurrent ? .blue.opacity(0.09) : .white.opacity(0.035)
        let borderFill: Color = row.isCurrent ? .blue.opacity(0.16) : .white.opacity(0.05)
        let playerIndex = session.players.firstIndex(where: { $0.username == row.playerName })
        let nameFill: Color = row.isCurrent ? (playerIndex.map { GamePlayerColor.color(for: $0) } ?? .blue) : .primary

        return HStack(alignment: .center, spacing: 8) {
            Text(row.playerName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(nameFill)
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)

            ForEach(row.roundCells) { cell in
                scoreRoundCell(cell)
            }

            Text(row.totalText)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 56)
        }
        .padding(12)
        .background(backgroundFill, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderFill)
        }
    }

    private func scoreRoundCell(_ cell: GuessTheSecondsSessionViewModel.ScoreCell) -> some View {
        let foreground: Color = cell.isEmpty ? .secondary : .white
        let background: Color = cell.tint.opacity(cell.isEmpty ? 0.08 : 0.28)

        return Text(cell.text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(background, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.05))
            }
    }

    private var finalResultsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Final Results")
                            .font(.title3.weight(.bold))
                        Text("Lowest total difference wins.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let winner = viewModel.ranking.first {
                        StatusPillView(title: winner.playerName, systemImage: "crown.fill", tint: .yellow)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(Array(viewModel.ranking.enumerated()), id: \.element.id) { index, result in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.headline.weight(.bold))
                                .frame(width: 38, height: 38)
                                .background(index == 0 ? .yellow.opacity(0.22) : .white.opacity(0.06), in: .circle)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.playerName)
                                    .font(.headline.weight(.semibold))
                                Text("Avg \(viewModel.formatDifference(result.averageDifference))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(viewModel.formatDifference(result.totalDifference))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(index == 0 ? .green : .primary)
                        }
                        .padding(12)
                        .background(index == 0 ? .green.opacity(0.12) : .white.opacity(0.04), in: .rect(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(index == 0 ? .green.opacity(0.2) : .white.opacity(0.05))
                        }
                    }
                }

            }
        }
    }
}

@MainActor
@Observable
final class GuessTheSecondsSessionViewModel {
    nonisolated struct TurnResult: Identifiable, Hashable, Sendable {
        let id: UUID
        let playerName: String
        let round: Int
        let targetTime: Double
        let actualTime: Double
        let difference: Double

        var accuracy: AccuracyBand {
            AccuracyBand(difference: difference)
        }
    }

    nonisolated struct ScoreCell: Identifiable, Hashable, Sendable {
        let id: String
        let text: String
        let tint: Color
        let isEmpty: Bool
    }

    nonisolated struct ScoreRow: Identifiable, Hashable, Sendable {
        let id: UUID
        let playerName: String
        let roundCells: [ScoreCell]
        let totalText: String
        let isCurrent: Bool
    }

    nonisolated struct RankingRow: Identifiable, Hashable, Sendable {
        let id: UUID
        let playerName: String
        let totalDifference: Double
        let averageDifference: Double
    }

    nonisolated struct RoundHeader: Hashable, Sendable {
        let round: Int
        let text: String
    }

    nonisolated enum AccuracyBand: Hashable, Sendable {
        case perfect
        case close
        case okay
        case far

        init(difference: Double) {
            if difference == 0 {
                self = .perfect
            } else if difference < 1 {
                self = .close
            } else if difference <= 2 {
                self = .okay
            } else {
                self = .far
            }
        }

        var tint: Color {
            switch self {
            case .perfect: return .green
            case .close: return .blue
            case .okay: return .yellow
            case .far: return .red
            }
        }
    }

    let session: GameSession

    var selectedTime: Double = 15
    var activeTurnIndex: Int = 0
    var isRunning: Bool = false
    var startedAt: Date?
    var elapsedTime: Double = 0
    var results: [TurnResult] = []
    var completedTurnCount: Int = 0
    var roundTargets: [Int: Double] = [:]

    init(session: GameSession) {
        self.session = session
    }

    var players: [PlayerProfile] {
        session.players
    }

    var roundsPerPlayer: Int {
        guard !players.isEmpty else { return 0 }
        return max(session.rounds.count / players.count, 1)
    }

    var totalTurns: Int {
        session.rounds.count
    }

    var isFinished: Bool {
        activeTurnIndex >= totalTurns
    }

    var currentPlayer: PlayerProfile? {
        guard !isFinished, session.rounds.indices.contains(activeTurnIndex) else { return nil }
        let playerName = session.rounds[activeTurnIndex].activePlayerName
        return players.first(where: { $0.username == playerName })
    }

    var currentRoundNumber: Int {
        guard !players.isEmpty, !isFinished else { return roundsPerPlayer }
        return (activeTurnIndex / players.count) + 1
    }

    var isFirstPlayerOfCurrentRound: Bool {
        guard !players.isEmpty, !isFinished else { return false }
        return activeTurnIndex % players.count == 0
    }

    var currentRoundTargetLocked: Bool {
        roundTargets[currentRoundNumber] != nil
    }

    var displayedTargetTime: Double {
        roundTargets[currentRoundNumber] ?? selectedTime
    }

    var roundProgressText: String {
        if isFinished {
            return "All rounds complete"
        }
        return "Round \(currentRoundNumber) / \(roundsPerPlayer)"
    }

    var nowPlayingText: String {
        if let currentPlayer {
            return "Now playing: \(currentPlayer.username)"
        }
        return "Ranking is ready"
    }

    var statusText: String {
        if isFinished {
            return "Finished"
        }
        return isRunning ? "Running" : "Ready"
    }

    var canEditTargetTime: Bool {
        !isRunning && !isFinished && isFirstPlayerOfCurrentRound && !currentRoundTargetLocked
    }

    var canStart: Bool {
        !isRunning && !isFinished
    }

    var canStop: Bool {
        isRunning && !isFinished
    }

    var latestTurn: TurnResult? {
        results.last
    }

    var ranking: [RankingRow] {
        players.map { player in
            let playerResults = results.filter { $0.playerName == player.username }
            let total = playerResults.reduce(0) { $0 + $1.difference }
            let average = playerResults.isEmpty ? 0 : total / Double(playerResults.count)
            return RankingRow(id: player.id, playerName: player.username, totalDifference: rounded(total), averageDifference: rounded(average))
        }
        .sorted { lhs, rhs in
            if lhs.totalDifference == rhs.totalDifference {
                return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedAscending
            }
            return lhs.totalDifference < rhs.totalDifference
        }
    }

    var roundHeaders: [RoundHeader] {
        (1...roundsPerPlayer).map { round in
            let targetTime = roundTargets[round]
            return RoundHeader(round: round, text: targetTime.map(formatSeconds(_:)) ?? "—")
        }
    }

    var scoreRows: [ScoreRow] {
        players.map { player in
            let playerResults = results.filter { $0.playerName == player.username }
            let cells: [ScoreCell] = (1...roundsPerPlayer).map { round in
                guard let result = playerResults.first(where: { $0.round == round }) else {
                    return ScoreCell(id: "\(player.id)-\(round)", text: "—", tint: .secondary, isEmpty: true)
                }
                return ScoreCell(id: "\(player.id)-\(round)", text: formatSeconds(result.actualTime), tint: result.accuracy.tint, isEmpty: false)
            }
            let total = playerResults.reduce(0) { $0 + $1.difference }
            return ScoreRow(
                id: player.id,
                playerName: player.username,
                roundCells: cells,
                totalText: formatDifference(total),
                isCurrent: currentPlayer?.id == player.id && !isFinished
            )
        }
    }

    func setTargetTime(_ value: Double) {
        guard canEditTargetTime else { return }
        selectedTime = clampTime(value)
    }

    func adjustTargetTime(by delta: Double) {
        guard canEditTargetTime else { return }
        selectedTime = clampTime(selectedTime + delta)
        FeedbackService.shared.playClick()
    }

    func startTurn() {
        guard canStart else { return }
        if roundTargets[currentRoundNumber] == nil {
            let lockedTarget = rounded(selectedTime)
            roundTargets[currentRoundNumber] = lockedTarget
            selectedTime = lockedTarget
        }
        startedAt = Date()
        elapsedTime = 0
        isRunning = true
        FeedbackService.shared.playTimerStart()
    }

    func stopTurn() {
        guard canStop, let startedAt, let currentPlayer else { return }
        let actualTime = rounded(Date().timeIntervalSince(startedAt))
        let targetTime = roundTargets[currentRoundNumber] ?? rounded(selectedTime)
        let difference = rounded(abs(targetTime - actualTime))
        let turn = TurnResult(
            id: UUID(),
            playerName: currentPlayer.username,
            round: currentRoundNumber,
            targetTime: targetTime,
            actualTime: actualTime,
            difference: difference
        )
        results.append(turn)
        completedTurnCount += 1
        elapsedTime = actualTime
        isRunning = false
        self.startedAt = nil
        activeTurnIndex += 1
        FeedbackService.shared.playTimerStop()
        if turn.accuracy == .perfect {
            FeedbackService.shared.playSuccess()
        } else if turn.accuracy == .close {
            FeedbackService.shared.playSuccess()
        } else if turn.accuracy == .far {
            FeedbackService.shared.playError()
        }
        if isFinished {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                FeedbackService.shared.playGameEnd()
            }
        }
    }

    func liveElapsed(at date: Date) -> Double {
        guard let startedAt, isRunning else { return elapsedTime }
        return rounded(date.timeIntervalSince(startedAt))
    }

    func formatSeconds(_ value: Double) -> String {
        String(format: "%.2f", rounded(value))
    }

    func formatDifference(_ value: Double) -> String {
        String(format: "%.2f", rounded(value))
    }

    private func clampTime(_ value: Double) -> Double {
        min(max(rounded(value), 1), 60)
    }

    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

struct GuessPrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 0.9), in: .capsule)
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.smooth, value: configuration.isPressed)
    }
}

struct GuessStepperButton: View {
    let systemImage: String
    let isEnabled: Bool
    let onTap: () -> Void
    let onRepeat: (Int) -> Void

    @State private var repeatTask: Task<Void, Never>?
    @State private var didRepeat: Bool = false

    var body: some View {
        Button {
            if !didRepeat {
                onTap()
            }
            stopRepeating()
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(isEnabled ? .white : .secondary)
                .frame(width: 60, height: 60)
                .background(isEnabled ? .blue.opacity(0.9) : .white.opacity(0.06), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    startRepeatingIfNeeded()
                }
                .onEnded { _ in
                    stopRepeating()
                }
        )
        .onDisappear {
            stopRepeating()
        }
    }

    private func startRepeatingIfNeeded() {
        guard isEnabled, repeatTask == nil else { return }
        didRepeat = false
        repeatTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            didRepeat = true
            var iteration = 0
            while !Task.isCancelled {
                await MainActor.run {
                    onRepeat(iteration)
                }
                iteration += 1
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            didRepeat = false
        }
    }
}
