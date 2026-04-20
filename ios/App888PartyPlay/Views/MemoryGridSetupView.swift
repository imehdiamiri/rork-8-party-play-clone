import SwiftUI

struct MemoryGridSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil
    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var selectedGridSize: MemoryGridSize = .tiny3x4
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
                    gridSizeCard
                    SetupStartButton(subtitle: "\(selectedGridSize.title) · \(selectedGridSize.pairCount) pairs · \(playerCount) players") {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            startMemoryGridGame()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Memory Grid — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names for each player.")
        }
    }

    private var gridSizeCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Board Size", systemImage: "square.grid.3x3.fill")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MemoryGridSize.allCases) { size in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.25)) {
                                    selectedGridSize = size
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(size.title)
                                        .font(.subheadline.weight(.bold))
                                    Text(size.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(selectedGridSize == size ? .white.opacity(0.7) : .secondary)
                                }
                                .frame(minWidth: 56)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedGridSize == size ? .cyan.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedGridSize == size ? .cyan.opacity(0.5) : .white.opacity(0.06))
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

    private func startMemoryGridGame() {
        let resolvedPlayers: [PlayerProfile] = playerNames.enumerated().map { index, rawName in
            let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = cleanName.isEmpty ? "Player \(index + 1)" : cleanName
            return PlayerProfile(username: name, isHost: index == 0, isReady: true)
        }
        appModel.currentMemoryGridSettings = MemoryGridSettings(gridSize: selectedGridSize)
        appModel.startSingleDeviceMode(game: game, playerNames: resolvedPlayers.map(\.username), roundCount: 1)
    }
}
