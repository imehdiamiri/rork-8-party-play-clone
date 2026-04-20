import SwiftUI

struct ColorTrapSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil

    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var selectedDifficulty: ColorTrapDifficulty = .medium
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
                    difficultyCard
                    SetupStartButton(subtitle: "\(selectedDifficulty.title) · \(Int(selectedDifficulty.totalDuration))s · \(playerCount) players") {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            startGame()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Color Trap — Setup")
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
                Label("Difficulty", systemImage: "paintpalette.fill")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ColorTrapDifficulty.allCases) { level in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.25)) {
                                    selectedDifficulty = level
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(level.title)
                                        .font(.subheadline.weight(.bold))
                                    Text(level.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(selectedDifficulty == level ? .white.opacity(0.7) : .secondary)
                                }
                                .frame(minWidth: 90)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedDifficulty == level ? .pink.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedDifficulty == level ? .pink.opacity(0.5) : .white.opacity(0.06))
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

    private func startGame() {
        appModel.currentColorTrapSettings = ColorTrapSettings(difficulty: selectedDifficulty)
        appModel.startSingleDeviceMode(game: game, playerNames: playerNames, roundCount: 1)
    }
}
