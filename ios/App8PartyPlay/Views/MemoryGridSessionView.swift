import SwiftUI

struct MemoryGridSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @State private var viewModel = MemoryGridViewModel()
    @State private var currentPlayerIndex: Int = 0
    @State private var playerTimes: [UUID: Double] = [:]
    @State private var gamePhase: MemoryGridPhase = .ready
    @State private var spectatorBroadcastTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase

    private var isMultiDevice: Bool {
        session.mode != .singleDevice && session.memoryGridState != nil
    }

    private var settings: MemoryGridSettings {
        appModel.currentMemoryGridSettings ?? .default
    }

    private var players: [PlayerProfile] {
        session.players
    }

    private var currentPlayer: PlayerProfile? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            if isMultiDevice {
                multiDeviceBody
            } else {
                singleDeviceBody
            }
        }
        .navigationTitle("Memory Grid")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .firstTimeHint(
            key: "hint_seen_memory_grid",
            icon: "square.grid.3x3.fill",
            title: "Memory Grid",
            tip: "Flip two tiles at a time. Match every pair as fast as you can.",
            accent: .cyan
        )
        .onAppear {
            if isMultiDevice {
                viewModel.onStateChange = { [weak appModel, weak viewModel] in
                    guard let appModel, let viewModel else { return }
                    appModel.broadcastMemoryGridSpectatorState(
                        tiles: viewModel.tiles,
                        matchedPairs: viewModel.matchedPairs,
                        moveCount: viewModel.moveCount,
                        elapsedSeconds: viewModel.elapsedSeconds
                    )
                }
                startSpectatorBroadcastTimer()
            }
        }
        .onDisappear {
            viewModel.onStateChange = nil
            viewModel.cleanup()
            spectatorBroadcastTimer?.invalidate()
            spectatorBroadcastTimer = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isMultiDevice {
                appModel.rebroadcastCurrentCasualSessionState(attempts: 2)
                if appModel.isCurrentPlayerTurn(in: appModel.activeSession ?? session) {
                    appModel.broadcastMemoryGridSpectatorState(
                        tiles: viewModel.tiles,
                        matchedPairs: viewModel.matchedPairs,
                        moveCount: viewModel.moveCount,
                        elapsedSeconds: viewModel.elapsedSeconds
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var singleDeviceBody: some View {
        switch gamePhase {
        case .ready:
            readyView
        case .playing:
            gameplayView
        case .playerComplete:
            playerCompleteView
        case .results:
            resultsView
        }
    }

    @ViewBuilder
    private var multiDeviceBody: some View {
        if let mg = appModel.activeSession?.memoryGridState ?? session.memoryGridState {
            let currentSession = appModel.activeSession ?? session
            let isMyTurn = appModel.isCurrentPlayerTurn(in: currentSession)
            let turnPlayerName = appModel.currentTurnPlayerName(in: currentSession)
            let gridSize = mg.resolvedGridSize

            if mg.isFinished {
                multiResultsView(mg: mg, players: currentSession.players)
            } else if isMyTurn && gamePhase == .playing {
                VStack(spacing: 0) {
                    gameHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    progressBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    gridBoard
                        .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                }
                .onChange(of: viewModel.isGameComplete) { _, complete in
                    if complete {
                        handleMultiPlayerComplete()
                    }
                }
            } else if isMyTurn {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.cyan)
                            .frame(width: 100, height: 100)
                            .background(.cyan.opacity(0.14), in: .rect(cornerRadius: 28))
                        VStack(spacing: 8) {
                            Text("Your Turn! Start")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.green)
                            Text("Tap Start to begin your turn and find all matching pairs as fast as you can.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        HStack(spacing: 16) {
                            statBubble(title: gridSize.title, subtitle: "Grid")
                            statBubble(title: "\(gridSize.pairCount)", subtitle: "Pairs")
                            statBubble(title: "\(mg.currentPlayerIndex + 1)/\(currentSession.players.count)", subtitle: "Player")
                        }
                        Button("Start") {
                            FeedbackService.shared.playRoundStart()
                            viewModel.startGame(size: gridSize)
                            withAnimation(.spring(duration: 0.4)) {
                                gamePhase = .playing
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .padding(.horizontal, 40)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                multiWaitingView(mg: mg, turnPlayerName: turnPlayerName, players: currentSession.players)
            }
        }
    }

    private func multiWaitingView(mg: MemoryGridGameState, turnPlayerName: String?, players: [PlayerProfile]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Waiting for \(turnPlayerName ?? "player")...")
                    .font(.title2.weight(.bold))
                Text("Watch their board live, in black & white.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let snap = mg.spectator {
                    spectatorLiveGrid(snap: snap, gridSize: mg.resolvedGridSize)
                        .padding(.horizontal, 16)
                } else {
                    spectatorGridPreview(gridSize: mg.resolvedGridSize)
                        .padding(.horizontal, 16)
                }

                if !mg.playerResults.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Completed")
                                .font(.subheadline.weight(.semibold))
                            ForEach(mg.playerResults) { result in
                                HStack {
                                    Text(result.playerName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(String(format: "%.1fs", result.elapsedSeconds))
                                        .font(.subheadline.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(.cyan)
                                }
                                .padding(10)
                                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                statBubble(title: "\(mg.currentPlayerIndex + 1)/\(players.count)", subtitle: "Player")

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func spectatorLiveGrid(snap: MGSpectatorSnapshot, gridSize: MemoryGridSize) -> some View {
        let cols = gridSize.cols
        let rows = gridSize.rows
        let spacing: CGFloat = 8
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Spectator View", subtitle: "\(snap.playerName)'s live board — \(snap.matchedPairs)/\(gridSize.pairCount) pairs · \(snap.moveCount) moves · \(String(format: "%.1fs", snap.elapsedSeconds))")
                GeometryReader { geo in
                    let availableWidth = geo.size.width - CGFloat(cols - 1) * spacing
                    let tileWidth = availableWidth / CGFloat(cols)
                    let availableHeight = geo.size.height - CGFloat(rows - 1) * spacing
                    let tileHeight = availableHeight / CGFloat(rows)
                    let tileSize = min(tileWidth, tileHeight)

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(Array(snap.tiles.enumerated()), id: \.offset) { _, tile in
                            spectatorTileView(tile: tile)
                                .frame(height: tileSize)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: min(CGFloat(rows) * 68, 360))
            }
        }
        .saturation(0)
    }

    private func spectatorTileView(tile: MGSpectatorTile) -> some View {
        let isShowing = tile.isFlipped || tile.isMatched
        return ZStack {
            if isShowing {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(tile.isMatched ? 0.35 : 0.55),
                                Color.white.opacity(tile.isMatched ? 0.2 : 0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: tile.symbol)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                    }
                    .opacity(tile.isMatched ? 0.6 : 1)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "questionmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1.5)
                    }
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.1), value: tile.isFlipped)
        .animation(.spring(duration: 0.35, bounce: 0.1), value: tile.isMatched)
    }

    private func spectatorGridPreview(gridSize: MemoryGridSize) -> some View {
        let cols = gridSize.cols
        let rows = gridSize.rows
        let spacing: CGFloat = 8
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Spectator View", subtitle: "The board stays visible in black and white until your turn.")
                GeometryReader { geo in
                    let availableWidth = geo.size.width - CGFloat(cols - 1) * spacing
                    let tileWidth = availableWidth / CGFloat(cols)
                    let availableHeight = geo.size.height - CGFloat(rows - 1) * spacing
                    let tileHeight = availableHeight / CGFloat(rows)
                    let tileSize = min(tileWidth, tileHeight)

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(0..<(rows * cols), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.18), .white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Image(systemName: "questionmark")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.white.opacity(0.16), lineWidth: 1.5)
                                }
                                .frame(height: tileSize)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: min(CGFloat(rows) * 68, 320))
            }
        }
        .saturation(0)
    }

    private func multiResultsView(mg: MemoryGridGameState, players: [PlayerProfile]) -> some View {
        let sorted = mg.playerResults.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
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
                                Text(String(format: "%.1fs · %d moves", result.elapsedSeconds, result.moveCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

    private func startSpectatorBroadcastTimer() {
        spectatorBroadcastTimer?.invalidate()
        spectatorBroadcastTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            Task { @MainActor in
                guard isMultiDevice,
                      let current = appModel.activeSession,
                      appModel.isCurrentPlayerTurn(in: current),
                      !viewModel.tiles.isEmpty,
                      gamePhase == .playing else { return }
                appModel.broadcastMemoryGridSpectatorState(
                    tiles: viewModel.tiles,
                    matchedPairs: viewModel.matchedPairs,
                    moveCount: viewModel.moveCount,
                    elapsedSeconds: viewModel.elapsedSeconds
                )
            }
        }
    }

    private func handleMultiPlayerComplete() {
        SoundManager.shared.playVictory()
        FeedbackService.shared.playSuccess()
        appModel.submitMemoryGridResult(elapsedSeconds: viewModel.elapsedSeconds, moveCount: viewModel.moveCount)
        viewModel.resetGame()
        gamePhase = .ready
    }

    private func statBubble(title: String, subtitle: String) -> some View {
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

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 100, height: 100)
                    .background(.cyan.opacity(0.14), in: .rect(cornerRadius: 28))

                VStack(spacing: 8) {
                    if players.count > 1, let player = currentPlayer {
                        CurrentTurnPill(playerName: player.username, prefix: "Now", accent: .green)
                        Text("Your turn! Get ready to memorize.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Memory Grid")
                            .font(.title2.weight(.bold))
                        Text("Find all matching pairs!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 16) {
                    statBubble(title: settings.gridSize.title, subtitle: "Grid")
                    statBubble(title: "\(settings.gridSize.pairCount)", subtitle: "Pairs")
                    if players.count > 1 {
                        statBubble(title: "\(currentPlayerIndex + 1)/\(players.count)", subtitle: "Player")
                    }
                }

                Button("Start") {
                    FeedbackService.shared.playRoundStart()
                    withAnimation(.spring(duration: 0.4)) {
                        gamePhase = .playing
                    }
                    viewModel.startGame(size: settings.gridSize)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 40)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private var gameplayView: some View {
        VStack(spacing: 0) {
            gameHeader
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            progressBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            gridBoard
                .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .onChange(of: viewModel.isGameComplete) { _, complete in
            if complete {
                handlePlayerComplete()
            }
        }
    }

    private var gameHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if players.count > 1, let player = currentPlayer {
                    CurrentTurnPill(playerName: player.username, prefix: "Now", accent: .green)
                } else {
                    Text("Memory Grid")
                        .font(.headline.weight(.bold))
                }
                Text("\(viewModel.matchedPairs)/\(viewModel.totalPairs) pairs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(viewModel.moveCount)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1), in: .capsule)

                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    Text(viewModel.formattedTime)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.cyan.opacity(0.1), in: .capsule)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * viewModel.progress, 4))
                    .animation(.spring(duration: 0.4), value: viewModel.progress)
            }
        }
        .frame(height: 6)
    }

    private var gridBoard: some View {
        let cols = settings.gridSize.cols
        let rows = settings.gridSize.rows
        let spacing: CGFloat = 8
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)

        return GeometryReader { geo in
            let availableWidth = geo.size.width - CGFloat(cols - 1) * spacing
            let tileWidth = availableWidth / CGFloat(cols)
            let availableHeight = geo.size.height - CGFloat(rows - 1) * spacing
            let tileHeightFromRows = availableHeight / CGFloat(rows)
            let tileSize = min(tileWidth, tileHeightFromRows)

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(viewModel.tiles.enumerated()), id: \.element.id) { index, tile in
                    MemoryTileView(tile: tile) {
                        viewModel.flipTile(at: index)
                    }
                    .frame(height: tileSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var playerCompleteView: some View {
        if currentPlayerIndex < players.count {
            return AnyView(
                GamePassPhoneView(
                    playerName: players[currentPlayerIndex].username,
                    subtitle: "Make sure no one else is looking at the tiles!",
                    accentColor: .cyan,
                    buttonTitle: "I'm Ready"
                ) {
                    FeedbackService.shared.playRoundStart()
                    withAnimation(.spring(duration: 0.4)) {
                        gamePhase = .ready
                    }
                }
            )
        }
        return AnyView(
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: gamePhase)
                    VStack(spacing: 6) {
                        if let player = players[safe: currentPlayerIndex - 1] {
                            Text("\(player.username) Finished!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(GamePlayerColor.color(for: player.id, in: players))
                        }
                        Text(String(format: "%.1fs · %d moves", playerTimes[players[safe: currentPlayerIndex - 1]?.id ?? UUID()] ?? 0, viewModel.moveCount))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
            }
        )
    }

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .padding(.top, 20)
                        .symbolEffect(.bounce, value: gamePhase)

                    Text(players.count > 1 ? "Final Rankings" : "Complete!")
                        .font(.title2.weight(.bold))
                }

                VStack(spacing: 10) {
                    let sorted = sortedResults()
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, player in
                        let time = playerTimes[player.id] ?? 999
                        resultRow(player: player, rank: index + 1, time: time)
                    }
                }
                .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    Button("Play Again") {
                        restartGame()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }

    private func resultRow(player: PlayerProfile, rank: Int, time: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? .yellow.opacity(0.2) : .white.opacity(0.06))
                    .frame(width: 40, height: 40)
                Text("\(rank)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(rank == 1 ? .yellow : rank == 2 ? .gray : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GamePlayerColor.color(for: player.id, in: players))
                Text(String(format: "%.1f seconds", time))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(12)
        .background(rank == 1 ? .yellow.opacity(0.06) : .white.opacity(0.035), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(rank == 1 ? .yellow.opacity(0.2) : .white.opacity(0.04))
        }
    }

    private func handlePlayerComplete() {
        SoundManager.shared.playVictory()
        FeedbackService.shared.playSuccess()
        if let player = currentPlayer {
            playerTimes[player.id] = viewModel.elapsedSeconds
        }
        currentPlayerIndex += 1

        if currentPlayerIndex >= players.count {
            withAnimation(.spring(duration: 0.5)) {
                gamePhase = .results
            }
        } else {
            withAnimation(.spring(duration: 0.4)) {
                gamePhase = .playerComplete
            }
        }
    }

    private func restartGame() {
        viewModel.resetGame()
        currentPlayerIndex = 0
        playerTimes = [:]
        gamePhase = .ready
    }

    private func sortedResults() -> [PlayerProfile] {
        players.sorted { lhs, rhs in
            let lhsTime = playerTimes[lhs.id] ?? 999
            let rhsTime = playerTimes[rhs.id] ?? 999
            return lhsTime < rhsTime
        }
    }
}

nonisolated enum MemoryGridPhase: Hashable, Sendable {
    case ready
    case playing
    case playerComplete
    case results
}

struct MemoryTileView: View {
    let tile: MemoryTile
    let onTap: () -> Void

    private static let tileColors: [Color] = [
        .cyan, .pink, .orange, .green, .purple,
        .yellow, .mint, .red, .indigo, .teal
    ]

    private var tileColor: Color {
        Self.tileColors[tile.colorIndex % Self.tileColors.count]
    }

    private var isShowingFront: Bool {
        tile.isFlipped || tile.isMatched
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isShowingFront {
                    frontFace
                        .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
                } else {
                    backFace
                        .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
                }
            }
        }
        .buttonStyle(.plain)
        .rotation3DEffect(
            .degrees(isShowingFront ? 0 : 180),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
        .animation(.spring(duration: 0.45, bounce: 0.15), value: tile.isFlipped)
        .disabled(tile.isFlipped || tile.isMatched)
        .opacity(tile.isMatched ? 0.55 : 1)
        .scaleEffect(tile.isMatched ? 0.94 : 1)
        .animation(.spring(duration: 0.4), value: tile.isMatched)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: tile.isFlipped)
    }

    private var frontFace: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [
                        tileColor.opacity(tile.isMatched ? 0.35 : 0.65),
                        tileColor.opacity(tile.isMatched ? 0.2 : 0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.35), .clear],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 90
                        )
                    )
            }
            .overlay {
                Image(systemName: tile.symbol)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: tileColor.opacity(0.9), radius: 6)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tileColor.opacity(tile.isMatched ? 0.45 : 0.9), lineWidth: 2)
            }
            .shadow(color: tileColor.opacity(tile.isMatched ? 0.15 : 0.45), radius: 8, y: 3)
    }

    private var backFace: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.25, blue: 0.55),
                        Color(red: 0.12, green: 0.14, blue: 0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.28), Color.clear],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 80
                        )
                    )
            }
            .overlay {
                Image(systemName: "questionmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.85), .cyan.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .cyan.opacity(0.6), radius: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.cyan.opacity(0.55), .purple.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: .blue.opacity(0.25), radius: 6, y: 3)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
