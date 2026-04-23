import SwiftUI

struct MemoryPathSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void
    @State private var vm = MemoryPathViewModel()
    @State private var hasStarted: Bool = false
    @State private var multiHasStartedTurn: Bool = false

    private var isMultiDevice: Bool {
        session.mode != .singleDevice && session.memoryPathState != nil
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            if isMultiDevice {
                multiDeviceBody
            } else {
                singleDeviceBody
            }

            if vm.showConfetti {
                confettiOverlay
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .firstTimeHint(
            key: "hint_seen_memory_path",
            icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
            title: "Memory Path",
            tip: "Find the hidden path from Start to End. One wrong tap and you restart.",
            accent: .teal
        )
        .sensoryFeedback(.error, trigger: vm.wrongFeedbackToken)
        .sensoryFeedback(.success, trigger: vm.correctFeedbackToken)
        .onAppear {
            guard !hasStarted, !isMultiDevice else { return }
            hasStarted = true
            let settings = appModel.currentMemoryPathSettings ?? .default
            let names = session.players.map(\.username)
            vm.configure(settings: settings, playerNames: names)
            vm.startGame()
        }
        .onChange(of: vm.phase) { _, newPhase in
            if isMultiDevice && multiHasStartedTurn && newPhase == .finished {
                handleMultiTurnComplete()
            }
        }
    }

    @ViewBuilder
    private var singleDeviceBody: some View {
        switch vm.phase {
        case .setup, .countdown:
            countdownView
        case .playing, .hintActive:
            gameplayView
        case .passDevice:
            passDeviceView
        case .turnSwitch:
            turnSwitchView
        case .finished:
            resultsView
        }
    }

    @ViewBuilder
    private var multiDeviceBody: some View {
        if let mp = appModel.activeSession?.memoryPathState {
            let currentSession = appModel.activeSession ?? session
            let isMyTurn = appModel.isCurrentPlayerTurn(in: currentSession)
            let turnPlayerName = appModel.currentTurnPlayerName(in: currentSession)

            if mp.isFinished {
                multiResultsView(mp: mp, players: currentSession.players)
            } else if isMyTurn && multiHasStartedTurn {
                switch vm.phase {
                case .setup, .countdown:
                    countdownView
                case .playing, .hintActive:
                    gameplayView
                case .passDevice, .turnSwitch:
                    countdownView
                case .finished:
                    multiTurnCompleteView(mp: mp)
                }
            } else if isMyTurn {
                multiReadyView(mp: mp, players: currentSession.players)
            } else {
                multiWaitingView(mp: mp, turnPlayerName: turnPlayerName, players: currentSession.players)
            }
        }
    }

    private func multiReadyView(mp: MemoryPathGameState, players: [PlayerProfile]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "map.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 100, height: 100)
                    .background(.teal.opacity(0.14), in: .rect(cornerRadius: 28))
                VStack(spacing: 8) {
                    Text("Your Turn! Start")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    if let name = appModel.currentTurnPlayerName(in: appModel.activeSession ?? session) {
                        CurrentTurnPill(playerName: name, prefix: "Now", accent: .green)
                    }
                    Text("Tap Start to begin your turn and find the hidden path from start to end.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 16) {
                    mpStatBubble(title: "\(mp.gridSize)×\(mp.gridSize)", subtitle: "Grid")
                    mpStatBubble(title: "\(mp.targetSteps)", subtitle: "Steps")
                    mpStatBubble(title: "\(mp.currentPlayerIndex + 1)/\(players.count)", subtitle: "Player")
                }
                Button("Start") {
                    FeedbackService.shared.playRoundStart()
                    startMultiTurn(mp: mp)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 40)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func multiWaitingView(mp: MemoryPathGameState, turnPlayerName: String?, players: [PlayerProfile]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)
                if let name = turnPlayerName {
                    CurrentTurnPill(playerName: name, prefix: "Waiting for", accent: .green)
                        .scaleEffect(1.15)
                } else {
                    Text("Waiting...")
                        .font(.title2.weight(.bold))
                }
                Text("They are finding the path on their device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !mp.playerResults.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Completed")
                                .font(.subheadline.weight(.semibold))
                            ForEach(mp.playerResults) { result in
                                HStack {
                                    Text(result.playerName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if result.isFinished, let time = result.completionTime {
                                        Text(String(format: "%.1fs", time))
                                            .font(.subheadline.weight(.bold))
                                            .monospacedDigit()
                                            .foregroundStyle(.teal)
                                    } else {
                                        Text("\(result.progress) steps")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(10)
                                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                mpStatBubble(title: "\(mp.currentPlayerIndex + 1)/\(players.count)", subtitle: "Player")
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func multiTurnCompleteView(mp: MemoryPathGameState) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.green)
            Text("Turn Complete!")
                .font(.title2.weight(.bold))
            Text("Waiting for other players...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func multiResultsView(mp: MemoryPathGameState, players: [PlayerProfile]) -> some View {
        let sorted = mp.playerResults.sorted { r1, r2 in
            if r1.isFinished && r2.isFinished { return (r1.completionTime ?? .infinity) < (r2.completionTime ?? .infinity) }
            if r1.isFinished { return true }
            if r2.isFinished { return false }
            return r1.progress > r2.progress
        }
        let currentSession = appModel.activeSession ?? session
        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .padding(.top, 20)
                    Text("Final Rankings")
                        .font(.title2.weight(.bold))
                }
                VStack(spacing: 10) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, result in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(index == 0 ? .yellow.opacity(0.2) : .white.opacity(0.06))
                                    .frame(width: 40, height: 40)
                                Text("\(index + 1)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(index == 0 ? .yellow : .secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.playerName)
                                    .font(.subheadline.weight(.semibold))
                                if result.isFinished, let time = result.completionTime {
                                    Text(String(format: "%.1fs · %d tries", time, result.attempts))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(result.progress) steps · \(result.attempts) tries")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if index == 0 {
                                Image(systemName: "crown.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding(12)
                        .background(index == 0 ? .yellow.opacity(0.06) : .white.opacity(0.035), in: .rect(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(index == 0 ? .yellow.opacity(0.2) : .white.opacity(0.04)) }
                    }
                }
                .padding(.horizontal, 16)

                MultiplayerResultActionsBar(appModel: appModel, session: currentSession, onExit: onExit)
                    .padding(.bottom, 28)
            }
        }
    }

    private func startMultiTurn(mp: MemoryPathGameState) {
        let difficulty = MemoryPathDifficulty(rawValue: mp.difficulty) ?? .medium
        let gameMode = MemoryPathGameMode(rawValue: mp.gameMode) ?? .timeRace
        let settings = MemoryPathSettings(gameMode: gameMode, playType: .singleDevice, difficulty: difficulty, targetSteps: mp.targetSteps)
        vm = MemoryPathViewModel()
        vm.configure(settings: settings, playerNames: ["You"])
        vm.startGame()
        multiHasStartedTurn = true
    }

    private func handleMultiTurnComplete() {
        let player = vm.players.first
        let progress = player?.progress ?? 0
        let attempts = player?.attempts ?? 0
        let completionTime = player?.completionTime
        let finished = player?.isFinished ?? false
        let completionBonus = finished ? 10_000 : 0
        let progressScore = progress * 100
        let efficiencyBonus = max(0, 40 - attempts * 10)
        let timeBonus = Int(max(0, 600 - (completionTime ?? 0) * 10))
        let score = completionBonus + progressScore + efficiencyBonus + timeBonus
        appModel.submitMemoryPathResult(
            progress: progress,
            attempts: attempts,
            completionTime: completionTime,
            isFinished: finished,
            score: score
        )
        multiHasStartedTurn = false
    }

    private func mpStatBubble(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "road.lanes")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.teal)
                .symbolEffect(.pulse, isActive: true)

            Text("Memory Path")
                .font(.title.weight(.bold))

            Text("\(vm.settings.difficulty.gridSize)×\(vm.settings.difficulty.gridSize) · \(vm.settings.gameMode.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Get Ready...")
                .font(.title2.weight(.bold))
                .foregroundStyle(.teal)
                .transition(.scale.combined(with: .opacity))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gameplay

    private var gameplayView: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer(minLength: 12)

            gridView
                .padding(.horizontal, 12)

            Spacer(minLength: 12)

            bottomControls
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.activeName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(playerColorForName(vm.activeName))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label(vm.settings.gameMode.title, systemImage: vm.settings.gameMode.icon)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(vm.stepsFound)/\(vm.stepsToFind)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.teal)
                }
            }

            Spacer(minLength: 0)

            timerPill

            if vm.phase == .hintActive {
                hintCountdownPill
            }
        }
    }

    private var timerPill: some View {
        let seconds = Int(vm.elapsedTime) % 60
        let minutes = Int(vm.elapsedTime) / 60
        return HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.teal)
            Text(String(format: "%d:%02d", minutes, seconds))
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: .capsule)
    }

    private var hintCountdownPill: some View {
        Text("\(vm.hintCountdown)s")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.orange.opacity(0.16), in: .capsule)
    }

    private var gridView: some View {
        let size = vm.gridSize
        let spacing: CGFloat = size <= 5 ? 6 : (size <= 6 ? 5 : 4)

        return GeometryReader { geo in
            let totalSpacing = spacing * CGFloat(size - 1)
            let availableWidth = geo.size.width - totalSpacing
            let availableHeight = geo.size.height - totalSpacing
            let tileSize = min(availableWidth / CGFloat(size), availableHeight / CGFloat(size))

            let gridWidth = tileSize * CGFloat(size) + totalSpacing
            let gridHeight = tileSize * CGFloat(size) + totalSpacing

            VStack(spacing: spacing) {
                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<size, id: \.self) { col in
                            if row < vm.tiles.count && col < vm.tiles[row].count {
                                MemoryPathTileView(
                                    tile: vm.tiles[row][col],
                                    tileSize: tileSize,
                                    isWrong: vm.wrongTileID == vm.tiles[row][col].id,
                                    progress: vm.currentProgress,
                                    pathLength: vm.pathLength
                                ) {
                                    vm.tapTile(row: row, col: col)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: gridWidth, height: gridHeight)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            progressBar
            if vm.hintEligible {
                hintButton
            }
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.08))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: vm.stepsToFind > 0 ? geo.size.width * CGFloat(vm.stepsFound) / CGFloat(vm.stepsToFind) : 0, height: 8)
                        .animation(.spring(duration: 0.3), value: vm.stepsFound)
                }
            }
            .frame(height: 8)

            Text("Step \(vm.stepsFound) of \(vm.stepsToFind)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var hintButton: some View {
        Button {
            vm.useHint()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill")
                    .font(.caption.weight(.bold))
                Text("Hint")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(vm.currentHintUsed ? Color.secondary : Color.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(vm.currentHintUsed ? .white.opacity(0.04) : .orange.opacity(0.14), in: .capsule)
            .overlay {
                Capsule().strokeBorder(vm.currentHintUsed ? .white.opacity(0.04) : .orange.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .disabled(vm.currentHintUsed || vm.phase == .hintActive || !vm.hintUnlocked)
        .opacity(vm.currentHintUsed ? 0.4 : (!vm.hintUnlocked ? 0.5 : 1))
    }

    // MARK: - Pass Device

    private var passDeviceView: some View {
        GamePassPhoneView(
            playerName: vm.passDevicePlayerName,
            subtitle: "Get ready for your turn!",
            accentColor: .teal,
            buttonTitle: "I'm Ready"
        ) {
            FeedbackService.shared.playRoundStart()
            vm.advanceFromPassDevice()
        }
    }

    // MARK: - Turn Switch

    private var turnSwitchView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.cyan)
                .symbolEffect(.rotate, isActive: true)

            VStack(spacing: 6) {
                ForEach(vm.turnSwitchMessage.components(separatedBy: "\n"), id: \.self) { line in
                    Text(line)
                        .font(line == vm.turnSwitchMessage.components(separatedBy: "\n").first ? .title2.weight(.bold) : .headline.weight(.semibold))
                        .foregroundStyle(line == vm.turnSwitchMessage.components(separatedBy: "\n").first ? .primary : .secondary)
                }
            }
            .multilineTextAlignment(.center)

            Button("Continue") {
                FeedbackService.shared.playPhaseTransition()
                vm.advanceFromTurnSwitch()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .frame(maxWidth: 200)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                resultHeader
                rankingList
                statsSection
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private var resultHeader: some View {
        SurfaceCard {
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.yellow)

                if let winner = vm.rankings.first {
                    Text(winner.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(playerColorForName(winner.name))
                    Text("Winner · Rank #\(winner.rank)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.yellow)
                    Text(winner.completed ? "Completed in \(winner.formattedTime) · Score \(winner.score)" : "Furthest: \(max(0, winner.progress - 1))/\(max(0, winner.pathLength - 2)) steps · Score \(winner.score)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var rankingList: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "Leaderboard", subtitle: vm.settings.gameMode == .timeRace ? "Sorted by rank, then fastest completion" : "Sorted by rank, progress, tries, and time")

                ForEach(vm.rankings) { ranking in
                    rankingRow(ranking)
                }
            }
        }
    }

    private func rankingRow(_ ranking: MemoryPathRanking) -> some View {
        HStack(spacing: 12) {
            rankBadge(ranking.rank)

            VStack(alignment: .leading, spacing: 3) {
                Text(ranking.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(playerColorForName(ranking.name))
                HStack(spacing: 8) {
                    if ranking.completed {
                        Label(ranking.formattedTime, systemImage: "clock.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.teal)
                    } else {
                        Label("\(max(0, ranking.progress - 1))/\(max(0, ranking.pathLength - 2))", systemImage: "road.lanes")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                    Label("\(ranking.attempts) tries", systemImage: "arrow.counterclockwise")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Label("\(ranking.score)", systemImage: "star.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.yellow)
                }
            }

            Spacer(minLength: 0)

            if ranking.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                let pct = ranking.pathLength > 2 ? Double(max(0, ranking.progress - 1)) / Double(ranking.pathLength - 2) * 100 : 0
                Text("\(Int(pct))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func rankBadge(_ rank: Int) -> some View {
        let color: Color = rank == 1 ? .yellow : (rank == 2 ? .gray : (rank == 3 ? .orange : .white.opacity(0.3)))
        return Text("\(rank)")
            .font(.caption.weight(.bold))
            .frame(width: 28, height: 28)
            .background(color.opacity(0.2), in: .circle)
            .overlay {
                Circle().strokeBorder(color.opacity(0.4))
            }
    }

    private var statsSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "Game Stats", subtitle: "")

                HStack(spacing: 16) {
                    statItem(title: "Grid", value: "\(vm.settings.difficulty.gridSize)×\(vm.settings.difficulty.gridSize)", icon: "square.grid.3x3")
                    statItem(title: "Path", value: "\(vm.stepsToFind) steps", icon: "road.lanes")
                    statItem(title: "Mode", value: vm.settings.gameMode.title, icon: vm.settings.gameMode.icon)
                }

                if vm.settings.playType == .team {
                    HStack(spacing: 16) {
                        ForEach(vm.teams) { team in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(team.name)
                                    .font(.caption.weight(.bold))
                                HStack(spacing: 6) {
                                    Label(team.hintUsed ? "Used" : "Available", systemImage: "eye.fill")
                                        .font(.caption2)
                                        .foregroundStyle(team.hintUsed ? .orange : .green)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)
            Text(value)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button("Play Again") {
                restartGame()
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button("Exit") {
                onExit()
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    // MARK: - Confetti

    private var confettiOverlay: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { i in
                ConfettiPiece(index: i)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func playerColorForName(_ name: String) -> Color {
        let names = session.players.map(\.username)
        guard let idx = names.firstIndex(of: name) else { return .primary }
        return GamePlayerColor.color(for: idx)
    }

    private func restartGame() {
        let settings = appModel.currentMemoryPathSettings ?? .default
        let names = session.players.map(\.username)
        vm = MemoryPathViewModel()
        vm.configure(settings: settings, playerNames: names)
        vm.startGame()
    }
}

struct MemoryPathTileView: View {
    let tile: MemoryPathTile
    let tileSize: CGFloat
    let isWrong: Bool
    let progress: Int
    let pathLength: Int
    let onTap: () -> Void

    private var backgroundColor: Color {
        switch tile.state {
        case .hidden:
            return .white.opacity(0.06)
        case .correct:
            let fraction = pathLength > 0 ? Double(progress) / Double(pathLength) : 0
            return Color.teal.opacity(0.3 + fraction * 0.4)
        case .wrong:
            return .red.opacity(0.5)
        case .hintRevealed:
            return .orange.opacity(0.3)
        case .start:
            return .green.opacity(0.3)
        case .end:
            return .cyan.opacity(0.3)
        }
    }

    private var borderColor: Color {
        switch tile.state {
        case .hidden: return .white.opacity(0.08)
        case .correct: return .teal.opacity(0.5)
        case .wrong: return .red.opacity(0.7)
        case .hintRevealed: return .orange.opacity(0.5)
        case .start: return .green.opacity(0.5)
        case .end: return .cyan.opacity(0.5)
        }
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: tileSize > 40 ? 10 : 7)
                    .fill(backgroundColor)
                    .frame(width: tileSize, height: tileSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: tileSize > 40 ? 10 : 7)
                            .strokeBorder(borderColor, lineWidth: 1.2)
                    }

                if tile.state == .start {
                    Text("Start")
                        .font(.system(size: tileSize * 0.2, weight: .heavy))
                        .foregroundStyle(.green)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                } else if tile.state == .end {
                    Text("End")
                        .font(.system(size: tileSize * 0.22, weight: .heavy))
                        .foregroundStyle(.cyan)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                } else if tile.state == .correct {
                    Image(systemName: "checkmark")
                        .font(.system(size: tileSize * 0.25, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                } else if tile.state == .hintRevealed {
                    Circle()
                        .fill(.orange.opacity(0.5))
                        .frame(width: tileSize * 0.25, height: tileSize * 0.25)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(tile.state == .correct ? 1.05 : (isWrong ? 0.92 : 1.0))
        .offset(x: isWrong ? -4 : 0)
        .shadow(color: tile.state == .correct ? .teal.opacity(0.35) : .clear, radius: tile.state == .correct ? 10 : 0)
        .animation(.spring(duration: 0.22, bounce: 0.28), value: tile.state)
        .animation(.spring(duration: 0.1).repeatCount(3, autoreverses: true), value: isWrong)
        .disabled(tile.state == .correct || tile.state == .start)
    }
}

struct ConfettiPiece: View {
    let index: Int
    @State private var isAnimating: Bool = false

    private let colors: [Color] = [.yellow, .teal, .cyan, .green, .orange, .pink, .purple]

    var body: some View {
        Circle()
            .fill(colors[index % colors.count])
            .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
            .offset(
                x: isAnimating ? CGFloat.random(in: -180...180) : 0,
                y: isAnimating ? CGFloat.random(in: 200...600) : -50
            )
            .opacity(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: Double.random(in: 1.2...2.5)).delay(Double(index) * 0.03)) {
                    isAnimating = true
                }
            }
    }
}
