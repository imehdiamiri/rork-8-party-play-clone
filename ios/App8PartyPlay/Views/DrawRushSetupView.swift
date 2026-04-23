import SwiftUI

struct DrawRushSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil

    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var showDuplicateError: Bool = false
    @State private var navigate: Bool = false
    @State private var conceptMode: DRConceptMode = .freeDraw

    init(appModel: AppViewModel, game: GameType, mode: GameMode, showProfile: (() -> Void)? = nil) {
        self.appModel = appModel
        self.game = game
        self.mode = mode
        self.showProfile = showProfile
        let initial = max(game.minPlayers, min(3, game.maxPlayers))
        _playerCount = State(initialValue: initial)
        _playerNames = State(initialValue: Array(repeating: "", count: initial))
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
                    conceptModeCard
                    SetupPlayersSection(
                        playerCount: $playerCount,
                        playerNames: $playerNames,
                        minPlayers: game.minPlayers,
                        maxPlayers: game.maxPlayers,
                        offlineFriends: appModel.offlineFriends
                    )
                    SetupStartButton(subtitle: "Each player draws once · 60s per turn") {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            navigate = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Draw & Rush — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigate) {
            DrawRushSessionView(playerNames: resolvedPlayerNames(), conceptMode: conceptMode)
        }
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names.")
        }
    }

    private func resolvedPlayerNames() -> [String] {
        playerNames.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        }
    }

    private var conceptModeCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "Concept Source", subtitle: "How does the drawer pick what to draw?")
                VStack(spacing: 8) {
                    ForEach(DRConceptMode.allCases) { mode in
                        Button {
                            conceptMode = mode
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(conceptMode == mode ? .cyan : .secondary)
                                    .frame(width: 36, height: 36)
                                    .background((conceptMode == mode ? Color.cyan : Color.white).opacity(0.12), in: .rect(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text(mode.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: conceptMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(conceptMode == mode ? .cyan : .secondary)
                            }
                            .padding(12)
                            .background(.white.opacity(conceptMode == mode ? 0.10 : 0.04), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(conceptMode == mode ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

}
