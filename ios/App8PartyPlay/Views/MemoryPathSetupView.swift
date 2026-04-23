import SwiftUI

struct MemoryPathSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil
    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var selectedGameMode: MemoryPathGameMode = .timeRace
    @State private var selectedDifficulty: MemoryPathDifficulty = .medium
    @State private var targetSteps: Int = 6
    @State private var showDuplicateError: Bool = false

    init(appModel: AppViewModel, game: GameType, mode: GameMode, showProfile: (() -> Void)? = nil) {
        self.appModel = appModel
        self.game = game
        self.mode = mode
        self.showProfile = showProfile
        let initialCount = max(game.minPlayers, min(2, game.maxPlayers))
        _playerCount = State(initialValue: initialCount)
        _playerNames = State(initialValue: Array(repeating: "", count: initialCount))
    }

    private var hasDuplicateNames: Bool {
        let trimmed = playerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(trimmed).count != trimmed.count
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HowToPlayButton(game: game, language: appModel.currentLanguage)
                    SetupPlayersSection(
                        playerCount: $playerCount,
                        playerNames: $playerNames,
                        minPlayers: game.minPlayers,
                        maxPlayers: game.maxPlayers,
                        offlineFriends: appModel.offlineFriends
                    )
                    gameModeCard
                    difficultyCard
                    pathLengthCard
                    SetupStartButton(subtitle: "\(selectedDifficulty.gridSize)×\(selectedDifficulty.gridSize) · \(targetSteps) steps · \(selectedGameMode.title)") {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            startMemoryPathGame()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Memory Path — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names.")
        }
        .onChange(of: selectedDifficulty) { _, newDiff in
            let newDefault = MemoryPathSettings.defaultSteps(for: newDiff)
            let range = MemoryPathSettings.stepsRange(for: newDiff)
            targetSteps = min(max(newDefault, range.lowerBound), range.upperBound)
        }
    }

    private var gameModeCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Game Mode", systemImage: "gamecontroller.fill")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 10) {
                    ForEach(MemoryPathGameMode.allCases) { gm in
                        Button {
                            FeedbackService.shared.playClick()
                            withAnimation(.spring(duration: 0.25)) { selectedGameMode = gm }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: gm.icon)
                                    .font(.title3.weight(.semibold))
                                Text(gm.title)
                                    .font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(selectedGameMode == gm ? .teal.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(selectedGameMode == gm ? .teal.opacity(0.5) : .white.opacity(0.06))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var pathLengthCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Path Length", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    ForEach(["Easy", "Medium", "Hard"], id: \.self) { label in
                        let isSelected = stepDifficultyLabel == label
                        Button {
                            FeedbackService.shared.playClick()
                            withAnimation(.spring(duration: 0.25)) {
                                switch label {
                                case "Easy":
                                    let range = stepsRange
                                    let third = (range.upperBound - range.lowerBound) / 3
                                    targetSteps = range.lowerBound + third / 2
                                case "Medium":
                                    let range = stepsRange
                                    let third = (range.upperBound - range.lowerBound) / 3
                                    targetSteps = range.lowerBound + third + third / 2
                                case "Hard":
                                    let range = stepsRange
                                    let third = (range.upperBound - range.lowerBound) / 3
                                    targetSteps = range.lowerBound + third * 2 + third / 2
                                default: break
                                }
                                targetSteps = min(max(targetSteps, stepsRange.lowerBound), stepsRange.upperBound)
                            }
                        } label: {
                            Text(label)
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? stepDifficultyColor.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(isSelected ? stepDifficultyColor.opacity(0.5) : .white.opacity(0.06))
                                }
                                .foregroundStyle(isSelected ? stepDifficultyColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 14) {
                    Button {
                        FeedbackService.shared.playClick()
                        if targetSteps > stepsRange.lowerBound {
                            withAnimation(.spring(duration: 0.2)) { targetSteps -= 1 }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption.weight(.bold))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .disabled(targetSteps <= stepsRange.lowerBound)
                    .opacity(targetSteps <= stepsRange.lowerBound ? 0.3 : 1)

                    VStack(spacing: 1) {
                        Text("\(targetSteps)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.teal)
                            .contentTransition(.numericText())
                        Text("steps")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        FeedbackService.shared.playClick()
                        if targetSteps < stepsRange.upperBound {
                            withAnimation(.spring(duration: 0.2)) { targetSteps += 1 }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .disabled(targetSteps >= stepsRange.upperBound)
                    .opacity(targetSteps >= stepsRange.upperBound ? 0.3 : 1)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var stepsRange: ClosedRange<Int> {
        MemoryPathSettings.stepsRange(for: selectedDifficulty)
    }

    private var stepDifficultyLabel: String {
        let range = stepsRange
        let third = (range.upperBound - range.lowerBound) / 3
        if targetSteps <= range.lowerBound + third { return "Easy" }
        if targetSteps <= range.lowerBound + third * 2 { return "Medium" }
        return "Hard"
    }

    private var stepDifficultyColor: Color {
        let range = stepsRange
        let third = (range.upperBound - range.lowerBound) / 3
        if targetSteps <= range.lowerBound + third { return .green }
        if targetSteps <= range.lowerBound + third * 2 { return .orange }
        return .red
    }

    private var difficultyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Grid Size", systemImage: "square.grid.3x3")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MemoryPathDifficulty.allCases) { diff in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.25)) { selectedDifficulty = diff }
                            } label: {
                                Text("\(diff.gridSize)×\(diff.gridSize)")
                                    .font(.subheadline.weight(.bold))
                                    .frame(minWidth: 54)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selectedDifficulty == diff ? diff.accentColor.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedDifficulty == diff ? diff.accentColor.opacity(0.5) : .white.opacity(0.06))
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

    private func startMemoryPathGame() {
        FeedbackService.shared.playRoundStart()
        let resolvedPlayers: [PlayerProfile] = playerNames.enumerated().map { index, rawName in
            let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = cleanName.isEmpty ? "Player \(index + 1)" : cleanName
            return PlayerProfile(username: name, isHost: index == 0, isReady: true)
        }
        appModel.currentMemoryPathSettings = MemoryPathSettings(
            gameMode: selectedGameMode,
            playType: .singleDevice,
            difficulty: selectedDifficulty,
            targetSteps: targetSteps
        )
        appModel.startSingleDeviceMode(game: game, playerNames: resolvedPlayers.map(\.username), roundCount: 1)
    }
}
