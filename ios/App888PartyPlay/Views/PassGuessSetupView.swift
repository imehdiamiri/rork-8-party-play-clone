import SwiftUI

struct PassGuessSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil

    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var roundCount: Int = 1
    @State private var showDuplicateError: Bool = false
    @State private var answerTimeLimit: Int
    @State private var guessTimeLimit: Int

    init(appModel: AppViewModel, game: GameType, mode: GameMode, showProfile: (() -> Void)? = nil) {
        self.appModel = appModel
        self.game = game
        self.mode = mode
        self.showProfile = showProfile
        let initialCount = max(game.minPlayers, min(4, game.maxPlayers))
        _playerCount = State(initialValue: initialCount)
        _playerNames = State(initialValue: Array(repeating: "", count: initialCount))
        _answerTimeLimit = State(initialValue: appModel.currentPassGuessSettings.answerTimeLimit)
        _guessTimeLimit = State(initialValue: appModel.currentPassGuessSettings.guessTimeLimit)
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
                    SetupRoundsSection(roundCount: $roundCount)
                    timersSection
                    SetupStartButton(
                        subtitle: "\(roundCount) rounds · \(playerCount) players"
                    ) {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            let settings = PassGuessSettings(
                                rounds: roundCount,
                                questionMode: .predefined,
                                selectedQuestionID: nil,
                                customQuestion: "",
                                answerTimeLimit: answerTimeLimit,
                                guessTimeLimit: guessTimeLimit
                            )
                            appModel.updatePassGuessSettings(settings)
                            appModel.startSingleDeviceMode(game: game, playerNames: playerNames, roundCount: roundCount)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Pass & Guess — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names for each player.")
        }
    }

    private var timersSection: some View {
        VStack(spacing: 14) {
            SetupTimerSection(
                title: "Answer Time",
                icon: "pencil.circle.fill",
                seconds: $answerTimeLimit,
                range: 15...120,
                step: 10
            )
            SetupTimerSection(
                title: "Guess Time",
                icon: "eye.circle.fill",
                seconds: $guessTimeLimit,
                range: 15...90,
                step: 10
            )
        }
    }

}
