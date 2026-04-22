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
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "number.square.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 58, height: 58)
                                    .background(.blue.opacity(0.14), in: .rect(cornerRadius: 18))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Join with Code")
                                        .font(.title3.weight(.bold))
                                    Text("Type the room code and your name. If the host starts right away, the game opens automatically on your phone.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 8) {
                                StatusPillView(title: "Fast Join", systemImage: "bolt.fill", tint: .blue)
                                StatusPillView(title: "Live Sync", systemImage: "dot.radiowaves.up.forward", tint: .green)
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Room Code")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextField("123456", text: $casualVM.roomCode)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .focused($focusedField, equals: .code)
                                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 16)
                                    .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(.white.opacity(0.08))
                                    }
                                Text("Ask your friend for the 6-digit code.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

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
            if casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focusedField = .code
            } else {
                focusedField = .name
            }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLeaveConfirm: Bool = false

    private var room: CasualRoom? { casualVM.room }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    roomHeaderCard
                    if casualVM.isHost {
                        hostActionsSection
                    }
                    playersSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Party Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Leave") {
                    showLeaveConfirm = true
                }
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
            Text(casualVM.isHost ? "This will close the room for everyone." : "You will leave this room.")
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
            Button("Return to Lobby") { dismiss() }
        } message: {
            Text("The host left the game. This room code has expired.")
        }
        .sheet(isPresented: $casualVM.readyCheckActive) {
            ReadyCheckSheet(casualVM: casualVM)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
        }
        .task(id: casualVM.gameStarted) {
            guard casualVM.gameStarted else { return }
            startGameSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            casualVM.handleScenePhaseChange(to: newPhase)
        }
    }

    private var roomHeaderCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(height: 100)
                    .overlay {
                        LinearGradient(
                            colors: [.green.opacity(0.86), .teal.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .allowsHitTesting(false)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room?.gameType.name ?? "Party Game")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("Party Room")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            if room?.isFull == true {
                                StatusPillView(title: "Full", systemImage: "person.crop.circle.badge.xmark", tint: .white)
                            }
                        }
                        .padding(16)
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 16))

                HStack(spacing: 10) {
                    Text("Room Code")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(room?.code ?? "---")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                        .kerning(4)
                    Button {
                        UIPasteboard.general.string = room?.code ?? ""
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 14))

                if let code = room?.code, let gameName = room?.gameType.name {
                    ShareLink(item: "Join my 888PartyPlay \(gameName) room! Code: \(code)") {
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
                            ShareLink(item: "Join my 888PartyPlay \(gameName) room! Code: \(code)") {
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
        VStack(spacing: 8) {
            Button("Start Match") {
                casualVM.startGame()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!casualVM.canStart)

            if let room, room.players.count < room.minPlayers {
                Text("Need at least \(room.minPlayers) players to start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startGameSession() {
        guard let room = casualVM.room else { return }
        let players = casualVM.buildPlayersForSession()
        guard appModel.activeSession?.roomCode != room.code else { return }
        appModel.startCasualMultiplayerSession(
            game: room.gameType,
            mode: room.playMode,
            players: players,
            roomCode: room.code,
            localPlayerID: casualVM.localPlayer?.id
        )
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
