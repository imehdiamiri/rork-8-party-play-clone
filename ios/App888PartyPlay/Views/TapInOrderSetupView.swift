import SwiftUI

struct TapInOrderSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil

    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var selectedVariant: TapInOrderVariant = .numberMemory
    @State private var selectedGridSize: Int = 4
    @State private var selectedTileCount: Int = 6
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

    private var tileOptions: [Int] {
        TapInOrderBoard.tileOptions(for: selectedGridSize, variant: selectedVariant)
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
                    variantCard
                    gridSizeCard
                    tileCountCard
                    SetupStartButton(subtitle: "\(selectedVariant.title) · \(selectedGridSize)×\(selectedGridSize) · \(selectedTileCount) tiles") {
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
        .navigationTitle("Tap in Order — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: selectedVariant) { _, _ in clampTileCount() }
        .onChange(of: selectedGridSize) { _, _ in clampTileCount() }
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names for each player.")
        }
    }

    private func clampTileCount() {
        let opts = tileOptions
        if !opts.contains(selectedTileCount) {
            selectedTileCount = TapInOrderBoard.defaultTileCount(for: selectedGridSize, variant: selectedVariant)
        }
    }

    private var variantCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Mode", systemImage: "brain.head.profile")
                    .font(.subheadline.weight(.semibold))

                VStack(spacing: 8) {
                    ForEach(TapInOrderVariant.allCases) { variant in
                        Button {
                            FeedbackService.shared.playClick()
                            withAnimation(.spring(duration: 0.25)) {
                                selectedVariant = variant
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: variant.icon)
                                    .font(.title3)
                                    .foregroundStyle(selectedVariant == variant ? .orange : .secondary)
                                    .frame(width: 36, height: 36)
                                    .background(.orange.opacity(selectedVariant == variant ? 0.18 : 0.06), in: .rect(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(variant.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text(variant.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Label("Fewest mistakes wins", systemImage: "checkmark.seal.fill")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.green.opacity(0.85))
                                        .padding(.top, 2)
                                }
                                Spacer(minLength: 0)
                                if selectedVariant == variant {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(12)
                            .background(selectedVariant == variant ? .orange.opacity(0.12) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selectedVariant == variant ? .orange.opacity(0.45) : .white.opacity(0.06))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var gridSizeCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Grid Size", systemImage: "square.grid.3x3.fill")
                    .font(.subheadline.weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TapInOrderBoard.gridSizeOptions, id: \.self) { size in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.25)) { selectedGridSize = size }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(size)×\(size)")
                                        .font(.subheadline.weight(.bold))
                                    Text("\(size * size) cells")
                                        .font(.caption2)
                                        .foregroundStyle(selectedGridSize == size ? .white.opacity(0.7) : .secondary)
                                }
                                .frame(minWidth: 80)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedGridSize == size ? .orange.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedGridSize == size ? .orange.opacity(0.5) : .white.opacity(0.06))
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

    private var tileCountCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(selectedVariant == .numberMemory ? "Numbers" : "Pattern Tiles", systemImage: "number.square.fill")
                    .font(.subheadline.weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tileOptions, id: \.self) { count in
                            Button {
                                FeedbackService.shared.playClick()
                                withAnimation(.spring(duration: 0.25)) { selectedTileCount = count }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(count)")
                                        .font(.title3.weight(.heavy))
                                    Text(selectedVariant == .numberMemory ? "numbers" : "tiles")
                                        .font(.caption2)
                                        .foregroundStyle(selectedTileCount == count ? .white.opacity(0.7) : .secondary)
                                }
                                .frame(minWidth: 70)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedTileCount == count ? .orange.opacity(0.2) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedTileCount == count ? .orange.opacity(0.5) : .white.opacity(0.06))
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
        appModel.currentTapInOrderSettings = TapInOrderSettings(variant: selectedVariant, gridSize: selectedGridSize, tileCount: selectedTileCount)
        appModel.startSingleDeviceMode(game: game, playerNames: playerNames, roundCount: 1)
    }
}
