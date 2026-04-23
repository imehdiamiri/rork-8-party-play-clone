import SwiftUI

struct CasualCreateRoomView: View {
    let appModel: AppViewModel
    let game: GameType
    @State private var casualVM = CasualRoomViewModel()
    @State private var navigateToLobby: Bool = false

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(spacing: 20) {
                    iconHeader
                    nameInputCard
                    settingsCard
                    createButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .dismissKeyboardOnTap()
        .navigationTitle("\(game.name) — Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToLobby) {
            CasualLobbyView(appModel: appModel, casualVM: casualVM)
        }
        .onChange(of: casualVM.isConnected) { _, connected in
            if connected && casualVM.room != nil {
                navigateToLobby = true
            }
        }
    }

    private var iconHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 64, height: 64)
                .background(.green.opacity(0.14), in: .rect(cornerRadius: 20))

            Text("Create a Party Room")
                .font(.title3.weight(.bold))

            Text("No login needed. Share the code with friends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var nameInputCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Your Name", subtitle: "This is how others will see you.")

                TextField("Display name", text: $casualVM.displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && casualVM.errorMessage != nil ? .red.opacity(0.5) : .white.opacity(0.05))
                    }

                if casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Display name is required", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var settingsCard: some View {
        EmptyView()
    }

    private var createButton: some View {
        VStack(spacing: 8) {
            Button("Create Room") {
                casualVM.createRoom(gameType: game) {}
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(casualVM.isBusy)

            if let error = casualVM.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if casualVM.isBusy {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

struct CasualJoinRoomView: View {
    let appModel: AppViewModel
    let onJoinedAndStarted: ((CasualRoomViewModel) -> Void)?
    @State private var casualVM = CasualRoomViewModel()
    @State private var navigateToLobby: Bool = false
    @FocusState private var focusedField: JoinField?
    @Environment(\.dismiss) private var dismiss

    nonisolated enum JoinField: Hashable, Sendable {
        case code
        case name
    }

    init(appModel: AppViewModel, onJoinedAndStarted: ((CasualRoomViewModel) -> Void)? = nil) {
        self.appModel = appModel
        self.onJoinedAndStarted = onJoinedAndStarted
    }

    private var isJoinDisabled: Bool {
        casualVM.isBusy
            || casualVM.roomCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 4
            || casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Room Code")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextField("123456", text: $casualVM.roomCode)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .focused($focusedField, equals: .code)
                                    .font(.system(size: 40, weight: .black, design: .monospaced))
                                    .kerning(8)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 22)
                                    .frame(maxWidth: .infinity)
                                    .background(.blue.opacity(0.12), in: .rect(cornerRadius: 18))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18)
                                            .strokeBorder(.blue.opacity(0.35), lineWidth: 1.5)
                                    }
                                Text("Enter the 6-digit room code.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            EmptyView()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Name")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextField("Enter your name", text: $casualVM.displayName)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        if !isJoinDisabled {
                                            focusedField = nil
                                            casualVM.joinRoom()
                                        }
                                    }
                                    .font(.body.weight(.medium))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 16)
                                    .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(.white.opacity(0.08))
                                    }
                                Text("Everyone in the room sees this name.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            focusedField = nil
                            casualVM.joinRoom()
                        } label: {
                            Label("Join Room", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(isJoinDisabled)

                        if let error = casualVM.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        if casualVM.isBusy {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .dismissKeyboardOnTap()
        .navigationDestination(isPresented: $navigateToLobby) {
            CasualLobbyView(appModel: appModel, casualVM: casualVM)
        }
        .onChange(of: casualVM.roomCode) { _, newValue in
            let sanitized = String(newValue.filter(\.isNumber).prefix(6))
            if sanitized != newValue {
                casualVM.roomCode = sanitized
            }
            if sanitized.count >= 6 && focusedField == .code {
                focusedField = .name
            }
        }
        .onChange(of: casualVM.isConnected) { _, connected in
            if connected {
                navigateToLobby = true
                onJoinedAndStarted?(casualVM)
            }
        }
        .task {
            focusedField = .code
        }
        .alert("Removed from Room", isPresented: $casualVM.wasKicked) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host removed you from this room. You can join another room any time.")
        }
        .alert("Room Closed", isPresented: $casualVM.roomClosed) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host closed this room. This code has expired.")
        }
    }
}

struct CasualLobbyView: View {
    let appModel: AppViewModel
    @Bindable var casualVM: CasualRoomViewModel

    var body: some View {
        Group {
            if casualVM.isHost {
                HostLobbyView(appModel: appModel, casualVM: casualVM)
            } else {
                GuestLobbyView(appModel: appModel, casualVM: casualVM)
            }
        }
    }
}

struct ResyncBannerView: View {
    let message: String

    private var isGood: Bool { message == "Connection restored" }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isGood ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isGood ? .green : .orange)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            if !isGood {
                ProgressView().controlSize(.small).tint(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background((isGood ? Color.green : Color.orange).opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder((isGood ? Color.green : Color.orange).opacity(0.35))
        }
        .transition(.opacity)
    }
}

struct HostLobbyView: View {
    let appModel: AppViewModel
    @Bindable var casualVM: CasualRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLeaveConfirm: Bool = false

    private var room: CasualRoom? { casualVM.room }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let banner = casualVM.resyncBanner {
                        ResyncBannerView(message: banner)
                    }
                    roomHeaderCard
                    hostActionsSection
                    playersSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Host Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close Room") { showLeaveConfirm = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
        .confirmationDialog("Close Room?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Close Room", role: .destructive) {
                casualVM.leaveRoom()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will close the room for everyone and expire the code.")
        }
        .sheet(isPresented: $casualVM.readyCheckActive) {
            ReadyCheckSheet(casualVM: casualVM)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
        }
        .task(id: casualVM.gameStarted) {
            guard casualVM.gameStarted else { return }
            startGameSession(appModel: appModel, casualVM: casualVM)
        }
        .onChange(of: scenePhase) { _, newPhase in
            casualVM.handleScenePhaseChange(to: newPhase)
        }
        .onChange(of: casualVM.shouldAutoDismissLobby) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }

    private var roomHeaderCard: some View {
        VStack(spacing: 14) {
            Text(room?.gameType.name ?? "Party Game")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .green.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .padding(.top, 4)

            VStack(spacing: 10) {
                Text("ROOM CODE")
                    .font(.caption2.weight(.heavy))
                    .kerning(2)
                    .foregroundStyle(.green.opacity(0.9))

                Text(room?.code ?? "------")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                    )
                    .kerning(8)
                    .monospacedDigit()
                    .shadow(color: .green.opacity(0.4), radius: 12)

                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = room?.code ?? ""
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)

                    if let code = room?.code, let gameName = room?.gameType.name {
                        ShareLink(item: "\(code)\n\nJoin me on 8PartyPlay to play together!\n(Game: \(gameName))") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.blue, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [.green.opacity(0.18), .teal.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 22)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.green.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(
                title: "Players · \(room?.connectedCount ?? 0) connected",
                subtitle: "\(room?.minPlayers ?? 2)–\(room?.maxPlayers ?? 10) players needed"
            )
            ForEach(casualVM.players) { player in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 34, height: 34)
                        Text(String(player.displayName.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(player.isConnected ? .green : .gray)
                            .frame(width: 9, height: 9)
                            .overlay {
                                Circle().stroke(.black.opacity(0.6), lineWidth: 2)
                            }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(player.displayName)
                                .font(.subheadline.weight(.semibold))
                            if player.isHost {
                                StatusPillView(title: "Host", systemImage: "crown.fill", tint: .blue)
                            }
                            if player.id == casualVM.localPlayer?.id {
                                StatusPillView(title: "You", systemImage: "person.fill", tint: .green)
                            }
                        }
                        StatusPillView(
                            title: player.isConnected ? "Connected" : "Disconnected",
                            systemImage: player.isConnected ? "checkmark.circle.fill" : "moon.fill",
                            tint: player.isConnected ? .green : .gray
                        )
                    }

                    Spacer(minLength: 0)

                    if casualVM.isHost && !player.isHost {
                        Button {
                            casualVM.kickPlayer(player)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(.white.opacity(0.035), in: .rect(cornerRadius: 14))
            }

            if casualVM.players.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Waiting for players...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            if casualVM.waitingTooLong, let room, room.players.count < room.minPlayers {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                        Text("Still waiting?")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    Text("Invite more friends with the code above, or wait a bit longer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        if let code = room.code.isEmpty ? nil : room.code as String?, let gameName = room.gameType.name as String? {
                            ShareLink(item: "\(code)\n\nJoin me on 8PartyPlay to play together!\n(Game: \(gameName))") {
                                Text("Invite")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(.blue, in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        Button("Cancel") { showLeaveConfirm = true }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.8), in: .rect(cornerRadius: 10))
                    }
                }
                .padding(12)
                .background(.orange.opacity(0.12), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.4))
                }
            }
        }
    }

    private var hostActionsSection: some View {
        VStack(spacing: 10) {
            Button {
                casualVM.startGame()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.title3.weight(.bold))
                    Text("Start Match")
                        .font(.title3.weight(.heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: casualVM.canStart ? [.green, .teal] : [.gray.opacity(0.4), .gray.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 18)
                )
                .shadow(color: casualVM.canStart ? .green.opacity(0.35) : .clear, radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!casualVM.canStart)

            if let room, room.players.count < room.minPlayers {
                Text("Need at least \(room.minPlayers) players to start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

}

@MainActor
fileprivate func startGameSession(appModel: AppViewModel, casualVM: CasualRoomViewModel) {
    guard let room = casualVM.room else { return }
    let players = casualVM.buildPlayersForSession()
    let localID = casualVM.localPlayer?.id
    let isHost = casualVM.isHost
    let roomID = room.id
    let roomCode = room.code
    let gameType = room.gameType
    let playMode = room.playMode
    let sessionToken = casualVM.localPlayer?.sessionToken
    let service = casualVM.service

    casualVM.onSessionEnded = { [weak appModel] in
        appModel?.dismissSession()
    }
    service.onGameStateSync = { [weak appModel] payload in
        appModel?.applyRemoteCasualGameState(payload)
    }
    appModel.attachCasualRoomService(
        service,
        localPlayerID: localID,
        roomID: roomID,
        sessionToken: sessionToken,
        cleanup: { [weak casualVM] in
            casualVM?.shouldAutoDismissLobby = true
            casualVM?.disconnect()
        }
    )

    guard appModel.activeSession?.roomCode != roomCode else { return }

    if isHost {
        // ReadyCheckSheet is dismissing right now — fullScreenCover cannot layer
        // over a dismissing sheet. Delay session open slightly so the sheet is
        // fully dismissed first, otherwise the game never opens for the host.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard appModel.activeSession?.roomCode != roomCode else { return }
            appModel.startCasualMultiplayerSession(
                game: gameType,
                mode: playMode,
                players: players,
                roomCode: roomCode,
                localPlayerID: localID,
                sessionID: roomID,
                syncToPeers: true
            )
            appModel.rebroadcastCurrentCasualSessionState()
        }
    } else {
        // Guest is inside a QuickJoinSheet fullScreenCover. SwiftUI cannot layer
        // MainTabView's .fullScreenCover(item: activeSession) over it, so we
        // must dismiss the join sheet FIRST, then set activeSession.
        appModel.requestCasualSheetDismiss = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard appModel.activeSession?.roomCode != roomCode else {
                appModel.requestCasualSheetDismiss = false
                return
            }
            appModel.startCasualMultiplayerSession(
                game: gameType,
                mode: playMode,
                players: players,
                roomCode: roomCode,
                localPlayerID: localID,
                sessionID: roomID,
                syncToPeers: false
            )
            appModel.requestCasualSheetDismiss = false
            // Guest just entered the session — request an immediate snapshot so
            // we don't wait up to 1.5s for the host's rebroadcast pump.
            Task { await service.requestGameStateSnapshot() }
        }
    }
}

struct GuestLobbyView: View {
    let appModel: AppViewModel
    @Bindable var casualVM: CasualRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLeaveConfirm: Bool = false

    private var room: CasualRoom? { casualVM.room }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let banner = casualVM.resyncBanner {
                        ResyncBannerView(message: banner)
                    }
                    guestHeroCard
                    guestStatusCard
                    guestPlayersCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Waiting Room")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Leave") { showLeaveConfirm = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
        .confirmationDialog("Leave Room?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                casualVM.leaveRoom()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will leave this room. The host will be notified.")
        }
        .alert("Removed from Room", isPresented: $casualVM.wasKicked) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host removed you from this room. You can rejoin any room with a valid code.")
        }
        .alert("Room Closed", isPresented: $casualVM.roomClosed) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host closed this room. This code has expired and can no longer be used.")
        }
        .alert("Host Left", isPresented: $casualVM.hostLeft) {
            Button("Back") { dismiss() }
        } message: {
            Text("The host left the game. This room code has expired and cannot be used again.")
        }
        .sheet(isPresented: $casualVM.readyCheckActive) {
            ReadyCheckSheet(casualVM: casualVM)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
        }
        .task(id: casualVM.gameStarted) {
            guard casualVM.gameStarted else { return }
            try? await Task.sleep(for: .milliseconds(120))
            guard casualVM.gameStarted else { return }
            startGameSession(appModel: appModel, casualVM: casualVM)
        }
        .onChange(of: scenePhase) { _, newPhase in
            casualVM.handleScenePhaseChange(to: newPhase)
        }
        .onChange(of: casualVM.shouldAutoDismissLobby) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }

    private var guestHeroCard: some View {
        VStack(spacing: 18) {
            Text(room?.gameType.name ?? "Party Game")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .blue.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
                .lineLimit(2)
                .padding(.top, 8)

            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(colors: [.blue.opacity(0.7), .purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                    .frame(width: 96, height: 96)
                    .blur(radius: 1)
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.7), .purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 78, height: 78)
                    .shadow(color: .blue.opacity(0.5), radius: 18)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.vertical, 4)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(.blue)
                    Text("Waiting for the host…")
                        .font(.headline.weight(.bold))
                }
                Text("The match will start as soon as the host is ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.18), .purple.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
        }
    }

    private var guestStatusCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Room Info", subtitle: "You’re connected as a guest.")
                HStack(spacing: 10) {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(.blue)
                    Text(room?.gameType.name ?? "Party Game")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusPillView(title: "Connected", systemImage: "dot.radiowaves.up.forward", tint: .green)
                }
                .padding(10)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))

                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    Text("Your name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(casualVM.localPlayer?.displayName ?? "—")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(10)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
            }
        }
    }

    private var guestPlayersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(
                title: "Players · \(room?.connectedCount ?? 0) in room",
                subtitle: "Wait for the host to start the match."
            )
            ForEach(casualVM.players) { player in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white.opacity(0.08)).frame(width: 34, height: 34)
                        Text(String(player.displayName.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(player.isConnected ? .green : .gray)
                            .frame(width: 9, height: 9)
                            .overlay { Circle().stroke(.black.opacity(0.6), lineWidth: 2) }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(player.displayName)
                                .font(.subheadline.weight(.semibold))
                            if player.isHost {
                                StatusPillView(title: "Host", systemImage: "crown.fill", tint: .blue)
                            }
                            if player.id == casualVM.localPlayer?.id {
                                StatusPillView(title: "You", systemImage: "person.fill", tint: .green)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(.white.opacity(0.035), in: .rect(cornerRadius: 14))
            }
        }
    }
}

struct ReadyCheckSheet: View {
    @Bindable var casualVM: CasualRoomViewModel

    private var connectedPlayers: [GuestPlayer] {
        (casualVM.room?.players ?? []).filter { $0.isConnected }
    }

    private var readyCount: Int {
        connectedPlayers.filter { casualVM.readyConfirmedPlayerIDs.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse, options: .repeating)
                Text(casualVM.isHost ? "Waiting for players to ready up" : "Ready to start?")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(casualVM.isHost
                     ? "Game begins once everyone confirms they’re ready."
                     : "The host wants to start the match. Tap Ready to begin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 20)

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.secondary)
                Text("\(readyCount)/\(connectedPlayers.count) ready")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.06), in: .capsule)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(connectedPlayers) { player in
                        let isReady = casualVM.readyConfirmedPlayerIDs.contains(player.id)
                        HStack(spacing: 10) {
                            Image(systemName: isReady ? "checkmark.circle.fill" : "hourglass")
                                .foregroundStyle(isReady ? .green : .orange)
                            Text(player.displayName)
                                .font(.subheadline.weight(.semibold))
                            if player.isHost {
                                StatusPillView(title: "Host", systemImage: "crown.fill", tint: .blue)
                            }
                            Spacer()
                            Text(isReady ? "Ready" : "Waiting…")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isReady ? .green : .secondary)
                        }
                        .padding(10)
                        .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 180)

            VStack(spacing: 10) {
                if !casualVM.isHost {
                    Button {
                        casualVM.confirmReady()
                    } label: {
                        Label(casualVM.readyCheckLocalConfirmed ? "Ready!" : "I’m Ready",
                              systemImage: casualVM.readyCheckLocalConfirmed ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(casualVM.readyCheckLocalConfirmed)
                } else {
                    Button(role: .destructive) {
                        casualVM.cancelReadyCheck()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .presentationBackground(.thinMaterial)
    }
}
