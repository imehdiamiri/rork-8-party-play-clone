import SwiftUI

struct ColorTrapSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @State private var viewModel = ColorTrapViewModel()
    @State private var currentPlayerIndex: Int = 0
    @State private var playerScores: [UUID: Int] = [:]
    @State private var playerStats: [UUID: (hits: Int, fails: Int, survival: Double, eliminated: Bool)] = [:]
    @State private var gamePhase: Phase = .ready

    enum Phase: Hashable { case ready, playing, playerComplete, results }

    private var isMultiDevice: Bool {
        session.mode != .singleDevice && session.colorTrapState != nil
    }

    private var settings: ColorTrapSettings {
        appModel.currentColorTrapSettings ?? .default
    }

    private var players: [PlayerProfile] { session.players }

    private var currentPlayer: PlayerProfile? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    private var localForbiddenColorIndex: Int {
        if let state = appModel.activeSession?.colorTrapState {
            return state.forbiddenColorIndex
        }
        return ColorTrapGenerator.pickForbiddenColor(seed: UInt64(abs(session.id.hashValue)))
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
        .navigationTitle("Color Trap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .firstTimeHint(
            key: "hint_seen_color_trap",
            icon: "paintpalette.fill",
            title: "Color Trap",
            tip: "Tap every color EXCEPT the forbidden one. Three wrong taps and you're out.",
            accent: .pink
        )
        .onDisappear { viewModel.cleanup() }
    }

    @ViewBuilder
    private var singleDeviceBody: some View {
        switch gamePhase {
        case .ready: readyView
        case .playing: gameplayView
        case .playerComplete: passPhoneView
        case .results: resultsView
        }
    }

    @ViewBuilder
    private var multiDeviceBody: some View {
        if let state = appModel.activeSession?.colorTrapState {
            let currentSession = appModel.activeSession ?? session
            let isMyTurn = appModel.isCurrentPlayerTurn(in: currentSession)
            let turnName = appModel.currentTurnPlayerName(in: currentSession)

            if state.isFinished {
                multiResultsView(state: state)
            } else if isMyTurn && gamePhase == .playing {
                playingLayout
                    .onChange(of: viewModel.isFinished) { _, done in
                        if done { handleMultiComplete() }
                    }
            } else if isMyTurn {
                multiReadyView(state: state)
            } else {
                multiWaitingView(state: state, turnName: turnName)
            }
        }
    }

    private func multiReadyView(state: ColorTrapGameState) -> some View {
        let forbidden = ColorTrapViewModel.palette[state.forbiddenColorIndex % ColorTrapViewModel.palette.count]
        return ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 100, height: 100)
                    .background(.pink.opacity(0.14), in: .rect(cornerRadius: 28))
                VStack(spacing: 8) {
                    Text("Your Turn! Start")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("Tap Start to begin your turn, then tap every color EXCEPT the one below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                forbiddenPreview(color: forbidden)
                HStack(spacing: 16) {
                    statBubble(title: state.resolvedDifficulty.title, subtitle: "Mode")
                    statBubble(title: "\(Int(state.resolvedDifficulty.totalDuration))s", subtitle: "Time")
                    statBubble(title: "\(ColorTrapViewModel.maxFails)", subtitle: "Lives")
                }
                Button("Start") {
                    FeedbackService.shared.playRoundStart()
                    viewModel.start(difficulty: state.resolvedDifficulty, seed: state.seed, forbiddenColorIndex: state.forbiddenColorIndex)
                    withAnimation(.spring(duration: 0.4)) { gamePhase = .playing }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 40)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func multiWaitingView(state: ColorTrapGameState, turnName: String?) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.pink)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Waiting for \(turnName ?? "player")...")
                    .font(.title2.weight(.bold))
                Text("Same tiles, same colors, same forbidden color.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                spectatorArenaPreview(state: state)
                    .padding(.horizontal, 16)

                if !state.playerResults.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Completed")
                                .font(.subheadline.weight(.semibold))
                            ForEach(state.playerResults) { r in
                                HStack {
                                    Text(r.playerName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(r.eliminated ? "OUT · \(r.hits) hits" : "\(r.score) pts")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(r.eliminated ? .red : .pink)
                                }
                                .padding(10)
                                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func spectatorArenaPreview(state: ColorTrapGameState) -> some View {
        let previewSpawns = Array(ColorTrapGenerator.generateSpawns(difficulty: state.resolvedDifficulty, seed: state.seed).prefix(8))
        let forbidden = ColorTrapViewModel.palette[state.forbiddenColorIndex % ColorTrapViewModel.palette.count]

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Spectator View", subtitle: "The live arena stays visible in black and white until your turn.")
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Forbidden")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(forbidden)
                        .frame(width: 28, height: 20)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(0.28))
                        }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))

                GeometryReader { geo in
                    let colWidth = geo.size.width / CGFloat(ColorTrapGenerator.columnCount)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.08))

                        ForEach(previewSpawns, id: \.id) { spawn in
                            let xCenter = colWidth * (CGFloat(spawn.columnIndex) + 0.5)
                            let tileSize = min(colWidth * 0.78, 60) * CGFloat(spawn.size)
                            let yOffset = (spawn.appearAt / max(state.resolvedDifficulty.totalDuration, 1)) * (geo.size.height - 70)
                            let color = ColorTrapViewModel.palette[spawn.colorIndex % ColorTrapViewModel.palette.count]

                            Circle()
                                .fill(color)
                                .overlay {
                                    Circle().strokeBorder(.white.opacity(0.32), lineWidth: 1.2)
                                }
                                .frame(width: tileSize, height: tileSize)
                                .position(x: xCenter, y: yOffset + 36)
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .saturation(0)
    }

    private func multiResultsView(state: ColorTrapGameState) -> some View {
        let sorted = state.playerResults.sorted { $0.score > $1.score }
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
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, r in
                        resultRow(rank: index + 1, name: r.playerName, score: r.score, hits: r.hits, fails: r.fails, eliminated: r.eliminated)
                    }
                }
                .padding(.horizontal, 16)

                MultiplayerResultActionsBar(appModel: appModel, session: currentSession, onExit: onExit)
                    .padding(.bottom, 28)
            }
        }
    }

    private func handleMultiComplete() {
        FeedbackService.shared.playSuccess()
        appModel.submitColorTrapResult(
            hits: viewModel.hits,
            fails: viewModel.fails,
            survivalTime: viewModel.elapsedSeconds,
            eliminated: viewModel.wasEliminated
        )
        viewModel.reset()
        gamePhase = .ready
    }

    private var readyView: some View {
        let forbidden = ColorTrapViewModel.palette[localForbiddenColorIndex % ColorTrapViewModel.palette.count]
        return ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 100, height: 100)
                    .background(.pink.opacity(0.14), in: .rect(cornerRadius: 28))
                VStack(spacing: 8) {
                    if players.count > 1, let player = currentPlayer {
                        CurrentTurnPill(playerName: player.username, prefix: "Now", accent: .green)
                        Text("Your turn! Avoid the forbidden color below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Color Trap")
                            .font(.title2.weight(.bold))
                        Text("Tap every color EXCEPT the one below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                forbiddenPreview(color: forbidden)
                HStack(spacing: 16) {
                    statBubble(title: settings.difficulty.title, subtitle: "Mode")
                    statBubble(title: "\(Int(settings.difficulty.totalDuration))s", subtitle: "Time")
                    statBubble(title: "\(ColorTrapViewModel.maxFails)", subtitle: "Lives")
                }
                Button("Start") {
                    FeedbackService.shared.playRoundStart()
                    let seed = UInt64.random(in: 1...UInt64.max)
                    viewModel.start(difficulty: settings.difficulty, seed: seed, forbiddenColorIndex: localForbiddenColorIndex)
                    withAnimation(.spring(duration: 0.4)) { gamePhase = .playing }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 40)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private var playingLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            forbiddenBanner
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            arena
                .padding(.horizontal, 12)
        }
    }

    private var gameplayView: some View {
        playingLayout
            .onChange(of: viewModel.isFinished) { _, done in
                if done { handlePlayerComplete() }
            }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if players.count > 1, let player = currentPlayer {
                    CurrentTurnPill(playerName: player.username, prefix: "Now", accent: .green)
                } else {
                    Text("Color Trap")
                        .font(.headline.weight(.bold))
                }
                HStack(spacing: 6) {
                    ForEach(0..<ColorTrapViewModel.maxFails, id: \.self) { idx in
                        Image(systemName: idx < viewModel.fails ? "heart.slash.fill" : "heart.fill")
                            .font(.caption)
                            .foregroundStyle(idx < viewModel.fails ? .red.opacity(0.4) : .red)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("\(viewModel.hits)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.green.opacity(0.1), in: .capsule)

                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                    Text(String(format: "%.1fs", max(0, viewModel.difficulty.totalDuration - viewModel.elapsedSeconds)))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.pink.opacity(0.1), in: .capsule)
            }
        }
    }

    private var forbiddenBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Avoid")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.forbiddenColor)
                .frame(width: 28, height: 20)
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.4)) }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))
    }

    private var arena: some View {
        GeometryReader { geo in
            let colWidth = geo.size.width / CGFloat(ColorTrapGenerator.columnCount)
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.15)
                    .clipShape(.rect(cornerRadius: 16))

                ForEach(viewModel.activeTiles) { tile in
                    let timeAlive = viewModel.elapsedSeconds - tile.spawnedAt
                    let lifetime = viewModel.difficulty.tileLifetime
                    let t = max(0, min(1, timeAlive / lifetime))
                    let maxY = geo.size.height - 80
                    let yOffset: CGFloat = CGFloat(t) * maxY
                    let xCenter: CGFloat = colWidth * (CGFloat(tile.columnIndex) + 0.5)
                    let tileSize: CGFloat = min(colWidth * 0.78, 72) * CGFloat(tile.size)
                    let color = ColorTrapViewModel.palette[tile.colorIndex % ColorTrapViewModel.palette.count]

                    Button {
                        viewModel.tap(tileID: tile.id)
                    } label: {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [color.opacity(0.95), color.opacity(0.55)],
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: tileSize
                                )
                            )
                            .overlay { Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1.5) }
                            .shadow(color: color.opacity(0.55), radius: 8, y: 3)
                            .scaleEffect(tile.isHit ? 0.5 : 1)
                            .opacity(tile.isHit ? 0 : 1)
                            .animation(.spring(duration: 0.3), value: tile.isHit)
                            .frame(width: tileSize, height: tileSize)
                    }
                    .buttonStyle(.plain)
                    .position(x: xCenter, y: yOffset + 40)
                    .disabled(!viewModel.isActive || tile.isHit)
                }
            }
        }
    }

    private func forbiddenPreview(color: Color) -> some View {
        VStack(spacing: 8) {
            Text("Forbidden Color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 14)
                .fill(color)
                .frame(width: 120, height: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 2)
                }
                .shadow(color: color.opacity(0.5), radius: 8, y: 3)
        }
    }

    private var passPhoneView: some View {
        GamePassPhoneView(
            playerName: players[safe: currentPlayerIndex]?.username ?? "Next Player",
            subtitle: "Pass the phone. Ready to dodge the forbidden color?",
            accentColor: .pink,
            buttonTitle: "I'm Ready"
        ) {
            FeedbackService.shared.playRoundStart()
            withAnimation(.spring(duration: 0.4)) { gamePhase = .ready }
        }
    }

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .padding(.top, 20)
                    Text(players.count > 1 ? "Final Rankings" : "Complete!")
                        .font(.title2.weight(.bold))
                }
                VStack(spacing: 10) {
                    let sorted = players.sorted { (playerScores[$0.id] ?? 0) > (playerScores[$1.id] ?? 0) }
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, p in
                        let stats = playerStats[p.id] ?? (0, 0, 0, false)
                        resultRow(rank: index + 1, name: p.username, score: playerScores[p.id] ?? 0, hits: stats.hits, fails: stats.fails, eliminated: stats.eliminated)
                    }
                }
                .padding(.horizontal, 16)

                Button("Play Again") { restart() }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
        }
    }

    private func resultRow(rank: Int, name: String, score: Int, hits: Int, fails: Int, eliminated: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? .yellow.opacity(0.2) : .white.opacity(0.06))
                    .frame(width: 40, height: 40)
                Text("\(rank)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(rank == 1 ? .yellow : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold))
                Text("\(hits) hits · \(fails) miss\(eliminated ? " · eliminated" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(score)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.pink)
            if rank == 1 {
                Image(systemName: "crown.fill").foregroundStyle(.yellow)
            }
        }
        .padding(12)
        .background(rank == 1 ? .yellow.opacity(0.06) : .white.opacity(0.035), in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(rank == 1 ? .yellow.opacity(0.2) : .white.opacity(0.04)) }
    }

    private func statBubble(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.headline.weight(.bold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
    }

    private func handlePlayerComplete() {
        FeedbackService.shared.playSuccess()
        let score = viewModel.hits * 10 + Int(viewModel.elapsedSeconds * 5) - viewModel.fails * 15
        if let player = currentPlayer {
            playerScores[player.id] = max(0, score)
            playerStats[player.id] = (viewModel.hits, viewModel.fails, viewModel.elapsedSeconds, viewModel.wasEliminated)
        }
        currentPlayerIndex += 1
        if currentPlayerIndex >= players.count {
            withAnimation(.spring(duration: 0.5)) { gamePhase = .results }
        } else {
            withAnimation(.spring(duration: 0.4)) { gamePhase = .playerComplete }
        }
    }

    private func restart() {
        viewModel.reset()
        currentPlayerIndex = 0
        playerScores = [:]
        playerStats = [:]
        gamePhase = .ready
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
