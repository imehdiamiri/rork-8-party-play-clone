import SwiftUI

struct TapInOrderSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @State private var viewModel = TapInOrderViewModel()
    @State private var currentPlayerIndex: Int = 0
    @State private var playerResults: [UUID: LocalResult] = [:]
    @State private var gamePhase: Phase = .ready
    @State private var showOutcomeOverlay: Bool = false
    @State private var outcomeIsWin: Bool = false
    @State private var gaveUp: Bool = false
    @State private var showGiveUpConfirm: Bool = false

    struct LocalResult: Hashable {
        let elapsed: Double
        let correct: Int
        let total: Int
        let miss: Int
        let didFinish: Bool
    }

    enum Phase: Hashable { case ready, playing, outcome, playerComplete, results }

    private var isMultiDevice: Bool {
        session.mode != .singleDevice && session.tapInOrderState != nil
    }

    private var settings: TapInOrderSettings {
        appModel.currentTapInOrderSettings ?? .default
    }

    private var players: [PlayerProfile] { session.players }

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

            if showOutcomeOverlay {
                outcomeOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .navigationTitle("Tap in Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .firstTimeHint(
            key: "hint_seen_tap_in_order",
            icon: "brain.head.profile",
            title: "Memorize. Tap.",
            tip: "You have a few seconds to memorize. Fewer mistakes win — time is just for reference.",
            accent: .orange
        )
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Single Device

    @ViewBuilder
    private var singleDeviceBody: some View {
        switch gamePhase {
        case .ready: readyView
        case .playing, .outcome: gameplayView
        case .playerComplete: passPhoneView
        case .results: resultsView
        }
    }

    // MARK: - Multi Device

    @ViewBuilder
    private var multiDeviceBody: some View {
        if let state = appModel.activeSession?.tapInOrderState {
            let currentSession = appModel.activeSession ?? session
            let isMyTurn = appModel.isCurrentPlayerTurn(in: currentSession)
            let turnName = appModel.currentTurnPlayerName(in: currentSession)

            if state.isFinished {
                multiResultsView(state: state, players: currentSession.players)
            } else if isMyTurn && (gamePhase == .playing || gamePhase == .outcome) {
                playingLayout
                    .onChange(of: viewModel.isComplete) { _, done in
                        if done { handleMultiComplete() }
                    }
            } else if isMyTurn {
                multiReadyView(state: state, players: currentSession.players)
            } else {
                multiWaitingView(state: state, turnName: turnName, players: currentSession.players)
            }
        }
    }

    private func multiReadyView(state: TapInOrderGameState, players: [PlayerProfile]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: state.resolvedVariant.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 100, height: 100)
                    .background(.orange.opacity(0.14), in: .rect(cornerRadius: 28))
                VStack(spacing: 8) {
                    Text("Your Turn! Start")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("Tap Start to begin your turn.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(state.resolvedVariant.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 16) {
                    statBubble(title: state.resolvedVariant.title, subtitle: "Mode")
                    statBubble(title: "\(state.gridSize)×\(state.gridSize)", subtitle: "Grid")
                    statBubble(title: "\(state.tileCount)", subtitle: "Tiles")
                }
                Button("Start") {
                    FeedbackService.shared.playRoundStart()
                    viewModel.start(variant: state.resolvedVariant, gridSize: state.gridSize, tileCount: state.tileCount, seed: state.seed, providedCells: state.selectedCells)
                    withAnimation(.spring(duration: 0.4)) { gamePhase = .playing }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 40)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func multiWaitingView(state: TapInOrderGameState, turnName: String?, players: [PlayerProfile]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Waiting for \(turnName ?? "player")...")
                    .font(.title2.weight(.bold))
                Text("Same board. Best memory wins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                spectatorBoardPreview(state: state)
                    .padding(.horizontal, 16)

                if !state.playerResults.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Completed")
                                .font(.subheadline.weight(.semibold))
                            ForEach(state.playerResults) { result in
                                HStack {
                                    Text(result.playerName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(result.correctCount)/\(result.totalTargets) · \(String(format: "%.1fs", result.elapsedSeconds))")
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(.orange)
                                }
                                .padding(10)
                                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                statBubble(title: "\(state.currentPlayerIndex + 1)/\(players.count)", subtitle: "Player")

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func spectatorBoardPreview(state: TapInOrderGameState) -> some View {
        let cols = state.gridSize
        let spacing: CGFloat = 6
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Spectator View", subtitle: "Same layout, shown in black and white until your turn.")
                GeometryReader { geo in
                    let available = geo.size.width - CGFloat(cols - 1) * spacing
                    let tileSize = available / CGFloat(cols)
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(0..<(cols * cols), id: \.self) { index in
                            spectatorTile(index: index, state: state)
                                .frame(height: tileSize)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: min(CGFloat(cols) * 64, 320))
            }
        }
        .saturation(0)
    }

    private func spectatorTile(index: Int, state: TapInOrderGameState) -> some View {
        let isSelected = state.selectedCells.contains(index)
        let number = state.resolvedVariant == .numberMemory ? state.selectedCells.firstIndex(of: index).map { $0 + 1 } : nil
        let baseColor: Color = isSelected ? .white.opacity(0.28) : .white.opacity(0.08)
        let borderColor: Color = isSelected ? .white.opacity(0.38) : .white.opacity(0.14)
        let cornerRadius: CGFloat = state.gridSize >= 6 ? 10 : 14

        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [baseColor, baseColor.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if let number {
                    Text("\(number)")
                        .font(.system(size: state.gridSize >= 6 ? 18 : 24, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.86))
                } else if isSelected {
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 18, height: 18)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            }
    }

    private func multiResultsView(state: TapInOrderGameState, players: [PlayerProfile]) -> some View {
        let ranked = state.playerResults.sorted { lhs, rhs in
            if lhs.missTaps != rhs.missTaps { return lhs.missTaps < rhs.missTaps }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
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
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, r in
                        resultRow(rank: index + 1, name: r.playerName, correct: r.correctCount, total: r.totalTargets, miss: r.missTaps, time: r.elapsedSeconds, didFinish: r.didFinish)
                    }
                }
                .padding(.horizontal, 16)

                MultiplayerResultActionsBar(appModel: appModel, session: currentSession, onExit: onExit)
                    .padding(.bottom, 28)
            }
        }
    }

    private func handleMultiComplete() {
        let didWin = viewModel.didWin
        outcomeIsWin = didWin
        if gaveUp {
            FeedbackService.shared.playError()
        } else {
            SoundManager.shared.playVictory()
            FeedbackService.shared.playSuccess()
        }
        withAnimation(.spring(duration: 0.4)) {
            showOutcomeOverlay = true
            gamePhase = .outcome
        }
        appModel.submitTapInOrderResult(variant: viewModel.variant.rawValue, elapsedSeconds: viewModel.elapsedSeconds, correctCount: viewModel.correctCount, totalTargets: viewModel.totalTargets, missTaps: viewModel.missTaps, didFinish: didWin)
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            await MainActor.run {
                withAnimation(.spring(duration: 0.4)) { showOutcomeOverlay = false }
                gaveUp = false
                viewModel.reset()
                gamePhase = .ready
            }
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: settings.variant.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 100, height: 100)
                    .background(.orange.opacity(0.14), in: .rect(cornerRadius: 28))
                VStack(spacing: 8) {
                    if players.count > 1, let player = currentPlayer {
                        CurrentTurnPill(playerName: player.username, prefix: "Now", accent: .green)
                        Text("Your turn! Memorize carefully.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(settings.variant.title)
                            .font(.title2.weight(.bold))
                        Text(settings.variant.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Label("Fewest mistakes wins", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.top, 4)
                }
                HStack(spacing: 16) {
                    statBubble(title: "\(settings.gridSize)×\(settings.gridSize)", subtitle: "Grid")
                    statBubble(title: "\(settings.tileCount)", subtitle: "Tiles")
                    if players.count > 1 {
                        statBubble(title: "\(currentPlayerIndex + 1)/\(players.count)", subtitle: "Player")
                    }
                }
                Button("Start") {
                    FeedbackService.shared.playRoundStart()
                    let seed = UInt64.random(in: 1...UInt64.max)
                    viewModel.start(variant: settings.variant, gridSize: settings.gridSize, tileCount: settings.tileCount, seed: seed)
                    withAnimation(.spring(duration: 0.4)) { gamePhase = .playing }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 40)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Gameplay

    private var playingLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
            statsRow
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            progressBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            board
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
            if viewModel.phase == .playing {
                Button(role: .destructive) {
                    showGiveUpConfirm = true
                } label: {
                    Label("Give Up", systemImage: "flag.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .confirmationDialog("Give up your turn?", isPresented: $showGiveUpConfirm, titleVisibility: .visible) {
            Button("Give Up", role: .destructive) { performGiveUp() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text(players.count > 1 ? "Your progress will be kept. Next player will continue." : "Your progress will be saved.")
        }
    }

    private var gameplayView: some View {
        playingLayout
            .onChange(of: viewModel.isComplete) { _, done in
                if done { handlePlayerComplete() }
            }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if players.count > 1, let player = currentPlayer {
                    Text(player.username)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GamePlayerColor.color(for: player.id, in: players))
                } else {
                    Text(viewModel.variant.title)
                        .font(.headline.weight(.bold))
                }
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCard(
                icon: "xmark.circle.fill",
                value: "\(viewModel.missTaps)",
                label: "Mistakes",
                color: .red,
                bounceTrigger: viewModel.missTaps
            )
            statCard(
                icon: "checkmark.seal.fill",
                value: "\(viewModel.correctCount)/\(viewModel.totalTargets)",
                label: "Correct",
                color: .green,
                bounceTrigger: viewModel.correctCount
            )
            statCard(
                icon: viewModel.phase == .preview ? "eye.fill" : "timer",
                value: viewModel.phase == .preview ? String(format: "%.1f", viewModel.previewRemaining) : viewModel.formattedTime,
                label: viewModel.phase == .preview ? "Preview" : "Time",
                color: .orange,
                bounceTrigger: 0
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color, bounceTrigger: Int) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: bounceTrigger)
                Text(value)
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        }
    }

    private var headerSubtitle: String {
        if viewModel.phase == .preview {
            switch viewModel.variant {
            case .numberMemory: return "Memorize the numbers..."
            case .patternMemory: return "Memorize the pattern..."
            }
        }
        switch viewModel.variant {
        case .numberMemory: return "Next: \(viewModel.nextExpected) · \(viewModel.missTaps) mistakes"
        case .patternMemory: return "Tap the correct tiles · \(viewModel.missTaps) mistakes"
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * previewOrProgress, 4))
                    .animation(.spring(duration: 0.4), value: previewOrProgress)
            }
        }
        .frame(height: 6)
    }

    private var previewOrProgress: Double {
        if viewModel.phase == .preview {
            let total = max(viewModel.previewTotal, 0.1)
            return 1.0 - (viewModel.previewRemaining / total)
        }
        return viewModel.progress
    }

    private var board: some View {
        let cols = viewModel.gridSize
        let spacing: CGFloat = 6
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)
        return GeometryReader { geo in
            let available = geo.size.width - CGFloat(cols - 1) * spacing
            let tile = available / CGFloat(cols)
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(0..<(cols * cols), id: \.self) { index in
                    Button {
                        viewModel.tap(cellIndex: index)
                    } label: {
                        tileContent(index: index)
                            .frame(height: tile)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTap(index: index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func canTap(index: Int) -> Bool {
        guard viewModel.phase == .playing else { return false }
        if viewModel.tappedCells.contains(index) { return false }
        return true
    }

    private func tileContent(index: Int) -> some View {
        let isSelected = viewModel.selectedCells.contains(index)
        let isTapped = viewModel.tappedCells.contains(index)
        let isWrong = viewModel.wrongTileFlash == index
        let isPreview = viewModel.phase == .preview

        let number: Int? = viewModel.numberForCell[index]
        let tappedCorrect = isTapped && (viewModel.variant == .numberMemory || (viewModel.variant == .patternMemory && isSelected))
        let tappedWrongPersist = isTapped && viewModel.variant == .patternMemory && !isSelected

        let baseColor: Color = {
            if isPreview {
                return isSelected ? .orange : .gray
            }
            if tappedCorrect { return .green }
            if tappedWrongPersist { return .red }
            return .gray
        }()

        let opacityHigh: Double = {
            if isPreview && isSelected { return 0.55 }
            if tappedCorrect { return 0.55 }
            if tappedWrongPersist { return 0.45 }
            return 0.18
        }()
        let opacityLow: Double = {
            if isPreview && isSelected { return 0.3 }
            if tappedCorrect { return 0.3 }
            if tappedWrongPersist { return 0.22 }
            return 0.08
        }()

        let cornerRadius: CGFloat = viewModel.gridSize >= 6 ? 10 : 14
        let numberFontSize: CGFloat = {
            switch viewModel.gridSize {
            case 4: return 28
            case 5: return 22
            case 6: return 18
            default: return 15
            }
        }()

        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [baseColor.opacity(opacityHigh), baseColor.opacity(opacityLow)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                if isPreview, viewModel.variant == .numberMemory, let n = number {
                    Text("\(n)")
                        .font(.system(size: numberFontSize, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                } else if tappedCorrect, viewModel.variant == .numberMemory, let n = number {
                    Text("\(n)")
                        .font(.system(size: numberFontSize * 0.85, weight: .heavy))
                        .foregroundStyle(.white)
                } else if tappedCorrect, viewModel.variant == .patternMemory {
                    Image(systemName: "checkmark")
                        .font(.system(size: numberFontSize * 0.85, weight: .heavy))
                        .foregroundStyle(.white)
                } else if tappedWrongPersist {
                    Image(systemName: "xmark")
                        .font(.system(size: numberFontSize * 0.85, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isWrong ? .red : baseColor.opacity(isPreview && isSelected ? 0.6 : 0.2), lineWidth: isWrong ? 2.5 : 1.5)
            }
            .scaleEffect(isWrong ? 0.92 : 1)
            .animation(.spring(duration: 0.25), value: isWrong)
            .animation(.spring(duration: 0.3), value: isTapped)
    }

    // MARK: - Outcome overlay

    private var outcomeOverlay: some View {
        let accent: Color = gaveUp ? .orange : .green
        let icon: String = gaveUp ? "flag.fill" : "checkmark.seal.fill"
        let title: String = gaveUp ? "Gave Up" : "Done!"
        return ZStack {
            accent
                .opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(accent)
                    .symbolEffect(.bounce, value: showOutcomeOverlay)
                    .shadow(color: accent.opacity(0.5), radius: 20)
                Text(title)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(accent)
                Text("\(viewModel.missTaps) mistakes · \(viewModel.formattedTime)s")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if players.count > 1 {
                    Text("Pass the phone to the next player")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(accent.opacity(0.3), lineWidth: 2) }
            .padding(.horizontal, 32)
        }
    }

    private var passPhoneView: some View {
        GamePassPhoneView(
            playerName: players[safe: currentPlayerIndex]?.username ?? "Next Player",
            subtitle: "Pass the phone. Don't peek at the board!",
            accentColor: .orange,
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
                    let sorted = players.sorted { l, r in
                        let lr = playerResults[l.id]
                        let rr = playerResults[r.id]
                        let lm = lr?.miss ?? Int.max
                        let rm = rr?.miss ?? Int.max
                        if lm != rm { return lm < rm }
                        return (lr?.elapsed ?? 999) < (rr?.elapsed ?? 999)
                    }
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, p in
                        let r = playerResults[p.id]
                        resultRow(rank: index + 1, name: p.username, correct: r?.correct ?? 0, total: r?.total ?? 0, miss: r?.miss ?? 0, time: r?.elapsed ?? 0, didFinish: r?.didFinish ?? false)
                    }
                }
                .padding(.horizontal, 16)

                Button("Play Again") {
                    restart()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }

    private func resultRow(rank: Int, name: String, correct: Int, total: Int, miss: Int, time: Double, didFinish: Bool) -> some View {
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
                Text(name)
                    .font(.subheadline.weight(.semibold))
                Text("\(correct)/\(total) correct · \(miss) miss · \(String(format: "%.1fs", time))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if rank == 1 && didFinish {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
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

    private func performGiveUp() {
        gaveUp = true
        viewModel.giveUp()
    }

    private func handlePlayerComplete() {
        let didWin = viewModel.didWin
        outcomeIsWin = didWin
        if gaveUp {
            FeedbackService.shared.playError()
        } else {
            SoundManager.shared.playVictory()
            FeedbackService.shared.playSuccess()
        }
        if let player = currentPlayer {
            playerResults[player.id] = LocalResult(
                elapsed: viewModel.elapsedSeconds,
                correct: viewModel.correctCount,
                total: viewModel.totalTargets,
                miss: viewModel.missTaps,
                didFinish: didWin
            )
        }
        withAnimation(.spring(duration: 0.4)) {
            showOutcomeOverlay = true
            gamePhase = .outcome
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            await MainActor.run {
                withAnimation(.spring(duration: 0.4)) { showOutcomeOverlay = false }
                gaveUp = false
                advancePlayer()
            }
        }
    }

    private func advancePlayer() {
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
        playerResults = [:]
        gamePhase = .ready
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
