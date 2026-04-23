import SwiftUI

struct ImposterSingleDeviceSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    var showProfile: (() -> Void)? = nil
    @State private var gameStyle: ImposterGameStyle
    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var roundCount: Int = 3
    @State private var discussionDuration: Int = 60
    @State private var selectedCategory: ImposterCategoryPack = .random
    @State private var showDuplicateError: Bool = false

    init(appModel: AppViewModel, game: GameType, gameStyle: ImposterGameStyle = .discussion, showProfile: (() -> Void)? = nil) {
        self.appModel = appModel
        self.game = game
        self.showProfile = showProfile
        _gameStyle = State(initialValue: gameStyle)
        let initialCount = max(game.minPlayers, 4)
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
                    SetupRoundsSection(roundCount: $roundCount)
                    if gameStyle == .discussion {
                        SetupTimerSection(
                            title: "Discussion Time",
                            icon: "bubble.left.and.bubble.right.fill",
                            seconds: $discussionDuration,
                            range: 10...300,
                            step: 10
                        )
                    }
                    modeCard
                    categoryCard
                    SetupStartButton(subtitle: "\(roundCount) rounds · \(playerCount) players") {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            let settings = ImposterSettings(
                                gameStyle: gameStyle,
                                rounds: roundCount,
                                discussionDuration: gameStyle == .discussion ? discussionDuration : 0,
                                categoryPack: selectedCategory
                            )
                            appModel.currentImposterSettings = settings
                            appModel.startSingleDeviceMode(game: game, playerNames: playerNames, roundCount: roundCount)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Imposter — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names for each player.")
        }
    }

    private var modeCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Game Mode", systemImage: "gamecontroller.fill")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 10) {
                    ForEach(ImposterGameStyle.allCases) { style in
                        Button {
                            FeedbackService.shared.playClick()
                            withAnimation(.spring(duration: 0.22)) { gameStyle = style }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: style.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(gameStyle == style ? style.accentColor : .secondary)
                                Text(style.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(gameStyle == style ? .primary : .secondary)
                                Text(style.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(gameStyle == style ? style.accentColor.opacity(0.18) : .white.opacity(0.04), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(gameStyle == style ? style.accentColor.opacity(0.5) : .white.opacity(0.06))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categoryCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Category", systemImage: "tag.fill")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ImposterCategoryPack.allCases) { pack in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.22)) {
                                    selectedCategory = pack
                                }
                            } label: {
                                Text(pack.title)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(selectedCategory == pack ? gameStyle.accentColor.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                    .foregroundStyle(selectedCategory == pack ? gameStyle.accentColor : .secondary)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedCategory == pack ? gameStyle.accentColor.opacity(0.4) : .white.opacity(0.06))
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
}
