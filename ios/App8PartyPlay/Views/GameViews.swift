import SwiftUI

struct GameDetailView: View {
    let appModel: AppViewModel
    let game: GameType
    @Binding var path: [HomeRoute]
    let showProfile: () -> Void
    @State private var selectedMode: GameMode?
    @State private var showPaywall: Bool = false
    let store: StoreViewModel

    private var unlockStatus: GameUnlockStatus {
        appModel.unlockStatus(for: game)
    }

    private var isLocked: Bool {
        !appModel.canPlayGame(game)
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    if isLocked {
                        lockedPremiumCard
                    } else {
                        modeSelectionSection
                    }
                    instructionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(GameLocalizer.gameName(game, language: appModel.currentLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
        .navigationDestination(item: $selectedMode) { mode in
            switch mode {
            case .singleDevice:
                if game.rawValue == GameType.memoryGrid.rawValue {
                    MemoryGridSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else if game.rawValue == GameType.memoryPath.rawValue {
                    MemoryPathSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else if game.rawValue == GameType.passGuess.rawValue {
                    PassGuessSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else if game.rawValue == GameType.imposter.rawValue {
                    ImposterSingleDeviceSetupView(appModel: appModel, game: game, gameStyle: .discussion, showProfile: showProfile)
                } else if game.rawValue == GameType.tapInOrder.rawValue {
                    TapInOrderSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else if game.rawValue == GameType.colorTrap.rawValue {
                    ColorTrapSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else if game.rawValue == GameType.drawRush.rawValue {
                    DrawRushSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else if game.rawValue == GameType.spinBottle.rawValue {
                    SpinBottleSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                } else {
                    SingleDeviceSetupView(appModel: appModel, game: game, mode: mode, showProfile: showProfile)
                }
            case .multiDevice:
                MultiDeviceEntryView(appModel: appModel, game: game) { room in
                    path.append(.lobby(room))
                }
            case .teamMode:
                TeamModeEntryView(appModel: appModel, game: game)
            }
        }
    }

    private var hero: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(height: 200)
                    .overlay {
                        LinearGradient(
                            colors: [game.supportedModes.first?.accentColor.opacity(0.92) ?? .blue.opacity(0.92), .indigo.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: game.symbolName)
                                .font(.system(size: 72, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 18))
                    .padding(.bottom, 2)
            }
        }
    }

    private var lockedPremiumCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.orange)
                        .frame(width: 48, height: 48)
                        .background(.orange.opacity(0.16), in: .rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Premium Game")
                            .font(.headline.weight(.bold))
                        Text("Subscribe to 8PartyPlay+ to unlock \(game.name) and every other premium game.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    lockedBullet(icon: "checkmark.circle.fill", text: "Unlock all premium games")
                    lockedBullet(icon: "sparkles", text: "AI cards cost just 1 \u{2605} instead of 5")
                    lockedBullet(icon: "star.fill", text: "Bonus Stars every billing period")
                }

                Button {
                    FeedbackService.shared.playClick()
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline.weight(.bold))
                        Text("Unlock with 8PartyPlay+")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                        in: .rect(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lockedBullet(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
                .frame(width: 18)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(GameLocalizer.chooseMode(language: appModel.currentLanguage))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(game.supportedModes) { mode in
                    Button {
                        FeedbackService.shared.playClick()
                        if game.rawValue == GameType.reverseSinging.rawValue && mode == .singleDevice {
                            appModel.startSingleDeviceMode(game: game, playerNames: ["Player 1", "Player 2"], roundCount: 1)
                        } else {
                            selectedMode = mode
                        }
                    } label: {
                        ModeSelectionCard(mode: mode, language: appModel.currentLanguage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var instructionsSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: GameLocalizer.howItWorks(language: appModel.currentLanguage), subtitle: "")
                ForEach(Array(GameLocalizer.gameInstructions(game, language: appModel.currentLanguage).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.1), in: .circle)
                        Text(step)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MultiPhoneIcon: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Image(systemName: "iphone.gen3")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .offset(x: -(size * 0.28))
            Image(systemName: "iphone.gen3")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .offset(x: size * 0.28)
        }
    }
}

struct ModeSelectionCard: View {
    let mode: GameMode
    let language: AppLanguage

    private var titleText: String {
        GameLocalizer.modeName(mode, language: language)
    }

    private var subtitleText: String {
        GameLocalizer.modeSubtitle(mode, language: language)
    }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if mode == .multiDevice {
                    MultiPhoneIcon()
                } else {
                    Image(systemName: mode.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 52, height: 52)
            .background(mode.accentColor, in: .rect(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline.weight(.bold))

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mode.accentColor)
        }
        .padding(14)
        .background(mode.accentColor.opacity(0.12), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(mode.accentColor.opacity(0.4), lineWidth: 1.2)
        }
    }
}

struct SingleDeviceSetupView: View {
    let appModel: AppViewModel
    let game: GameType
    let mode: GameMode
    var showProfile: (() -> Void)? = nil
    @State private var playerCount: Int
    @State private var playerNames: [String]
    @State private var roundCount: Int = 3
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
                    SetupRoundsSection(roundCount: $roundCount, range: game.rawValue == GameType.guessTheSeconds.rawValue ? 1...3 : 1...10)
                    SetupStartButton {
                        if hasDuplicateNames {
                            showDuplicateError = true
                        } else {
                            appModel.startSingleDeviceMode(game: game, playerNames: playerNames, roundCount: roundCount)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("\(game.name) — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Duplicate Names", isPresented: $showDuplicateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Two or more players have the same name. Please use unique names for each player.")
        }
    }
}

struct MultiDeviceEntryView: View {
    let appModel: AppViewModel
    let game: GameType
    let onRoomOpened: (GameRoom) -> Void

    var body: some View {
        CasualCreateRoomView(appModel: appModel, game: game)
    }
}



struct WaitingRoomView: View {
    let appModel: AppViewModel
    let initialRoom: GameRoom

    private var room: GameRoom {
        appModel.currentRoom ?? initialRoom
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    playersSection
                    inviteSection
                    actionSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Waiting Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var headerCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(height: 140)
                    .overlay {
                        LinearGradient(
                            colors: [room.mode.accentColor.opacity(0.86), .indigo.opacity(0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .allowsHitTesting(false)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.game.name)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(room.mode.title)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                Spacer()
                                StatusPillView(title: room.access.title, systemImage: room.access.systemImage, tint: .white)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                StatusPillView(title: "Code \(room.code)", systemImage: "number", tint: .white)
                                StatusPillView(
                                    title: room.allPlayersReady ? "Ready" : "Waiting",
                                    systemImage: room.allPlayersReady ? "checkmark.circle.fill" : "clock.fill",
                                    tint: .white
                                )
                            }
                        }
                        .padding(16)
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 16))

                HStack(spacing: 6) {
                    MetricChipView(title: "\(room.readyCount)/\(room.players.count) ready", systemImage: "person.crop.circle.badge.checkmark")
                    MetricChipView(title: "\(room.onlineCount) online", systemImage: "dot.radiowaves.up.forward")
                    MetricChipView(title: room.hostName, systemImage: "crown.fill")
                }
            }
        }
    }


    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "Players", subtitle: "\(room.minPlayers)–\(room.maxPlayers) players needed")
            ForEach(room.players) { player in
                Button {
                    if player.username == appModel.username {
                        appModel.toggleReady(for: player.id)
                    }
                } label: {
                    PlayerBadgeView(player: player)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "Invites & Access", subtitle: "Control who can join.")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Visibility", selection: Binding(
                        get: { appModel.currentRoomAccess },
                        set: { appModel.updateRoomAccess($0) }
                    )) {
                        ForEach(RoomAccess.allCases) { access in
                            Text(access.title).tag(access)
                        }
                    }
                    .pickerStyle(.segmented)

                    InlineActionRow(
                        title: "Share room code",
                        subtitle: "Room \(room.code) — share it for fast joins.",
                        systemImage: "number",
                        tint: .blue
                    )

                    ShareLink(item: "\(room.code)\n\nJoin me on 8PartyPlay to play together!\n(Game: \(room.game.name))") {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                            Text("Invite Friends")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Start Game")
                    .font(.subheadline.weight(.semibold))
                Text("All players must be ready. Host starts the match.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Start Match") {
                    appModel.startMultiplayerFromLobby()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!appModel.canStartCurrentLobbyMatch)
            }
        }
    }
}

struct GameSessionView: View {
    let appModel: AppViewModel
    let sessionID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingLeaveConfirmation: Bool = false

    private var session: GameSession? {
        appModel.activeSession?.id == sessionID ? appModel.activeSession : nil
    }

    private func requestSessionExit() {
        Task {
            await appModel.exitActiveSession()
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    sessionContent(session)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingLeaveConfirmation = true
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                }
            }
            .confirmationDialog("Leave Game?", isPresented: $isShowingLeaveConfirmation, titleVisibility: .visible) {
                Button("Leave Game", role: .destructive) {
                    requestSessionExit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current progress will be lost.")
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func sessionContent(_ session: GameSession) -> some View {
        if session.game.rawValue == GameType.reverseSinging.rawValue {
            ReverseSingingSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.guessTheSeconds.rawValue {
            GuessTheSecondsSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.tenTangle.rawValue {
            TenTangleSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.imposter.rawValue {
            ImposterSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.memoryGrid.rawValue {
            MemoryGridSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.memoryPath.rawValue {
            MemoryPathSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.passGuess.rawValue {
            PassGuessSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.tapInOrder.rawValue {
            TapInOrderSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.colorTrap.rawValue {
            ColorTrapSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.drawRush.rawValue {
            DrawRushMultiDeviceSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        } else if session.game.rawValue == GameType.spinBottle.rawValue {
            SpinBottleSessionView(appModel: appModel, session: session) {
                requestSessionExit()
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
