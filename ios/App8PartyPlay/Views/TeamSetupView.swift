import SwiftUI

struct TeamSetupView: View {
    let appModel: AppViewModel
    @Bindable var casualVM: CasualRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLeaveConfirm: Bool = false

    private var room: CasualRoom? { casualVM.room }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    roomHeaderCard
                    if casualVM.isHost {
                        hostToolbar
                    }
                    teamSections
                    unassignedSection
                    if casualVM.isHost {
                        startSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Team Setup")
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
        .onChange(of: casualVM.gameStarted) { _, started in
            if started {
                startGameSession()
            }
        }
        .onChange(of: casualVM.shouldAutoDismissLobby) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }

    private var roomHeaderCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(height: 90)
                    .overlay {
                        LinearGradient(
                            colors: [.purple.opacity(0.86), .indigo.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .allowsHitTesting(false)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room?.gameType.name ?? "Party Game")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    StatusPillView(title: "Team Mode", systemImage: "person.2.badge.gearshape.fill", tint: .white)
                                }
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
                        .foregroundStyle(.purple)
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
            }
        }
    }

    private var hostToolbar: some View {
        HStack(spacing: 10) {
            Button {
                casualVM.randomizeTeams()
            } label: {
                Label("Randomize", systemImage: "shuffle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.purple.opacity(0.16), in: .capsule)
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)

            Button {
                casualVM.autoBalanceTeams()
            } label: {
                Label("Auto-Balance", systemImage: "equal.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.blue.opacity(0.16), in: .capsule)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var teamSections: some View {
        VStack(spacing: 14) {
            teamSection(
                team: casualVM.teamState.teamA,
                color: .orange,
                icon: "flame.fill"
            )
            teamSection(
                team: casualVM.teamState.teamB,
                color: .cyan,
                icon: "bolt.fill"
            )
        }
    }

    private func teamSection(team: TeamAssignment, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                Text(team.name)
                    .font(.subheadline.weight(.bold))
                Text("(\(team.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if team.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(casualVM.isHost ? "Drag or tap players to assign" : "Waiting for host to assign...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.06), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(color.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(teamPlayerList(team: team), id: \.id) { player in
                        teamPlayerRow(player: player, team: team, color: color)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(color.opacity(0.2))
        }
    }

    private func teamPlayerList(team: TeamAssignment) -> [GuestPlayer] {
        guard let room else { return [] }
        return team.playerIDs.compactMap { id in
            room.players.first { $0.id == id }
        }
    }

    private func teamPlayerRow(player: GuestPlayer, team: TeamAssignment, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 32, height: 32)
                Text(String(player.displayName.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(player.isConnected ? .green : .gray)
                    .frame(width: 8, height: 8)
                    .overlay {
                        Circle().stroke(.black.opacity(0.6), lineWidth: 1.5)
                    }
            }

            Text(player.displayName)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 0)

            if casualVM.isHost {
                let otherTeamID = team.id == "team_a" ? "team_b" : "team_a"
                let otherTeamName = team.id == "team_a" ? "B" : "A"
                Button {
                    casualVM.assignPlayer(player.id, toTeam: otherTeamID)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(otherTeamName)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.06), in: .capsule)
                }
                .buttonStyle(.plain)

                Button {
                    casualVM.unassignPlayer(player.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.06), in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.03), in: .rect(cornerRadius: 12))
    }

    private var unassignedSection: some View {
        Group {
            let unassigned = casualVM.unassignedPlayers
            if !unassigned.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeaderView(
                        title: "Unassigned · \(unassigned.count)",
                        subtitle: casualVM.isHost ? "Tap to assign players to a team." : "Waiting for host to assign players."
                    )

                    VStack(spacing: 6) {
                        ForEach(unassigned) { player in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.08))
                                        .frame(width: 32, height: 32)
                                    Text(String(player.displayName.prefix(1)).uppercased())
                                        .font(.caption.weight(.bold))
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(player.isConnected ? .green : .gray)
                                        .frame(width: 8, height: 8)
                                        .overlay {
                                            Circle().stroke(.black.opacity(0.6), lineWidth: 1.5)
                                        }
                                }

                                Text(player.displayName)
                                    .font(.subheadline.weight(.semibold))

                                Spacer(minLength: 0)

                                if casualVM.isHost {
                                    Button {
                                        casualVM.assignPlayer(player.id, toTeam: "team_a")
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 9))
                                            Text("A")
                                                .font(.caption2.weight(.bold))
                                        }
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.orange.opacity(0.12), in: .capsule)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        casualVM.assignPlayer(player.id, toTeam: "team_b")
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 9))
                                            Text("B")
                                                .font(.caption2.weight(.bold))
                                        }
                                        .foregroundStyle(.cyan)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.cyan.opacity(0.12), in: .capsule)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(10)
                            .background(.white.opacity(0.035), in: .rect(cornerRadius: 14))
                        }
                    }
                }
            }
        }
    }

    private var startSection: some View {
        VStack(spacing: 8) {
            let allAssigned = casualVM.unassignedPlayers.isEmpty
            let teamsValid = casualVM.teamState.isValid

            Button("Start Team Match") {
                casualVM.startGame()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!casualVM.canStart)

            if let room {
                if room.players.count < room.minPlayers {
                    Text("Need at least \(room.minPlayers) players to start.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !allAssigned {
                    Text("All players must be assigned to a team.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !teamsValid {
                    Text("Each team needs at least 1 player.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func startGameSession() {
        guard let room = casualVM.room else { return }
        let players = casualVM.buildPlayersForSession()
        let localID = casualVM.localPlayer?.id

        casualVM.onSessionEnded = { [weak appModel] in
            appModel?.dismissSession()
        }
        casualVM.service.onGameStateSync = { [weak appModel] payload in
            appModel?.applyRemoteCasualGameState(payload)
        }
        appModel.attachCasualRoomService(
            casualVM.service,
            localPlayerID: localID,
            roomID: room.id,
            sessionToken: casualVM.localPlayer?.sessionToken,
            cleanup: {
                casualVM.shouldAutoDismissLobby = true
                casualVM.disconnect()
            }
        )

        guard appModel.activeSession?.roomCode != room.code else { return }

        appModel.startCasualMultiplayerSession(
            game: room.gameType,
            mode: room.playMode,
            players: players,
            roomCode: room.code,
            localPlayerID: localID,
            sessionID: room.id,
            syncToPeers: casualVM.isHost
        )

        if casualVM.isHost {
            appModel.rebroadcastCurrentCasualSessionState()
        }
    }
}
