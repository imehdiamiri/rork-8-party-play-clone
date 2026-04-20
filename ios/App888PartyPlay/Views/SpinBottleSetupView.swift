import SwiftUI

struct SpinBottleSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil

    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var difficulty: SpinBottleDifficulty = .classic
    @State private var showDuplicateError: Bool = false

    init(appModel: AppViewModel, game: GameType, mode: GameMode, showProfile: (() -> Void)? = nil) {
        self.appModel = appModel
        self.game = game
        self.mode = mode
        self.showProfile = showProfile
        let initialCount = max(game.minPlayers, min(4, game.maxPlayers))
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
                    difficultyCard
                    SetupStartButton(subtitle: "\(difficulty.title) · \(playerCount) players") {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            appModel.currentSpinBottleDifficulty = difficulty
                            appModel.startSingleDeviceMode(game: game, playerNames: playerNames, roundCount: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Truth & Dare — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names for each player.")
        }
    }

    private var difficultyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Vibe", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)

                HStack(spacing: 8) {
                    ForEach(SpinBottleDifficulty.allCases) { level in
                        Button {
                            FeedbackService.shared.playClick()
                            withAnimation(.spring(duration: 0.25)) { difficulty = level }
                        } label: {
                            VStack(spacing: 4) {
                                Text(level.title)
                                    .font(.subheadline.weight(.bold))
                                Text(level.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(difficulty == level ? .white.opacity(0.75) : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(difficulty == level ? .red.opacity(0.22) : .white.opacity(0.04), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(difficulty == level ? .red.opacity(0.55) : .white.opacity(0.06))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
