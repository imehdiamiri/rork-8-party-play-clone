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
    @Environment(\.dismiss) private var dismiss

    init(appModel: AppViewModel, onJoinedAndStarted: ((CasualRoomViewModel) -> Void)? = nil) {
        self.appModel = appModel
        self.onJoinedAndStarted = onJoinedAndStarted
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "number.square.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text("Join a Room")
                        .font(.title3.weight(.bold))

                    Text("Enter the room code and your name.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Label("Ask your friend for a code", systemImage: "lightbulb.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.yellow.opacity(0.12), in: .capsule)
                        .overlay { Capsule().strokeBorder(.yellow.opacity(0.25)) }
                }

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Room code", text: $casualVM.roomCode)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 14)
                            .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.secondary.opacity(0.2))
                            }
                        if casualVM.roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Room code is required")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Your name", text: $casualVM.displayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 14)
                            .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.secondary.opacity(0.2))
                            }
                        if casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Display name is required")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Button("Join Room") {
                        casualVM.joinRoom()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(
                        casualVM.isBusy ||
                        casualVM.roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

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
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .onChange(of: casualVM.isConnected) { _, connected in
            if connected {
                navigateToLobby = true
                onJoinedAndStarted?(casualVM)
            }
        }
        .alert("Kicked", isPresented: $casualVM.wasKicked) {
            Button("OK") { dismiss() }
        } message: {
            Text("You were removed from the room by the host.")
        }
        .alert("Room Closed", isPresented: $casualVM.roomClosed) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host closed this room.")
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
        .alert("Kicked", isPresented: $casualVM.wasKicked) {
            Button("OK") { dismiss() }
        } message: {
            Text("You were removed from the room by the host.")
        }
        .alert("Room Closed", isPresented: $casualVM.roomClosed) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host closed this room.")
        }
        .alert("Host Left", isPresented: $casualVM.hostLeft) {
            Button("Return to Lobby") { dismiss() }
        } message: {
            Text("The host left the game. You've been returned to the main lobby.")
        }
        .onChange(of: casualVM.gameStarted) { _, started in
            if started {
                startGameSession()
            }
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
        appModel.startCasualMultiplayerSession(
            game: room.gameType,
            players: players,
            roomCode: room.code
        )
    }
}
