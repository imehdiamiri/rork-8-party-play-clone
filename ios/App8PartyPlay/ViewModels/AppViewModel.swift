import Foundation
import Observation
import Supabase
import SwiftUI

@Observable
@MainActor
final class AppViewModel {
    var selectedTab: AppTab = .home
    var isAuthenticated: Bool = false
    var isCheckingSession: Bool = true
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    var username: String = "Guest"
    var displayName: String = "Guest"
    var email: String?
    var publicUserID: Int?
    var avatarSymbol: String = "person.crop.circle.fill"
    var profileImageData: Data? = nil
    var currentLanguageCode: String = AppLanguage.english.rawValue
    var isSoundEnabled: Bool = true {
        didSet { FeedbackService.shared.updateSettings(sound: isSoundEnabled, vibration: isVibrationEnabled) }
    }
    var isVibrationEnabled: Bool = true {
        didSet { FeedbackService.shared.updateSettings(sound: isSoundEnabled, vibration: isVibrationEnabled) }
    }
    var currentProvider: AuthProvider = .guest
    var onlineUserIDs: Set<UUID> = []

    var currentLanguage: AppLanguage {
        AppLanguage(rawValue: currentLanguageCode) ?? .english
    }

    var starWallet: StarWallet = StarWallet(balance: 100)
    var subscription: UserSubscription = .none
    var gameUnlocks: [GameUnlockInfo] = []
    var games: [GameDefinition]
    var friends: [Friend]
    var requests: [FriendRequest]
    var activities: [ActivityItem]
    var offlineFriends: [Friend] {
        didSet { persistOfflineFriends() }
    }
    var friendSearchResults: [FriendSearchResult]
    var latestFriendSearchQuery: String = ""
    var roomInvites: [RoomInvite]
    var visibleRooms: [GameRoom]
    var currentRoom: GameRoom?
    var quickRejoinRoom: GameRoom?
    var activeSession: GameSession?
    var currentRoomAccess: RoomAccess = .privateRoom
    var invitedOnlineFriendIDs: Set<UUID> = []
    var currentImposterSettings: ImposterSettings? = nil
    var currentMemoryGridSettings: MemoryGridSettings? = nil
    var currentMemoryPathSettings: MemoryPathSettings? = nil
    var currentPassGuessSettings: PassGuessSettings = .default
    var currentTapInOrderSettings: TapInOrderSettings? = nil
    var currentColorTrapSettings: ColorTrapSettings? = nil
    var currentSpinBottleDifficulty: SpinBottleDifficulty = .classic
    var profileContextGame: GameType? = nil
    var lobbyNotice: String?
    var errorMessage: String?
    var economyFeedback: EconomyFeedback?
    var isBusy: Bool = false
    var isSearchingFriends: Bool = false
    var isProcessingWalletAction: Bool = false
    var inviteCode: String = ""
    var inviteTotalCount: Int = 0
    var inviteStarsEarned: Int = 0
    var isRedeemingInvite: Bool = false
    var pendingInviteCode: String?

    let authService: SupabaseAuthService
    let databaseService: SupabaseDatabaseService
    let realtimeService: SupabaseRealtimeService
    let resilienceService: SessionResilienceService
    var currentUserID: UUID?
    var currentProfileID: UUID?
    var activeSessionRecordID: UUID?
    var sessionOverridePlayerID: UUID?

    var connectionState: SessionResilienceService.ConnectionState = .connected
    var sessionOnlinePlayerIDs: Set<UUID> = []
    var sessionExitedPlayerIDs: Set<UUID> = []
    var showHostLeftAlert: Bool = false
    var showRejoinPrompt: Bool = false
    var pendingRejoinSessionID: UUID?
    var syncErrorMessage: String?
    var requestCasualSheetDismiss: Bool = false

    var sessionPlayerID: UUID? {
        if let sessionOverridePlayerID {
            if let activeSession {
                if activeSession.players.contains(where: { $0.id == sessionOverridePlayerID }) {
                    return sessionOverridePlayerID
                }
            } else {
                return sessionOverridePlayerID
            }
        }
        return currentProfileID ?? currentUserID
    }

    private var currentPlayerID: UUID? {
        sessionPlayerID
    }

    private var isCurrentUserHost: Bool {
        guard let session = activeSession, let currentPlayerID else { return false }
        return session.players.contains { $0.id == currentPlayerID && $0.isHost }
    }

    private var isApplyingRemoteSessionState: Bool = false
    // Strong reference: the guest's CasualJoinRoomView owns CasualRoomViewModel via
    // @State. When the QuickJoinSheet fullScreenCover dismisses to let the game
    // session cover open, that view (and the VM) deallocate. A weak ref here
    // would release the CasualRoomService, unsubscribe its realtime channel, and
    // freeze the guest on the spectator view with no inbound game-state updates
    // and no way to exit. The session must outlive the lobby sheet, so the app
    // model retains the service until `detachCasualRoomService()`.
    private var casualRoomService: CasualRoomService?
    private var casualSessionOriginPlayerID: UUID?
    private var casualSessionRoomID: UUID?
    private var casualSessionToken: String?
    private var casualRoomCleanupHandler: (() -> Void)?
    private var timerTask: Task<Void, Never>?
    private var wasInBackground: Bool = false
    private var backgroundTimersPaused: Bool = false
    private var currentStateVersion: Int = 0
    private var lastAppliedRemoteVersion: Int = 0
    private var casualRebroadcastPumpTask: Task<Void, Never>?
    private var casualRematchPollTask: Task<Void, Never>?
    private var isStartingRematch: Bool = false

    init() {
        self.authService = SupabaseAuthService()
        self.databaseService = SupabaseDatabaseService()
        self.realtimeService = SupabaseRealtimeService()
        self.resilienceService = SessionResilienceService()
        self.games = [
            GameDefinition(id: .reverseSinging, accentName: "purple"),
            GameDefinition(id: .guessTheSeconds, accentName: "blue"),
            GameDefinition(id: .imposter, accentName: "red"),
            GameDefinition(id: .memoryGrid, accentName: "cyan"),
            GameDefinition(id: .tenTangle, accentName: "pink"),
            GameDefinition(id: .memoryPath, accentName: "teal"),
            GameDefinition(id: .passGuess, accentName: "yellow"),
            GameDefinition(id: .tapInOrder, accentName: "orange"),
            GameDefinition(id: .colorTrap, accentName: "pink"),
            GameDefinition(id: .drawRush, accentName: "cyan"),
            GameDefinition(id: .spinBottle, accentName: "red")
        ]
        self.friends = []
        self.requests = []
        self.activities = []
        self.offlineFriends = Self.loadOfflineFriends()
        self.friendSearchResults = []
        self.roomInvites = []
        self.visibleRooms = []

        authService.startAuthListener { [weak self] session in
            guard let self else { return }
            Task { @MainActor in
                if let session {
                    await self.handleAuthenticatedSession(session)
                } else if self.currentUserID != nil || self.currentProvider != .guest {
                    self.applySignedOutState()
                }
            }
        }

        resilienceService.onConnectionStateChanged = { [weak self] state in
            self?.connectionState = state
        }
        resilienceService.onSyncError = { [weak self] message in
            self?.syncErrorMessage = message
        }

        Task {
            await restoreSession()
        }

        loadSettings()
    }

    // MARK: - App Lifecycle

    func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .background:
            handleEnterBackground()
        case .active:
            handleReturnToForeground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func handleEnterBackground() {
        wasInBackground = true
        // Keep the active session alive. We only pause the host's round timer —
        // the room stays open, players stay connected, and the game screen is
        // still presented when the user re-opens the app. Only explicit Leave
        // from the host tears down the session.
        if activeSession != nil, activeSession?.mode != .singleDevice, isCurrentUserHost {
            backgroundTimersPaused = true
            timerTask?.cancel()
            timerTask = nil
        }
    }

    private func handleReturnToForeground() {
        guard wasInBackground else { return }
        wasInBackground = false

        if let session = activeSession, session.mode != .singleDevice {
            if let roomCode = session.roomCode {
                resubscribeAndResync(roomCode: roomCode)
            }
            if backgroundTimersPaused, isCurrentUserHost, session.phase == .liveRound {
                startTimer()
            }
            backgroundTimersPaused = false
            // Host / active player: immediately rebroadcast so backgrounded peers
            // re-sync on our resume. Spectators: proactively request a fresh
            // snapshot from the authoritative active player so they don't wait
            // for the next rebroadcast pump tick.
            MultiplayerTelemetry.shared.log(event: "app_resumed_in_match", source: "resume")
            MultiplayerTelemetry.shared.log(event: "reconnect_during_match", source: "resume")
            if isCurrentUserHost || isCurrentPlayerTurn(in: session) {
                rebroadcastCurrentCasualSessionState(attempts: 3)
            } else if let service = casualRoomService {
                MultiplayerTelemetry.shared.log(event: "spectator_snapshot_requested", source: "resume")
                Task { await service.requestGameStateSnapshot() }
            }
            // Active-player validation on resume: a peer's authoritative rebroadcast
            // (triggered by our snapshot request above, or by the host pump) will
            // reconcile our turn index via the monotonic stateVersion guard in
            // applyRemoteCasualGameState. If the backend has already advanced past
            // us, the next inbound broadcast flips us back to spectator.
        } else if currentRoom != nil, let code = currentRoom?.code {
            observeRoom(code: code)
        }

        if let currentUserID {
            realtimeService.subscribeToSocialUpdates(userID: currentUserID) { [weak self] in
                guard let self else { return }
                Task { try? await self.refreshDashboardData() }
            }
            realtimeService.trackPresence(userID: currentUserID) { [weak self] ids in
                self?.onlineUserIDs = ids
            }
        }
    }

    private func resubscribeAndResync(roomCode: String) {
        Task {
            await resilienceService.attemptReconnect(
                roomCode: roomCode,
                realtimeService: realtimeService,
                onRoomUpdate: { [weak self] updatedCode in
                    guard let self else { return }
                    Task {
                        do {
                            let room = try await self.databaseService.fetchRoom(code: updatedCode)
                            let mode = self.currentRoom?.mode ?? .multiDevice
                            let gameRoom = self.mapToGameRoom(room, mode: mode)
                            self.applyRoom(gameRoom, notice: "Lobby synced.")
                        } catch {
                            self.syncErrorMessage = "Failed to sync room: \(error.localizedDescription)"
                        }
                    }
                },
                onSessionUpdate: { [weak self] record in
                    guard let self else { return }
                    self.handleRemoteSessionWithHostCheck(record)
                }
            )
        }
    }

    // MARK: - Session Recovery

    func checkForRejoinableSession() {
        Task {
            if let record = await resilienceService.checkForActiveSession() {
                pendingRejoinSessionID = record.id
                autoRejoinSession()
            }
        }
    }

    private func autoRejoinSession() {
        guard let sessionID = pendingRejoinSessionID else { return }
        Task {
            do {
                let record = try await resilienceService.fetchLatestSessionState(sessionID: sessionID)
                guard record.status == "active" else {
                    resilienceService.clearActiveSession()
                    pendingRejoinSessionID = nil
                    return
                }
                applyRemoteSessionRecord(record)
                if let roomCode = record.sessionState?.roomCode {
                    observeRoom(code: roomCode)
                }
                pendingRejoinSessionID = nil
            } catch {
                resilienceService.clearActiveSession()
                pendingRejoinSessionID = nil
            }
        }
    }

    func rejoinSession() {
        guard let sessionID = pendingRejoinSessionID else { return }
        showRejoinPrompt = false
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let record = try await resilienceService.fetchLatestSessionState(sessionID: sessionID)
                guard record.status == "active" else {
                    resilienceService.clearActiveSession()
                    errorMessage = "Session has ended."
                    pendingRejoinSessionID = nil
                    return
                }
                applyRemoteSessionRecord(record)
                if let roomCode = record.sessionState?.roomCode {
                    observeRoom(code: roomCode)
                }
                pendingRejoinSessionID = nil
            } catch {
                errorMessage = "Failed to rejoin: \(error.localizedDescription)"
                resilienceService.clearActiveSession()
                pendingRejoinSessionID = nil
            }
        }
    }

    func declineRejoin() {
        showRejoinPrompt = false
        pendingRejoinSessionID = nil
        resilienceService.clearActiveSession()
    }

    // MARK: - Host Disconnect

    private func handleRemoteSessionWithHostCheck(_ record: GameSessionRecord) {
        // Only an explicit cancellation by the host ends the session for guests.
        // A host briefly going to background or losing network does NOT end the room —
        // the game screen stays active and resumes when the host comes back.
        if record.status == "cancelled" {
            showHostLeftAlert = true
            return
        }
        applyRemoteSessionRecord(record)
    }

    func handleHostLeftDismiss() {
        showHostLeftAlert = false
        timerTask?.cancel()
        timerTask = nil
        activeSession = nil
        activeSessionRecordID = nil
        resilienceService.clearActiveSession()
        errorMessage = "The host left the game. Session ended."
    }

    // MARK: - Auth

    func signIn(username: String, password: String) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        economyFeedback = nil
        Task {
            defer { isBusy = false }
            do {
                let account = try await authService.signIn(username: username, password: password)
                try await bootstrap(account: account)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signUp(username: String, password: String) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        economyFeedback = nil
        Task {
            defer { isBusy = false }
            do {
                let account = try await authService.signUp(username: username, password: password)
                try await bootstrap(account: account)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signInWithGoogle() {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        economyFeedback = nil
        Task {
            defer { isBusy = false }
            do {
                let account = try await authService.signInWithGoogle()
                try await bootstrap(account: account)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signInWithApple() {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        economyFeedback = nil
        Task {
            defer { isBusy = false }
            do {
                let account = try await authService.signInWithApple()
                try await bootstrap(account: account)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func goToLogin() {
        isAuthenticated = false
    }

    func deleteAccount() {
        guard currentProvider != .guest, currentUserID != nil else {
            errorMessage = "You must be logged in to delete your account."
            return
        }
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                try await databaseService.deleteAccountData()
                try? await authService.signOut()
                applySignedOutState()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func logout() {
        let shouldSignOutRemotely = currentProvider != .guest || currentUserID != nil
        applySignedOutState()
        Task {
            if shouldSignOutRemotely {
                try? await authService.signOut()
            }
            resilienceService.clearActiveSession()
        }
    }

    func continueAsGuest() {
        applyGuestState()
    }

    func handleOAuthCallback(_ url: URL) {
        guard url.scheme == SupabaseConfiguration.callbackScheme else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let session = try await authService.handleOAuthCallback(url: url)
                await handleAuthenticatedSession(session)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var isCurrentUserLobbyHost: Bool {
        guard let room = currentRoom, let currentPlayerID else { return false }
        return room.players.contains { $0.id == currentPlayerID && $0.isHost }
    }

    var canStartCurrentLobbyMatch: Bool {
        guard let room = currentRoom else { return false }
        return isCurrentUserLobbyHost && room.players.count >= room.minPlayers && room.allPlayersReady
    }


    // MARK: - Single Device Mode

    func startSingleDeviceMode(game: GameType, playerNames: [String], roundCount: Int = 3) {
        guard canPlayGame(game) else {
            economyFeedback = EconomyFeedback(title: "Premium Game", message: "Subscribe to 8PartyPlay+ to unlock \(game.name).", style: .warning)
            return
        }
        let resolvedPlayers: [PlayerProfile] = playerNames.enumerated().map { index, rawName in
            let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = cleanName.isEmpty ? "Player \(index + 1)" : cleanName
            return PlayerProfile(username: name, isHost: index == 0, isReady: true)
        }
        startSession(game: game, mode: .singleDevice, players: resolvedPlayers, roomCode: nil, roundCount: roundCount)
    }

    // MARK: - Room Management

    func createRoom(for game: GameType, mode: GameMode, access: RoomAccess, invitedFriendIDs: Set<UUID>, completion: @escaping @MainActor (GameRoom?) -> Void) {
        guard let currentUserID else {
            errorMessage = SupabaseError.notAuthenticated.localizedDescription
            completion(nil)
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let roomRecord = try await databaseService.createRoom(game: game, hostUserID: currentUserID, access: access)
                currentRoomAccess = access
                invitedOnlineFriendIDs = invitedFriendIDs
                if access == .privateRoom {
                    try await databaseService.syncRoomInvites(roomID: roomRecord.id, inviterUserID: currentUserID, invitedUserIDs: invitedFriendIDs)
                }
                let room = try await databaseService.fetchRoom(code: roomRecord.code)
                let gameRoom = mapToGameRoom(room, mode: mode)
                applyRoom(gameRoom, notice: access == .privateRoom ? "Private room \(gameRoom.code) is ready." : "Public room \(gameRoom.code) is now open.")
                try? await refreshDashboardData()
                observeRoom(code: gameRoom.code)
                completion(gameRoom)
            } catch {
                errorMessage = error.localizedDescription
                completion(nil)
            }
        }
    }

    func joinRoom(code: String, game: GameType, completion: @escaping @MainActor (GameRoom?) -> Void) {
        guard let currentUserID else {
            errorMessage = SupabaseError.notAuthenticated.localizedDescription
            completion(nil)
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let roomRecord = try await databaseService.joinRoom(code: code, userID: currentUserID)
                let room = try await databaseService.fetchRoom(code: roomRecord.code)
                let gameRoom = mapToGameRoom(room, mode: .multiDevice)
                currentRoomAccess = gameRoom.access
                invitedOnlineFriendIDs = gameRoom.invitedFriendIDs
                applyRoom(gameRoom, notice: "You joined room \(gameRoom.code).")
                try? await refreshDashboardData()
                observeRoom(code: gameRoom.code)
                completion(gameRoom)
            } catch {
                errorMessage = error.localizedDescription
                completion(nil)
            }
        }
    }

    func toggleReady(for playerID: UUID) {
        guard let room = currentRoom else { return }
        guard playerID == currentProfileID else { return }
        guard let member = room.players.first(where: { $0.id == playerID }) else { return }
        Task {
            do {
                try await databaseService.updateReadyState(roomID: room.id, userID: playerID, isReady: !member.isReady)
                let refreshed = try await databaseService.fetchRoom(code: room.code)
                let gameRoom = mapToGameRoom(refreshed, mode: room.mode)
                applyRoom(gameRoom, notice: "Ready states updated.")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func inviteFriend(_ friend: Friend) {
        guard friend.kind == .online else { return }
        guard let room = currentRoom, let currentUserID else {
            invitedOnlineFriendIDs.insert(friend.id)
            return
        }
        invitedOnlineFriendIDs.insert(friend.id)
        Task {
            do {
                try await databaseService.syncRoomInvites(roomID: room.id, inviterUserID: currentUserID, invitedUserIDs: invitedOnlineFriendIDs)
                let refreshed = try await databaseService.fetchRoom(code: room.code)
                let gameRoom = mapToGameRoom(refreshed, mode: room.mode)
                applyRoom(gameRoom, notice: "Invite sent to \(friend.name).")
                try await refreshDashboardData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateRoomAccess(_ access: RoomAccess) {
        currentRoomAccess = access
        lobbyNotice = access == .publicRoom ? "Public room enabled." : "Private room enabled."
    }

    func updatePassGuessSettings(_ settings: PassGuessSettings) {
        currentPassGuessSettings = settings
        if let session = activeSession,
           session.game.rawValue == GameType.passGuess.rawValue,
           let state = session.passGuessState,
           state.phase == .intro {
            let updatedState = PassGuessRoundState(settings: settings, phase: .intro, question: resolvePassGuessQuestion(settings: settings), archivedRounds: state.archivedRounds)
            updateSession(copying: session, passGuessState: updatedState)
        }
    }

    func openInvite(_ invite: RoomInvite, completion: @escaping @MainActor (GameRoom?) -> Void) {
        joinRoom(code: invite.roomCode, game: invite.game) { room in
            completion(room)
        }
        Task {
            try? await databaseService.respondToRoomInvite(inviteID: invite.id, status: "accepted")
            try? await refreshDashboardData()
        }
    }

    func declineInvite(_ invite: RoomInvite) {
        Task {
            do {
                try await databaseService.respondToRoomInvite(inviteID: invite.id, status: "declined")
                try await refreshDashboardData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Casual Multiplayer

    func startCasualMultiplayerSession(game: GameType, mode: GameMode, players: [PlayerProfile], roomCode: String, localPlayerID: UUID?, sessionID: UUID? = nil, syncToPeers: Bool = true) {
        sessionOverridePlayerID = localPlayerID
        // Reset monotonic counters for the new match so stateVersion starts fresh.
        currentStateVersion = 0
        lastAppliedRemoteVersion = 0
        startSession(game: game, mode: mode, players: players, roomCode: roomCode, sessionID: sessionID, syncToPeers: syncToPeers)
        if mode == .multiDevice || mode == .teamMode {
            startCasualRebroadcastPump()
        }
    }

    func attachCasualRoomService(_ service: CasualRoomService, localPlayerID: UUID?, roomID: UUID?, sessionToken: String?, cleanup: (() -> Void)? = nil) {
        casualRoomService = service
        casualSessionOriginPlayerID = localPlayerID
        casualSessionRoomID = roomID
        casualSessionToken = sessionToken
        casualRoomCleanupHandler = cleanup
        if let localPlayerID {
            sessionOverridePlayerID = localPlayerID
        }
        // If a peer (resuming spectator) asks for a fresh snapshot, the
        // authoritative active player / host immediately rebroadcasts so the
        // spectator doesn't have to wait for the 1.5s rebroadcast pump.
        service.onSnapshotRequest = { [weak self] in
            guard let self else { return }
            guard let session = self.activeSession,
                  session.mode == .multiDevice || session.mode == .teamMode else { return }
            if self.isCurrentUserHost || self.isCurrentPlayerTurn(in: session) {
                MultiplayerTelemetry.shared.log(event: "spectator_snapshot_received", source: "peer")
                self.rebroadcastCurrentCasualSessionState(attempts: 2)
            }
        }
    }

    func detachCasualRoomService() {
        if let service = casualRoomService {
            Task { await service.disconnect() }
        }
        casualRoomService = nil
        casualSessionOriginPlayerID = nil
        casualSessionRoomID = nil
        casualSessionToken = nil
        casualRoomCleanupHandler = nil
    }

    func rebroadcastCurrentCasualSessionState(attempts: Int = 4) {
        guard attempts > 0,
              let session = activeSession,
              session.mode == .multiDevice || session.mode == .teamMode,
              let service = casualRoomService else { return }

        let state = makeSessionStateRecord(from: session)
        let origin = casualSessionOriginPlayerID ?? sessionPlayerID ?? UUID()

        Task {
            for attempt in 0..<attempts {
                let payload = CasualGameStatePayload(
                    sessionId: session.id.uuidString,
                    originPlayerId: origin.uuidString,
                    state: state
                )
                await service.broadcastGameState(payload)
                if attempt < attempts - 1 {
                    try? await Task.sleep(for: .milliseconds(450))
                }
            }
        }
    }

    /// Starts a periodic rebroadcast loop so backgrounded/late-joining peers
    /// receive the latest authoritative session state without needing a DB fetch.
    /// Only the host pushes; all other clients treat their inbound stream as
    /// monotonic via `stateVersion`.
    private func startCasualRebroadcastPump() {
        casualRebroadcastPumpTask?.cancel()
        casualRebroadcastPumpTask = Task { [weak self] in
            // Fire an immediate broadcast so spectators entering the game don't
            // have to wait a full tick for their first authoritative state.
            await MainActor.run {
                guard let self else { return }
                guard let session = self.activeSession,
                      session.mode == .multiDevice || session.mode == .teamMode,
                      self.isCurrentUserHost,
                      let service = self.casualRoomService else { return }
                let state = self.makeSessionStateRecord(from: session)
                let origin = self.casualSessionOriginPlayerID ?? self.sessionPlayerID ?? UUID()
                let payload = CasualGameStatePayload(sessionId: session.id.uuidString, originPlayerId: origin.uuidString, state: state)
                Task { await service.broadcastGameState(payload) }
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    guard let session = self.activeSession,
                          session.mode == .multiDevice || session.mode == .teamMode,
                          self.isCurrentUserHost,
                          let service = self.casualRoomService else { return }
                    let state = self.makeSessionStateRecord(from: session)
                    let origin = self.casualSessionOriginPlayerID ?? self.sessionPlayerID ?? UUID()
                    let payload = CasualGameStatePayload(sessionId: session.id.uuidString, originPlayerId: origin.uuidString, state: state)
                    Task { await service.broadcastGameState(payload) }
                }
            }
        }
    }

    private func stopCasualRebroadcastPump() {
        casualRebroadcastPumpTask?.cancel()
        casualRebroadcastPumpTask = nil
    }

    // MARK: - Authoritative turn guard

    /// Attempts to claim the next turn advance against the backend. Returns true
    /// if the caller is the real active player and the CAS on turn_version wins.
    /// For single-device / pre-attach modes this is a no-op that returns true.
    func authorizeCasualTurnAdvance(expectedIndex: Int) async -> Bool {
        guard activeSession?.mode == .multiDevice || activeSession?.mode == .teamMode else { return true }
        guard let service = casualRoomService,
              let roomID = casualSessionRoomID,
              let token = casualSessionToken else { return true }
        // Strict backend-authoritative advance: retry transient RPC failures, but
        // never let the client advance locally without a real server success.
        // Only an authoritative `success == true` returns true. Explicit server
        // rejections (stale_turn / not_active_player) and exhausted retries on
        // rpc_failed both abort the advance, so two clients can never race past
        // the backend.
        MultiplayerTelemetry.shared.log(event: "turn_advance_requested", source: "ui", props: ["expected_index": "\(expectedIndex)"])
        for attempt in 0..<3 {
            let start = Date()
            let resp = await service.claimTurnAdvance(roomID: roomID, sessionToken: token, expectedIndex: expectedIndex)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            if resp.success == true {
                let turnMs = MultiplayerTelemetry.shared.elapsedTurnMs()
                MultiplayerTelemetry.shared.log(
                    event: "turn_advance_authorized",
                    source: "rpc",
                    success: true,
                    turn_rpc_latency_ms: latency,
                    turn_duration_ms: turnMs
                )
                MultiplayerTelemetry.shared.markTurnStarted()
                return true
            }
            if resp.error == "rpc_failed" {
                MultiplayerTelemetry.shared.log(
                    event: "turn_advance_rpc_failed",
                    source: "rpc",
                    success: false,
                    failure_reason: "rpc_failed",
                    turn_rpc_latency_ms: latency,
                    props: ["attempt": "\(attempt)"]
                )
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
                    continue
                }
                syncErrorMessage = "Network error. Please try again."
                return false
            }
            MultiplayerTelemetry.shared.log(
                event: "turn_advance_rejected",
                source: "rpc",
                success: false,
                failure_reason: resp.error ?? "unknown",
                turn_rpc_latency_ms: latency
            )
            return false
        }
        return false
    }

    // MARK: - Rematch backend polling

    /// Polls backend `rematch_ready_at` per player so every device sees the same
    /// authoritative vote list on the results screen, without depending on the
    /// host being online to merge peer broadcasts.
    func startCasualRematchPollIfNeeded() {
        guard casualRematchPollTask == nil else { return }
        guard let service = casualRoomService, let roomID = casualSessionRoomID else { return }
        casualRematchPollTask = Task { [weak self] in
            while !Task.isCancelled {
                let readyIDs = await service.fetchRematchReadyPlayerIDs(roomID: roomID)
                let roomSnapshot: (CasualRoomRecord, [CasualRoomPlayerRecord])? = try? await service.fetchRoomFromDB(roomID: roomID)
                await MainActor.run {
                    guard let self else { return }
                    guard let session = self.activeSession, session.phase == .finished else {
                        self.casualRematchPollTask?.cancel()
                        self.casualRematchPollTask = nil
                        return
                    }
                    let merged = Array(Set(session.rematchPlayerIDs).union(readyIDs))
                    if Set(merged) != Set(session.rematchPlayerIDs) {
                        self.updateSession(copying: session, rematchPlayerIDs: merged)
                    }
                    if let records = roomSnapshot?.1 {
                        let onlineIDs = Set(records.filter(\.isConnected).map(\.guestPlayerId))
                        let presentIDs = Set(records.map(\.guestPlayerId))
                        self.sessionOnlinePlayerIDs = onlineIDs
                        let sessionPlayerIDs = Set(session.players.map(\.id))
                        self.sessionExitedPlayerIDs = sessionPlayerIDs.subtracting(presentIDs)
                    }
                    self.autoStartRematchIfReady()
                }
                try? await Task.sleep(for: .milliseconds(1500))
            }
        }
    }

    /// Host-side: if host has voted and every remaining connected non-host player
    /// is ready, automatically start the rematch so the host doesn't need to tap twice.
    private func autoStartRematchIfReady() {
        guard let session = activeSession, session.phase == .finished else { return }
        guard isCurrentUserHost, !isStartingRematch else { return }
        guard let pid = sessionPlayerID, session.rematchPlayerIDs.contains(pid) else { return }
        let opponents = session.players.filter { !$0.isHost }
        let remaining = opponents.filter { !sessionExitedPlayerIDs.contains($0.id) }
        guard !remaining.isEmpty else { return }
        let readySet = Set(session.rematchPlayerIDs)
        let allReady = remaining.allSatisfy { readySet.contains($0.id) }
        if allReady { startRematch() }
    }

    /// True when any opponent (non-self session player) has left the room entirely.
    var hasExitedOpponent: Bool {
        guard let session = activeSession, let me = sessionPlayerID else { return false }
        return session.players.contains { $0.id != me && sessionExitedPlayerIDs.contains($0.id) }
    }

    func stopCasualRematchPoll() {
        casualRematchPollTask?.cancel()
        casualRematchPollTask = nil
    }

    // MARK: - Rematch

    func voteForRematch() {
        guard let session = activeSession,
              let pid = sessionPlayerID,
              session.phase == .finished else { return }
        if session.rematchPlayerIDs.contains(pid) { return }
        let newIDs = session.rematchPlayerIDs + [pid]
        updateSession(copying: session, rematchPlayerIDs: newIDs)
        MultiplayerTelemetry.shared.log(event: "rematch_vote_submitted", source: "ui")
        // Authoritative per-player rematch readiness: write directly to backend
        // so the vote survives host backgrounding and host-independent reconnects.
        if let service = casualRoomService,
           let roomID = casualSessionRoomID,
           let token = casualSessionToken {
            Task {
                await service.setRematchReady(roomID: roomID, sessionToken: token, isReady: true)
                MultiplayerTelemetry.shared.log(event: "rematch_vote_persisted", source: "rpc", success: true)
            }
        }
        // Keep broadcast for fast UX feedback on peer screens.
        rebroadcastCurrentCasualSessionState(attempts: 6)
        startCasualRematchPollIfNeeded()
    }

    func startRematch() {
        guard !isStartingRematch else { return }
        guard let session = activeSession else { return }
        guard isCurrentUserHost else { return }
        guard session.mode == .multiDevice || session.mode == .teamMode else { return }
        isStartingRematch = true
        sessionExitedPlayerIDs = []
        MultiplayerTelemetry.shared.log(event: "rematch_started", source: "host", success: true)
        MultiplayerTelemetry.shared.markSessionStarted()
        // Clear backend rematch flags and reset authoritative turn counter for
        // the new cycle. Non-host peers will learn the new turn ownership the
        // next time they call claimTurnAdvance (server CAS rejects stale clients).
        if let service = casualRoomService,
           let roomID = casualSessionRoomID,
           let token = casualSessionToken {
            Task {
                await service.clearAllRematch(roomID: roomID, hostSessionToken: token)
                await service.resetTurnCounter(roomID: roomID, hostSessionToken: token)
            }
        }
        let freshPlayers = session.players.map { p in
            PlayerProfile(id: p.id, username: p.username, isHost: p.isHost, isReady: p.isReady, isOnline: p.isOnline, score: 0)
        }
        let localID = sessionOverridePlayerID ?? casualSessionOriginPlayerID
        startCasualMultiplayerSession(
            game: session.game,
            mode: session.mode,
            players: freshPlayers,
            roomCode: session.roomCode ?? "",
            localPlayerID: localID,
            sessionID: session.id,
            syncToPeers: true
        )
        // Explicitly clear any stale rematch flags on the new session payload.
        if let fresh = activeSession {
            updateSession(copying: fresh, rematchPlayerIDs: [])
        }
        rebroadcastCurrentCasualSessionState(attempts: 6)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { self?.isStartingRematch = false }
        }
    }

    var hasVotedRematch: Bool {
        guard let session = activeSession, let pid = sessionPlayerID else { return false }
        return session.rematchPlayerIDs.contains(pid)
    }

    func exitActiveSession() async {
        if let service = casualRoomService,
           let roomID = casualSessionRoomID,
           let playerID = casualSessionOriginPlayerID,
           let sessionToken = casualSessionToken,
           activeSession?.mode != .singleDevice {
            try? await service.leaveRoom(roomID: roomID, playerID: playerID, sessionToken: sessionToken)
            casualRoomCleanupHandler?()
        }

        dismissSession()
    }

    func applyRemoteCasualGameState(_ payload: CasualGameStatePayload) {
        if let origin = UUID(uuidString: payload.originPlayerId),
           let local = casualSessionOriginPlayerID,
           origin == local { return }
        let state = payload.state
        // Monotonic version guard: drop payloads that are older than what we've
        // already applied. Prevents a stale late broadcast from overwriting a
        // newer state (e.g. right after a turn change).
        if state.stateVersion > 0,
           state.stateVersion < lastAppliedRemoteVersion {
            return
        }
        let sessionID = UUID(uuidString: payload.sessionId) ?? activeSession?.id ?? UUID()
        isApplyingRemoteSessionState = true
        defer { isApplyingRemoteSessionState = false }
        let session = buildSession(fromState: state, sessionID: sessionID)
        activeSession = session
        lastAppliedRemoteVersion = max(lastAppliedRemoteVersion, state.stateVersion)
        currentStateVersion = max(currentStateVersion, state.stateVersion)

        // Kick off backend rematch polling once any device transitions to finished.
        if session.phase == .finished {
            startCasualRematchPollIfNeeded()
        }

        // Host persistence: if this device is the host and a non-host peer just
        // broadcast a rematch vote (or any merged state), write the updated
        // record back to DB so the vote survives host backgrounding.
        if isCurrentUserHost, let recordID = activeSessionRecordID, session.phase == .finished {
            Task { [weak self] in
                guard let self else { return }
                try? await self.databaseService.updateSessionState(sessionID: recordID, state: state, status: "active")
            }
        }
    }

    // MARK: - Multiplayer Start

    func startMultiplayerFromLobby() {
        guard let room = currentRoom else { return }
        guard isCurrentUserLobbyHost else {
            lobbyNotice = "Only the host can start."
            return
        }
        guard canPlayGame(room.game) else {
            lobbyNotice = "Subscribe to 8PartyPlay+ to host this premium game."
            return
        }
        guard room.players.count >= room.minPlayers else {
            lobbyNotice = "Need at least \(room.minPlayers) players."
            return
        }
        guard room.allPlayersReady else {
            lobbyNotice = "Everyone needs to be ready."
            return
        }
        startSession(game: room.game, mode: room.mode, players: room.players, roomCode: room.code)
    }

    // MARK: - Session Flow

    func advanceFromPassScreen() {
        guard let session = activeSession else { return }
        FeedbackService.shared.playRoundStart()
        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                phase: .liveRound, secondsRemaining: session.game.roundDuration,
                latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
                results: session.results, liveState: RoundLiveState()
            )
        )
        startTimer()
    }

    func completeRound(success: Bool) {
        guard let session = activeSession else { return }
        let points = success ? max(session.secondsRemaining, 5) : 0
        let feedback = success ? "Round complete with +\(points) points." : "No score this turn."
        if success { FeedbackService.shared.playSuccess() } else { FeedbackService.shared.playRoundEnd() }
        completeRound(points: points, feedback: feedback)
    }

    func continueAfterRound() {
        guard let session = activeSession else { return }
        let nextIndex = session.currentRoundIndex + 1
        if nextIndex >= session.rounds.count {
            finishSession()
            return
        }
        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: session.players, rounds: session.rounds, currentRoundIndex: nextIndex,
                phase: .passToNextPlayer, secondsRemaining: session.game.roundDuration,
                latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
                results: session.results, liveState: RoundLiveState()
            )
        )
    }

    func replaySession() {
        guard let session = activeSession else { return }
        if let passGuessState = session.passGuessState {
            currentPassGuessSettings = passGuessState.settings
        }
        startSession(
            game: session.game,
            mode: session.mode,
            players: session.players.map { PlayerProfile(id: $0.id, username: $0.username, isHost: $0.isHost, isReady: $0.isReady, isOnline: $0.isOnline) },
            roomCode: session.roomCode
        )
    }

    func dismissSession() {
        timerTask?.cancel()
        timerTask = nil
        stopCasualRebroadcastPump()
        stopCasualRematchPoll()
        activeSession = nil
        activeSessionRecordID = nil
        sessionOverridePlayerID = nil
        currentStateVersion = 0
        lastAppliedRemoteVersion = 0
        isStartingRematch = false
        sessionOnlinePlayerIDs = []
        sessionExitedPlayerIDs = []
        detachCasualRoomService()
        resilienceService.clearActiveSession()
    }

    func advancePassGuessIntro() {
        guard let session = activeSession,
              session.game.rawValue == GameType.passGuess.rawValue,
              let state = session.passGuessState,
              state.phase == .intro else { return }
        guard session.mode == .singleDevice || isCurrentUserHost else { return }
        let nextState = PassGuessRoundState(settings: state.settings, phase: .answering, question: state.question, archivedRounds: state.archivedRounds)
        let secondsRemaining = session.mode == .singleDevice ? 0 : state.settings.answerTimeLimit
        updateSession(
            GameSession(
                id: session.id,
                game: session.game,
                mode: session.mode,
                roomCode: session.roomCode,
                players: session.players,
                rounds: session.rounds,
                currentRoundIndex: session.currentRoundIndex,
                phase: .liveRound,
                secondsRemaining: secondsRemaining,
                latestAwardedPoints: 0,
                latestFeedback: "Write your answer privately.",
                results: session.results,
                liveState: session.liveState,
                passGuessState: nextState
            )
        )
        if session.mode != .singleDevice {
            startTimer()
        }
    }

    func submitPassGuessAnswer(_ text: String) {
        guard let currentPlayerID else { return }
        submitPassGuessAnswer(playerID: currentPlayerID, text: text)
    }

    func submitPassGuessAnswer(playerID: UUID, text: String) {
        guard let session = activeSession,
              session.game.rawValue == GameType.passGuess.rawValue,
              let state = session.passGuessState,
              state.phase == .answering else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Answer can't be empty."
            return
        }
        let capped = String(trimmed.prefix(120))
        var answers = state.answers.filter { $0.playerID != playerID }
        answers.append(PassGuessAnswer(playerID: playerID, text: capped))
        let updatedState = PassGuessRoundState(
            settings: state.settings,
            phase: .answering,
            question: state.question,
            answers: answers,
            votes: state.votes,
            revealItems: state.revealItems,
            archivedRounds: state.archivedRounds
        )
        updateSession(
            GameSession(
                id: session.id,
                game: session.game,
                mode: session.mode,
                roomCode: session.roomCode,
                players: session.players,
                rounds: session.rounds,
                currentRoundIndex: session.currentRoundIndex,
                phase: session.phase,
                secondsRemaining: session.secondsRemaining,
                latestAwardedPoints: session.latestAwardedPoints,
                latestFeedback: session.latestFeedback,
                results: session.results,
                liveState: session.liveState,
                passGuessState: updatedState
            )
        )
        if (session.mode == .singleDevice || isCurrentUserHost) && answers.count == session.players.count {
            advancePassGuessRoundIfPossible()
        }
    }

    func submitPassGuessVote(answerID: UUID, guessedPlayerID: UUID) {
        guard let currentPlayerID else { return }
        submitPassGuessVote(answerID: answerID, voterID: currentPlayerID, guessedPlayerID: guessedPlayerID)
    }

    func submitPassGuessVote(answerID: UUID, voterID: UUID, guessedPlayerID: UUID) {
        guard let session = activeSession,
              session.game.rawValue == GameType.passGuess.rawValue,
              let state = session.passGuessState,
              state.phase == .guessing else { return }
        guard !state.votes.contains(where: { $0.answerID == answerID && $0.voterID == voterID }) else { return }
        let updatedVotes = state.votes + [PassGuessVote(answerID: answerID, voterID: voterID, guessedPlayerID: guessedPlayerID)]
        let updatedState = PassGuessRoundState(
            settings: state.settings,
            phase: .guessing,
            question: state.question,
            answers: state.answers,
            votes: updatedVotes,
            revealItems: state.revealItems,
            archivedRounds: state.archivedRounds
        )
        updateSession(
            GameSession(
                id: session.id,
                game: session.game,
                mode: session.mode,
                roomCode: session.roomCode,
                players: session.players,
                rounds: session.rounds,
                currentRoundIndex: session.currentRoundIndex,
                phase: session.phase,
                secondsRemaining: session.secondsRemaining,
                latestAwardedPoints: session.latestAwardedPoints,
                latestFeedback: session.latestFeedback,
                results: session.results,
                liveState: session.liveState,
                passGuessState: updatedState
            )
        )
        let expectedVoteCount = state.answers.count * session.players.count
        if (session.mode == .singleDevice || isCurrentUserHost) && updatedVotes.count == expectedVoteCount {
            advancePassGuessRoundIfPossible()
        }
    }

    func advancePassGuessRoundIfPossible() {
        guard let session = activeSession,
              session.game.rawValue == GameType.passGuess.rawValue,
              let state = session.passGuessState else { return }
        guard session.mode == .singleDevice || isCurrentUserHost else { return }

        switch state.phase {
        case .intro:
            advancePassGuessIntro()
        case .answering:
            let orderedAnswers = state.answers.sorted { $0.id.uuidString < $1.id.uuidString }
            let nextState = PassGuessRoundState(
                settings: state.settings,
                phase: .guessing,
                question: state.question,
                answers: orderedAnswers,
                votes: [],
                revealItems: [],
                archivedRounds: state.archivedRounds
            )
            let secondsRemaining = session.mode == .singleDevice ? 0 : state.settings.guessTimeLimit
            updateSession(
                GameSession(
                    id: session.id,
                    game: session.game,
                    mode: session.mode,
                    roomCode: session.roomCode,
                    players: session.players,
                    rounds: session.rounds,
                    currentRoundIndex: session.currentRoundIndex,
                    phase: .liveRound,
                    secondsRemaining: secondsRemaining,
                    latestAwardedPoints: 0,
                    latestFeedback: "Guess who wrote each answer.",
                    results: session.results,
                    liveState: session.liveState,
                    passGuessState: nextState
                )
            )
            if session.mode != .singleDevice {
                startTimer()
            }
        case .guessing:
            finalizePassGuessRound(session: session)
        case .reveal:
            let leaderboardState = PassGuessRoundState(
                settings: state.settings,
                phase: .leaderboard,
                question: state.question,
                answers: state.answers,
                votes: state.votes,
                revealItems: state.revealItems,
                archivedRounds: state.archivedRounds
            )
            updateSession(
                GameSession(
                    id: session.id,
                    game: session.game,
                    mode: session.mode,
                    roomCode: session.roomCode,
                    players: session.players,
                    rounds: session.rounds,
                    currentRoundIndex: session.currentRoundIndex,
                    phase: .roundResult,
                    secondsRemaining: 0,
                    latestAwardedPoints: session.latestAwardedPoints,
                    latestFeedback: "Round complete.",
                    results: session.results,
                    liveState: session.liveState,
                    passGuessState: leaderboardState
                )
            )
        case .leaderboard:
            continuePassGuessMatch()
        }
    }

    func revealFirstTurn(for session: GameSession) {
        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                phase: .passToNextPlayer, secondsRemaining: session.game.roundDuration,
                latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
                results: session.results, liveState: RoundLiveState(), passGuessState: session.passGuessState
            )
        )
    }

    func updateLiveGuess(_ guess: String) {
        guard let session = activeSession else { return }
        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                phase: session.phase, secondsRemaining: session.secondsRemaining,
                latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
                results: session.results,
                liveState: RoundLiveState(guessText: guess, hasStartedTiming: session.liveState.hasStartedTiming, measuredElapsedTime: session.liveState.measuredElapsedTime, hasSubmittedTiming: session.liveState.hasSubmittedTiming, promptVisibleToPerformer: session.liveState.promptVisibleToPerformer)
            )
        )
    }

    func togglePromptReveal() {
        guard let session = activeSession else { return }
        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                phase: session.phase, secondsRemaining: session.secondsRemaining,
                latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
                results: session.results,
                liveState: RoundLiveState(guessText: session.liveState.guessText, hasStartedTiming: session.liveState.hasStartedTiming, measuredElapsedTime: session.liveState.measuredElapsedTime, hasSubmittedTiming: session.liveState.hasSubmittedTiming, promptVisibleToPerformer: !session.liveState.promptVisibleToPerformer)
            )
        )
    }

    // MARK: - Multi-Device Game Controls

    func submitGTSTurnResult(actualTime: Double) {
        guard let session = activeSession,
              let state = session.guessTheSecondsState,
              let pid = sessionPlayerID else { return }
        let playerCount = session.players.count
        guard playerCount > 0 else { return }
        let expectedIndex = state.activeTurnIndex
        Task { [weak self] in
            guard let self else { return }
            guard await self.authorizeCasualTurnAdvance(expectedIndex: expectedIndex) else { return }
            await MainActor.run { self._applyGTSTurnResult(actualTime: actualTime) }
        }
    }

    private func _applyGTSTurnResult(actualTime: Double) {
        guard let session = activeSession,
              let state = session.guessTheSecondsState,
              let pid = sessionPlayerID else { return }
        let playerCount = session.players.count
        guard playerCount > 0 else { return }
        let roundNumber = state.currentRoundNumber(playerCount: playerCount)
        let targetTime = state.roundTargets[roundNumber] ?? state.selectedTime
        let difference = ((abs(targetTime - actualTime) * 100).rounded()) / 100
        let actualRounded = ((actualTime * 100).rounded()) / 100
        let playerName = session.players.first(where: { $0.id == pid })?.username ?? "Player"
        let result = GTSTurnResult(playerID: pid, playerName: playerName, round: roundNumber, targetTime: targetTime, actualTime: actualRounded, difference: difference)
        let newResults = state.turnResults + [result]
        let newIndex = state.activeTurnIndex + 1
        let finished = newIndex >= state.totalTurns
        let newState = GuessTheSecondsGameState(activeTurnIndex: newIndex, roundTargets: state.roundTargets, turnResults: newResults, selectedTime: state.selectedTime, roundsPerPlayer: state.roundsPerPlayer, totalTurns: state.totalTurns)
        if finished {
            let scores = buildGTSFinalScores(session: session, state: newState)
            let updatedPlayers = session.players.map { p in
                PlayerProfile(id: p.id, username: p.username, isHost: p.isHost, isReady: p.isReady, isOnline: p.isOnline, score: scores[p.id] ?? 0)
            }
            updateSession(copying: session, phase: .finished, secondsRemaining: 0, players: updatedPlayers, guessTheSecondsState: newState)
        } else {
            updateSession(copying: session, guessTheSecondsState: newState)
        }
    }

    func setGTSTargetTime(_ time: Double, forRound round: Int) {
        guard let session = activeSession, let state = session.guessTheSecondsState else { return }
        guard state.roundTargets[round] == nil else { return }
        var targets = state.roundTargets
        targets[round] = time
        let newState = GuessTheSecondsGameState(activeTurnIndex: state.activeTurnIndex, roundTargets: targets, turnResults: state.turnResults, selectedTime: time, roundsPerPlayer: state.roundsPerPlayer, totalTurns: state.totalTurns)
        updateSession(copying: session, guessTheSecondsState: newState)
    }

    func updateGTSSelectedTime(_ time: Double) {
        guard let session = activeSession, let state = session.guessTheSecondsState else { return }
        let newState = GuessTheSecondsGameState(activeTurnIndex: state.activeTurnIndex, roundTargets: state.roundTargets, turnResults: state.turnResults, selectedTime: time, roundsPerPlayer: state.roundsPerPlayer, totalTurns: state.totalTurns)
        updateSession(copying: session, guessTheSecondsState: newState)
    }

    private func buildGTSFinalScores(session: GameSession, state: GuessTheSecondsGameState) -> [UUID: Int] {
        var scores: [UUID: Int] = [:]
        for player in session.players {
            let playerResults = state.turnResults.filter { $0.playerID == player.id }
            let totalDiff = playerResults.reduce(0.0) { $0 + $1.difference }
            scores[player.id] = max(0, Int(1000 - totalDiff * 100))
        }
        return scores
    }

    func submitMemoryGridResult(elapsedSeconds: Double, moveCount: Int) {
        guard let session = activeSession,
              let state = session.memoryGridState,
              let _ = sessionPlayerID else { return }
        let expectedIndex = state.currentPlayerIndex
        Task { [weak self] in
            guard let self else { return }
            guard await self.authorizeCasualTurnAdvance(expectedIndex: expectedIndex) else { return }
            await MainActor.run { self._applyMemoryGridResult(elapsedSeconds: elapsedSeconds, moveCount: moveCount) }
        }
    }

    private func _applyMemoryGridResult(elapsedSeconds: Double, moveCount: Int) {
        guard let session = activeSession,
              let state = session.memoryGridState,
              let pid = sessionPlayerID else { return }
        let playerName = session.players.first(where: { $0.id == pid })?.username ?? "Player"
        let result = MGPlayerResult(playerID: pid, playerName: playerName, elapsedSeconds: elapsedSeconds, moveCount: moveCount)
        let newResults = state.playerResults + [result]
        let nextIndex = state.currentPlayerIndex + 1
        let finished = nextIndex >= session.players.count
        let newState = MemoryGridGameState(gridSize: state.gridSize, currentPlayerIndex: nextIndex, playerResults: newResults, isFinished: finished, spectator: nil)
        if finished {
            let scores = buildMGFinalScores(session: session, state: newState)
            let updatedPlayers = session.players.map { p in
                PlayerProfile(id: p.id, username: p.username, isHost: p.isHost, isReady: p.isReady, isOnline: p.isOnline, score: scores[p.id] ?? 0)
            }
            updateSession(copying: session, phase: .finished, secondsRemaining: 0, players: updatedPlayers, memoryGridState: newState)
        } else {
            updateSession(copying: session, memoryGridState: newState)
        }
        rebroadcastCurrentCasualSessionState()
    }

    func broadcastMemoryGridSpectatorState(tiles: [MemoryTile], matchedPairs: Int, moveCount: Int, elapsedSeconds: Double) {
        guard let session = activeSession,
              let state = session.memoryGridState,
              let pid = sessionPlayerID else { return }
        guard state.currentPlayerIndex < session.players.count,
              session.players[state.currentPlayerIndex].id == pid else { return }
        let playerName = session.players.first(where: { $0.id == pid })?.username ?? "Player"
        let snap = MGSpectatorSnapshot(
            playerID: pid,
            playerName: playerName,
            tiles: tiles.map { MGSpectatorTile(pairId: $0.pairId, symbol: $0.symbol, colorIndex: $0.colorIndex, isFlipped: $0.isFlipped, isMatched: $0.isMatched) },
            matchedPairs: matchedPairs,
            moveCount: moveCount,
            elapsedSeconds: elapsedSeconds
        )
        let newState = MemoryGridGameState(gridSize: state.gridSize, currentPlayerIndex: state.currentPlayerIndex, playerResults: state.playerResults, isFinished: state.isFinished, spectator: snap)
        let newSession = GameSession(
            id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
            players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
            phase: session.phase, secondsRemaining: session.secondsRemaining,
            latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
            results: session.results, liveState: session.liveState,
            passGuessState: session.passGuessState,
            guessTheSecondsState: session.guessTheSecondsState, memoryGridState: newState,
            memoryPathState: session.memoryPathState, tapInOrderState: session.tapInOrderState,
            colorTrapState: session.colorTrapState
        )
        activeSession = newSession
        guard let service = casualRoomService, session.roomCode != nil else { return }
        let record = makeSessionStateRecord(from: newSession)
        let origin = casualSessionOriginPlayerID ?? pid
        let payload = CasualGameStatePayload(sessionId: session.id.uuidString, originPlayerId: origin.uuidString, state: record)
        Task { await service.broadcastGameState(payload) }
    }

    private func buildMGFinalScores(session: GameSession, state: MemoryGridGameState) -> [UUID: Int] {
        var scores: [UUID: Int] = [:]
        let sorted = state.playerResults.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        for (index, result) in sorted.enumerated() {
            scores[result.playerID] = max(0, 1000 - index * 100 - Int(result.elapsedSeconds * 10))
        }
        return scores
    }

    func submitMemoryPathResult(progress: Int, attempts: Int, completionTime: Double?, isFinished: Bool, score: Int) {
        guard let session = activeSession,
              let state = session.memoryPathState,
              let _ = sessionPlayerID else { return }
        let expectedIndex = state.currentPlayerIndex
        Task { [weak self] in
            guard let self else { return }
            guard await self.authorizeCasualTurnAdvance(expectedIndex: expectedIndex) else { return }
            await MainActor.run { self._applyMemoryPathResult(progress: progress, attempts: attempts, completionTime: completionTime, isFinished: isFinished, score: score) }
        }
    }

    private func _applyMemoryPathResult(progress: Int, attempts: Int, completionTime: Double?, isFinished: Bool, score: Int) {
        guard let session = activeSession,
              let state = session.memoryPathState,
              let pid = sessionPlayerID else { return }
        let playerName = session.players.first(where: { $0.id == pid })?.username ?? "Player"
        let result = MPPlayerResult(playerID: pid, playerName: playerName, progress: progress, attempts: attempts, completionTime: completionTime, isFinished: isFinished, score: score)
        let newResults = state.playerResults + [result]
        let nextIndex = state.currentPlayerIndex + 1
        let allDone = nextIndex >= session.players.count
        let newState = MemoryPathGameState(difficulty: state.difficulty, gameMode: state.gameMode, targetSteps: state.targetSteps, pathIndices: state.pathIndices, gridSize: state.gridSize, currentPlayerIndex: nextIndex, playerResults: newResults, isFinished: allDone)
        if allDone {
            let scores = buildMPFinalScores(session: session, state: newState)
            let updatedPlayers = session.players.map { p in
                PlayerProfile(id: p.id, username: p.username, isHost: p.isHost, isReady: p.isReady, isOnline: p.isOnline, score: scores[p.id] ?? 0)
            }
            updateSession(copying: session, phase: .finished, secondsRemaining: 0, players: updatedPlayers, memoryPathState: newState)
        } else {
            updateSession(copying: session, memoryPathState: newState)
        }
    }

    private func buildMPFinalScores(session: GameSession, state: MemoryPathGameState) -> [UUID: Int] {
        var scores: [UUID: Int] = [:]
        let sorted = state.playerResults.sorted { r1, r2 in
            if r1.isFinished && r2.isFinished { return (r1.completionTime ?? .infinity) < (r2.completionTime ?? .infinity) }
            if r1.isFinished { return true }
            if r2.isFinished { return false }
            return r1.progress > r2.progress
        }
        for (index, result) in sorted.enumerated() {
            scores[result.playerID] = result.score > 0 ? result.score : max(0, 1000 - index * 200)
        }
        return scores
    }

    func startMultiDeviceGameplay() {
        guard let session = activeSession else { return }
        guard session.mode != .singleDevice else { return }
        updateSession(copying: session, phase: .liveRound, secondsRemaining: 0, latestFeedback: "Game in progress")
    }

    func isCurrentPlayerTurn(in session: GameSession) -> Bool {
        guard let pid = sessionPlayerID else { return false }
        if let gts = session.guessTheSecondsState {
            let idx = gts.activeTurnIndex
            guard idx < session.players.count * gts.roundsPerPlayer else { return false }
            let playerIndex = idx % session.players.count
            guard playerIndex < session.players.count else { return false }
            return session.players[playerIndex].id == pid
        }
        if let mg = session.memoryGridState {
            guard mg.currentPlayerIndex < session.players.count else { return false }
            return session.players[mg.currentPlayerIndex].id == pid
        }
        if let mp = session.memoryPathState {
            guard mp.currentPlayerIndex < session.players.count else { return false }
            return session.players[mp.currentPlayerIndex].id == pid
        }
        if let tio = session.tapInOrderState {
            guard tio.currentPlayerIndex < session.players.count else { return false }
            return session.players[tio.currentPlayerIndex].id == pid
        }
        if let ct = session.colorTrapState {
            guard ct.currentPlayerIndex < session.players.count else { return false }
            return session.players[ct.currentPlayerIndex].id == pid
        }
        return false
    }

    func currentTurnPlayerName(in session: GameSession) -> String? {
        if let gts = session.guessTheSecondsState {
            let idx = gts.activeTurnIndex
            let playerIndex = idx % max(session.players.count, 1)
            guard playerIndex < session.players.count else { return nil }
            return session.players[playerIndex].username
        }
        if let mg = session.memoryGridState {
            guard mg.currentPlayerIndex < session.players.count else { return nil }
            return session.players[mg.currentPlayerIndex].username
        }
        if let mp = session.memoryPathState {
            guard mp.currentPlayerIndex < session.players.count else { return nil }
            return session.players[mp.currentPlayerIndex].username
        }
        if let tio = session.tapInOrderState {
            guard tio.currentPlayerIndex < session.players.count else { return nil }
            return session.players[tio.currentPlayerIndex].username
        }
        if let ct = session.colorTrapState {
            guard ct.currentPlayerIndex < session.players.count else { return nil }
            return session.players[ct.currentPlayerIndex].username
        }
        return nil
    }

    func submitTapInOrderResult(variant: String, elapsedSeconds: Double, correctCount: Int, totalTargets: Int, missTaps: Int, didFinish: Bool) {
        guard let session = activeSession,
              let state = session.tapInOrderState,
              let _ = sessionPlayerID else { return }
        let expectedIndex = state.currentPlayerIndex
        Task { [weak self] in
            guard let self else { return }
            guard await self.authorizeCasualTurnAdvance(expectedIndex: expectedIndex) else { return }
            await MainActor.run { self._applyTapInOrderResult(variant: variant, elapsedSeconds: elapsedSeconds, correctCount: correctCount, totalTargets: totalTargets, missTaps: missTaps, didFinish: didFinish) }
        }
    }

    private func _applyTapInOrderResult(variant: String, elapsedSeconds: Double, correctCount: Int, totalTargets: Int, missTaps: Int, didFinish: Bool) {
        guard let session = activeSession,
              let state = session.tapInOrderState,
              let pid = sessionPlayerID else { return }
        let playerName = session.players.first(where: { $0.id == pid })?.username ?? "Player"
        let result = TIOPlayerResult(playerID: pid, playerName: playerName, variant: variant, elapsedSeconds: elapsedSeconds, correctCount: correctCount, totalTargets: totalTargets, missTaps: missTaps, didFinish: didFinish)
        let newResults = state.playerResults + [result]
        let nextIndex = state.currentPlayerIndex + 1
        let finished = nextIndex >= session.players.count
        let newState = TapInOrderGameState(variant: state.variant, gridSize: state.gridSize, tileCount: state.tileCount, seed: state.seed, selectedCells: state.selectedCells, currentPlayerIndex: nextIndex, playerResults: newResults, isFinished: finished)
        if finished {
            let scores = buildTIOFinalScores(state: newState)
            let updatedPlayers = session.players.map { p in
                PlayerProfile(id: p.id, username: p.username, isHost: p.isHost, isReady: p.isReady, isOnline: p.isOnline, score: scores[p.id] ?? 0)
            }
            updateSession(copying: session, phase: .finished, secondsRemaining: 0, players: updatedPlayers, tapInOrderState: newState)
        } else {
            updateSession(copying: session, tapInOrderState: newState)
        }
    }

    private func buildTIOFinalScores(state: TapInOrderGameState) -> [UUID: Int] {
        var scores: [UUID: Int] = [:]
        let sorted = state.playerResults.sorted { lhs, rhs in
            if lhs.correctCount != rhs.correctCount { return lhs.correctCount > rhs.correctCount }
            if lhs.missTaps != rhs.missTaps { return lhs.missTaps < rhs.missTaps }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
        }
        for (index, result) in sorted.enumerated() {
            let base = max(0, result.correctCount * 100 - result.missTaps * 25 - Int(result.elapsedSeconds * 2) - index * 50)
            scores[result.playerID] = base
        }
        return scores
    }

    func submitColorTrapResult(hits: Int, fails: Int, survivalTime: Double, eliminated: Bool) {
        guard let session = activeSession,
              let state = session.colorTrapState,
              let _ = sessionPlayerID else { return }
        let expectedIndex = state.currentPlayerIndex
        Task { [weak self] in
            guard let self else { return }
            guard await self.authorizeCasualTurnAdvance(expectedIndex: expectedIndex) else { return }
            await MainActor.run { self._applyColorTrapResult(hits: hits, fails: fails, survivalTime: survivalTime, eliminated: eliminated) }
        }
    }

    private func _applyColorTrapResult(hits: Int, fails: Int, survivalTime: Double, eliminated: Bool) {
        guard let session = activeSession,
              let state = session.colorTrapState,
              let pid = sessionPlayerID else { return }
        let playerName = session.players.first(where: { $0.id == pid })?.username ?? "Player"
        let result = CTPlayerResult(playerID: pid, playerName: playerName, hits: hits, fails: fails, survivalTime: survivalTime, eliminated: eliminated)
        let newResults = state.playerResults + [result]
        let nextIndex = state.currentPlayerIndex + 1
        let finished = nextIndex >= session.players.count
        let newState = ColorTrapGameState(difficulty: state.difficulty, seed: state.seed, forbiddenColorIndex: state.forbiddenColorIndex, currentPlayerIndex: nextIndex, playerResults: newResults, isFinished: finished)
        if finished {
            let scores = buildCTFinalScores(state: newState)
            let updatedPlayers = session.players.map { p in
                PlayerProfile(id: p.id, username: p.username, isHost: p.isHost, isReady: p.isReady, isOnline: p.isOnline, score: scores[p.id] ?? 0)
            }
            updateSession(copying: session, phase: .finished, secondsRemaining: 0, players: updatedPlayers, colorTrapState: newState)
        } else {
            updateSession(copying: session, colorTrapState: newState)
        }
    }

    private func buildCTFinalScores(state: ColorTrapGameState) -> [UUID: Int] {
        var scores: [UUID: Int] = [:]
        for r in state.playerResults {
            scores[r.playerID] = max(0, r.score)
        }
        return scores
    }

    // MARK: - Profile & Settings

    func setLanguage(_ language: AppLanguage) {
        currentLanguageCode = language.rawValue
    }

    func saveProfileChanges(username: String, avatarSymbol: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            errorMessage = "Username can't be empty."
            return
        }
        if currentProvider == .guest || currentUserID == nil {
            self.username = trimmed
            self.avatarSymbol = avatarSymbol
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                let payload = ProfileUpdatePayload(username: trimmed, displayName: displayName, publicID: publicUserID, avatarURL: avatarSymbol)
                try await databaseService.updateProfile(payload: payload)
                self.username = trimmed
                self.avatarSymbol = avatarSymbol
                try await refreshDashboardData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func aiStarCost(isPremium: Bool) -> Int {
        isPremium ? 1 : 5
    }

    @discardableResult
    func spendStarsForAI(isPremium: Bool) -> Bool {
        let cost = aiStarCost(isPremium: isPremium)
        guard starWallet.balance >= cost else {
            economyFeedback = EconomyFeedback(title: "Not enough Stars", message: "You need \(cost) \u{2605} to generate a card.", style: .warning)
            return false
        }
        let newBalance = starWallet.balance - cost
        let tx = StarTransaction(amount: -cost, type: .adminAdjustment, description: "AI card", timestamp: Date())
        starWallet = StarWallet(balance: newBalance, transactions: [tx] + starWallet.transactions)
        return true
    }



    // MARK: - Private Implementation

    func completeOnboarding(playerName: String = "Player") {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Player" : trimmed
        UserDefaults.standard.set(name, forKey: "defaultPlayerName")
        displayName = name
        let meFriend = Friend(name: name, isOnline: false, status: "Me", kind: .offline)
        if let existingIndex = offlineFriends.firstIndex(where: { $0.status == "Me" }) {
            offlineFriends[existingIndex] = meFriend
        } else {
            offlineFriends.insert(meFriend, at: 0)
        }
    }

    private func restoreSession() async {
        guard let session = await authService.restoreSession() else {
            applyGuestState()
            isCheckingSession = false
            return
        }
        await handleAuthenticatedSession(session)
        isCheckingSession = false
    }

    private func handleAuthenticatedSession(_ session: Session) async {
        let fallbackUsername = session.user.email?.components(separatedBy: "@").first ?? "Player"
        let providerValue: String
        if case .string(let value) = session.user.appMetadata["provider"] {
            providerValue = value
        } else {
            providerValue = ""
        }
        let resolvedProvider: AuthProvider
        switch providerValue {
        case "google": resolvedProvider = .google
        case "apple": resolvedProvider = .apple
        default: resolvedProvider = .username
        }
        let account = AuthAccount(id: session.user.id, username: fallbackUsername, email: session.user.email, provider: resolvedProvider)
        try? await bootstrap(account: account)
    }

    private func bootstrap(account: AuthAccount) async throws {
        currentUserID = account.id
        username = account.username
        displayName = account.username
        email = account.email
        currentProvider = account.provider
        isAuthenticated = true
        try await databaseService.ensureBootstrap(for: account.id, username: account.username, email: account.email)
        if let profile = try await databaseService.fetchProfile(for: account.id) {
            currentProfileID = profile.id
            username = profile.username
            displayName = profile.displayName ?? profile.username
            email = profile.email ?? account.email
            publicUserID = profile.publicID
            avatarSymbol = profile.avatarURL ?? "person.crop.circle.fill"
        } else {
            currentProfileID = account.id
        }
        try await refreshDashboardData()
        realtimeService.subscribeToSocialUpdates(userID: account.id) { [weak self] in
            guard let self else { return }
            Task { try? await self.refreshDashboardData() }
        }
        realtimeService.trackPresence(userID: account.id) { [weak self] ids in
            guard let self else { return }
            self.onlineUserIDs = ids
        }
        if let token = DeviceTokenStore.shared.latestToken {
            saveDeviceToken(token)
        }
        if let pending = pendingInviteCode, !pending.isEmpty {
            pendingInviteCode = nil
            redeemInviteCode(pending)
        }
    }


    func refreshDashboardData() async throws {
        guard let currentUserID else { return }
        let snapshot = try await databaseService.fetchWallet(for: currentUserID)
        let balance = snapshot.wallet?.starsBalance ?? 100
        let transactions = snapshot.starTransactions.map { t in
            StarTransaction(
                id: t.id,
                amount: t.amount,
                type: StarTransactionType(rawValue: t.transactionType) ?? .adminAdjustment,
                description: t.reason,
                referenceID: t.referenceID,
                timestamp: t.createdAt
            )
        }
        starWallet = StarWallet(balance: balance, transactions: transactions)

        gameUnlocks = GameType.library.map { game in
            let status: GameUnlockStatus
            if game.isFreeForever || !game.isPremium {
                status = .free
            } else if subscription.hasPremiumAccess {
                status = .subscriberUnlocked
            } else {
                status = .trialUsed
            }
            return GameUnlockInfo(gameKey: game.rawValue, gameName: game.name, unlockCostStars: 0, isFreeForever: game.isFreeForever, hasFreeTrial: false, status: status)
        }

        if let subRecord = try await databaseService.fetchSubscription(for: currentUserID) {
            let tier = SubscriptionTier(rawValue: subRecord.tier)
            subscription = UserSubscription(
                tier: tier,
                isActive: subRecord.isActive,
                isLifetime: tier == .lifetime,
                expiresAt: subRecord.expiresAt,
                autoRenews: subRecord.autoRenews,
                lastStarGrantDate: subRecord.lastStarGrantDate
            )
        } else {
            subscription = .none
        }

        inviteCode = (try? await databaseService.fetchMyInviteCode()) ?? inviteCode
        let summary = (try? await databaseService.fetchInviteSummary()) ?? InviteSummaryRecord(totalInvites: 0, starsEarned: 0)
        inviteTotalCount = summary.totalInvites
        inviteStarsEarned = summary.starsEarned

        friends = try await databaseService.fetchFriends(for: currentUserID)
        requests = try await databaseService.fetchFriendRequests(for: currentUserID)
        roomInvites = try await databaseService.fetchRoomInvites(for: currentUserID)
        visibleRooms = try await databaseService.fetchVisibleRooms(for: currentUserID)
        if activities.isEmpty {
            activities = [
                ActivityItem(title: "Ready to play", subtitle: "Your account is synced.", systemImage: "checkmark.circle.fill")
            ]
        }
    }

    private func applyRoom(_ room: GameRoom, notice: String) {
        currentRoom = room
        quickRejoinRoom = room
        currentRoomAccess = room.access
        invitedOnlineFriendIDs = room.invitedFriendIDs
        lobbyNotice = notice
    }

    private func mapToGameRoom(_ room: GameRoom, mode: GameMode) -> GameRoom {
        GameRoom(
            id: room.id,
            code: room.code,
            game: room.game,
            mode: mode,
            hostName: room.hostName,
            players: room.players,
            message: room.message,
            access: room.access,
            invitedFriendIDs: room.invitedFriendIDs,
            status: .waiting
        )
    }

    private func observeRoom(code: String) {
        realtimeService.subscribeToRoom(
            code: code,
            onRoomUpdate: { [weak self] updatedCode in
                guard let self else { return }
                Task {
                    do {
                        let room = try await self.databaseService.fetchRoom(code: updatedCode)
                        let mode = self.currentRoom?.mode ?? .multiDevice
                        let gameRoom = self.mapToGameRoom(room, mode: mode)
                        self.applyRoom(gameRoom, notice: "Lobby synced.")
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
            },
            onSessionUpdate: { [weak self] record in
                guard let self else { return }
                self.applyRemoteSessionRecord(record)
            }
        )
    }

    private func startSession(game: GameType, mode: GameMode, players: [PlayerProfile], roomCode: String?, roundCount: Int? = nil, sessionID: UUID? = nil, syncToPeers: Bool = true) {
        let rounds = buildRounds(game: game, players: players, roundCount: roundCount)
        let sessionID = sessionID ?? UUID()
        let passGuessState: PassGuessRoundState?
        if game.rawValue == GameType.passGuess.rawValue {
            let settings = PassGuessSettings(
                rounds: roundCount ?? currentPassGuessSettings.rounds,
                questionMode: currentPassGuessSettings.questionMode,
                selectedQuestionID: currentPassGuessSettings.selectedQuestionID,
                customQuestion: currentPassGuessSettings.customQuestion,
                answerTimeLimit: currentPassGuessSettings.answerTimeLimit,
                guessTimeLimit: currentPassGuessSettings.guessTimeLimit
            )
            let question = resolvePassGuessQuestion(settings: settings)
            passGuessState = PassGuessRoundState(settings: settings, phase: .intro, question: question)
        } else {
            passGuessState = nil
        }

        let isMultiMode = mode == .multiDevice || mode == .teamMode
        var guessTheSecondsState: GuessTheSecondsGameState? = nil
        var memoryGridState: MemoryGridGameState? = nil
        var memoryPathState: MemoryPathGameState? = nil

        if game.rawValue == GameType.guessTheSeconds.rawValue && isMultiMode {
            let rpp = max(roundCount ?? 3, 1)
            guessTheSecondsState = GuessTheSecondsGameState(
                roundsPerPlayer: rpp,
                totalTurns: rpp * players.count
            )
        }
        if game.rawValue == GameType.memoryGrid.rawValue && isMultiMode {
            let gridSizeRaw = (currentMemoryGridSettings ?? .default).gridSize.rawValue
            memoryGridState = MemoryGridGameState(gridSize: gridSizeRaw)
        }
        if game.rawValue == GameType.memoryPath.rawValue && isMultiMode {
            let mpSettings = currentMemoryPathSettings ?? .default
            let size = mpSettings.difficulty.gridSize
            let pathResult = MemoryPathGenerator.generate(rows: size, cols: size)
            memoryPathState = MemoryPathGameState(
                difficulty: mpSettings.difficulty.rawValue,
                gameMode: mpSettings.gameMode.rawValue,
                targetSteps: mpSettings.targetSteps,
                pathIndices: pathResult.pathTiles,
                gridSize: size
            )
        }
        var tapInOrderState: TapInOrderGameState? = nil
        var colorTrapState: ColorTrapGameState? = nil
        if game.rawValue == GameType.tapInOrder.rawValue && isMultiMode {
            let tioSettings = currentTapInOrderSettings ?? .default
            let seed = UInt64.random(in: 1...UInt64.max)
            let cells = TapInOrderGenerator.generateSelectedCells(variant: tioSettings.variant, gridSize: tioSettings.gridSize, tileCount: tioSettings.tileCount, seed: seed)
            tapInOrderState = TapInOrderGameState(variant: tioSettings.variant.rawValue, gridSize: tioSettings.gridSize, tileCount: tioSettings.tileCount, seed: seed, selectedCells: cells)
        }
        if game.rawValue == GameType.colorTrap.rawValue && isMultiMode {
            let ctSettings = currentColorTrapSettings ?? .default
            let seed = UInt64.random(in: 1...UInt64.max)
            let forbidden = ColorTrapGenerator.pickForbiddenColor(seed: seed)
            colorTrapState = ColorTrapGameState(difficulty: ctSettings.difficulty.rawValue, seed: seed, forbiddenColorIndex: forbidden)
        }

        let session = GameSession(
            id: sessionID, game: game, mode: mode, roomCode: roomCode,
            players: players, rounds: rounds, currentRoundIndex: 0,
            phase: .intro, secondsRemaining: game.rawValue == GameType.passGuess.rawValue ? 0 : game.roundDuration,
            latestAwardedPoints: 0, latestFeedback: "",
            results: [], liveState: RoundLiveState(), passGuessState: passGuessState,
            guessTheSecondsState: guessTheSecondsState, memoryGridState: memoryGridState, memoryPathState: memoryPathState,
            tapInOrderState: tapInOrderState, colorTrapState: colorTrapState
        )

        if (mode == .multiDevice || mode == .teamMode), let currentRoom, let currentUserID {
            isBusy = true
            let sessionState = makeSessionStateRecord(from: session)
            Task {
                defer { self.isBusy = false }
                do {
                    let created = try await databaseService.createGameSession(sessionID: sessionID, roomID: currentRoom.id, game: game, mode: mode, userID: currentUserID, sessionState: sessionState)
                    self.activeSessionRecordID = created.id
                    self.updateSession(session, syncToPeers: syncToPeers)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        } else {
            activeSessionRecordID = nil
            updateSession(session, syncToPeers: syncToPeers)
        }
    }

    private func completeRound(points: Int, feedback: String) {
        timerTask?.cancel()
        guard let session = activeSession else { return }
        let currentRound = session.rounds[session.currentRoundIndex]
        let updatedPlayers = session.players.map { player in
            guard player.username == currentRound.activePlayerName else { return player }
            return PlayerProfile(id: player.id, username: player.username, isHost: player.isHost, isReady: player.isReady, isOnline: player.isOnline, score: player.score + points)
        }
        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: updatedPlayers, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                phase: .roundResult, secondsRemaining: 0,
                latestAwardedPoints: points, latestFeedback: feedback,
                results: session.results,
                liveState: RoundLiveState(guessText: session.liveState.guessText, hasStartedTiming: session.liveState.hasStartedTiming, measuredElapsedTime: session.liveState.measuredElapsedTime, hasSubmittedTiming: true, promptVisibleToPerformer: session.liveState.promptVisibleToPerformer)
            )
        )
    }

    private func finishSession() {
        timerTask?.cancel()
        resilienceService.clearActiveSession()
        guard let session = activeSession else { return }
        let resultBuilder = SharedResultBuilder()
        let scores = Dictionary(uniqueKeysWithValues: session.players.map { ($0.id, $0.score) })
        let results = resultBuilder.buildResults(
            players: session.players,
            scores: scores,
            mode: session.mode,
        )

        updateSession(
            GameSession(
                id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                phase: .finished, secondsRemaining: 0,
                latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
                results: results, liveState: session.liveState
            )
        )

        if session.mode == .multiDevice || session.mode == .teamMode {
            sessionOnlinePlayerIDs = Set(session.players.map(\.id))
            sessionExitedPlayerIDs = []
            startCasualRematchPollIfNeeded()
        }

        if let activeSessionRecordID {
            let resultRecords = session.players.sorted(by: { $0.score > $1.score }).enumerated().map { index, player in
                let rank = index + 1
                let policy = RewardPolicy.defaultPolicy
                let isWin = rank == 1
                let starsAwarded = isWin ? policy.starsForWin : policy.starsForParticipation
                return GameResultUpsertRecord(
                    sessionID: activeSessionRecordID, userID: player.id,
                    rank: rank, score: player.score,
                    starsAwarded: starsAwarded
                )
            }
            Task {
                do {
                    try await databaseService.persistResults(sessionID: activeSessionRecordID, results: resultRecords)
                    try await databaseService.finalizeGame(sessionID: activeSessionRecordID, idempotencyKey: UUID())
                    try await refreshDashboardData()
                } catch {
                    MultiplayerTelemetry.shared.log(event: "results_delivery_failure", source: "rpc", success: false, failure_reason: String(describing: error))
                    errorMessage = error.localizedDescription
                }
            }
        }

        grantStarsAfterMatch(game: session.game, isWin: results.first?.name == username, mode: session.mode)
        MultiplayerTelemetry.shared.log(event: "results_screen_shown", source: "session", success: true, props: ["player_count": "\(session.players.count)"])
    }

    private func grantStarsAfterMatch(game: GameType, isWin: Bool, mode: GameMode) {
        // Stars are earned only from daily rewards, sign-up bonus, invites, and subscription.
    }

    private func startTimer() {
        if let session = activeSession,
           session.mode != .singleDevice,
           !isCurrentUserHost {
            return
        }
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let session = activeSession, session.phase == .liveRound else { return }
                let updatedSeconds = max(session.secondsRemaining - 1, 0)
                let updatedElapsed = session.liveState.hasStartedTiming && !session.liveState.hasSubmittedTiming ? session.liveState.measuredElapsedTime + 1 : session.liveState.measuredElapsedTime
                if updatedSeconds == 0, let passGuessState = session.passGuessState, session.game.rawValue == GameType.passGuess.rawValue {
                    switch passGuessState.phase {
                    case .answering, .guessing:
                        advancePassGuessRoundIfPossible()
                    case .intro, .reveal, .leaderboard:
                        break
                    }
                    return
                }
                updateSession(
                    GameSession(
                        id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
                        players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
                        phase: updatedSeconds == 0 ? .roundResult : .liveRound,
                        secondsRemaining: updatedSeconds,
                        latestAwardedPoints: updatedSeconds == 0 ? 0 : session.latestAwardedPoints,
                        latestFeedback: updatedSeconds == 0 ? "Time ran out." : session.latestFeedback,
                        results: session.results,
                        liveState: RoundLiveState(guessText: session.liveState.guessText, hasStartedTiming: session.liveState.hasStartedTiming, measuredElapsedTime: updatedElapsed, hasSubmittedTiming: session.liveState.hasSubmittedTiming, promptVisibleToPerformer: session.liveState.promptVisibleToPerformer)
                    )
                )
                if updatedSeconds == 0 { return }
            }
        }
    }

    private func buildRounds(game: GameType, players: [PlayerProfile], roundCount: Int? = nil) -> [GameRound] {
        let safePlayers = players.isEmpty ? [PlayerProfile(username: username, isHost: true, isReady: true)] : players
        let resolvedRoundCount = max(roundCount ?? 3, 1)
        var generatedRounds: [GameRound] = []

        if game.rawValue == GameType.passGuess.rawValue {
            for roundIndex in 0..<resolvedRoundCount {
                generatedRounds.append(
                    GameRound(
                        index: roundIndex + 1,
                        prompt: "Pass & Guess",
                        activePlayerName: safePlayers.first?.username ?? username
                    )
                )
            }
            return generatedRounds
        }

        for roundIndex in 0..<resolvedRoundCount {
            for player in safePlayers {
                generatedRounds.append(
                    GameRound(
                        index: generatedRounds.count + 1,
                        prompt: "\(game.name) round \(roundIndex + 1)",
                        activePlayerName: player.username
                    )
                )
            }
        }

        return generatedRounds
    }

    private func updateSession(copying session: GameSession, phase: MatchPhase? = nil, secondsRemaining: Int? = nil, latestAwardedPoints: Int? = nil, latestFeedback: String? = nil, players: [PlayerProfile]? = nil, results: [GameResultRow]? = nil, passGuessState: PassGuessRoundState? = nil, guessTheSecondsState: GuessTheSecondsGameState? = nil, memoryGridState: MemoryGridGameState? = nil, memoryPathState: MemoryPathGameState? = nil, tapInOrderState: TapInOrderGameState? = nil, colorTrapState: ColorTrapGameState? = nil, rematchPlayerIDs: [UUID]? = nil) {
        updateSession(
            GameSession(
                id: session.id,
                game: session.game,
                mode: session.mode,
                roomCode: session.roomCode,
                players: players ?? session.players,
                rounds: session.rounds,
                currentRoundIndex: session.currentRoundIndex,
                phase: phase ?? session.phase,
                secondsRemaining: secondsRemaining ?? session.secondsRemaining,
                latestAwardedPoints: latestAwardedPoints ?? session.latestAwardedPoints,
                latestFeedback: latestFeedback ?? session.latestFeedback,
                results: results ?? session.results,
                liveState: session.liveState,
                passGuessState: passGuessState ?? session.passGuessState,
                guessTheSecondsState: guessTheSecondsState ?? session.guessTheSecondsState,
                memoryGridState: memoryGridState ?? session.memoryGridState,
                memoryPathState: memoryPathState ?? session.memoryPathState,
                tapInOrderState: tapInOrderState ?? session.tapInOrderState,
                colorTrapState: colorTrapState ?? session.colorTrapState,
                rematchPlayerIDs: rematchPlayerIDs ?? session.rematchPlayerIDs
            )
        )
    }

    private func resolvePassGuessQuestion(settings: PassGuessSettings) -> PassGuessQuestion {
        if settings.questionMode == .custom {
            let trimmed = settings.customQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = passGuessQuestionBank.first?.text ?? "What's something only your friends would know about you?"
            return PassGuessQuestion(text: trimmed.isEmpty ? fallback : trimmed, type: .custom)
        }

        if let selectedQuestionID = settings.selectedQuestionID,
           let selectedQuestion = passGuessQuestionBank.first(where: { $0.id == selectedQuestionID }) {
            return selectedQuestion
        }

        return passGuessQuestionBank.first ?? PassGuessQuestion(text: "What's something only your friends would know about you?", type: .predefined)
    }

    private var passGuessQuestionBank: [PassGuessQuestion] {
        [
            PassGuessQuestion(text: "What is your most irrational fear?", type: .predefined),
            PassGuessQuestion(text: "What is the weirdest snack combo you would actually eat?", type: .predefined),
            PassGuessQuestion(text: "What would be your secret superpower in real life?", type: .predefined),
            PassGuessQuestion(text: "What is the most embarrassing song you know all the words to?", type: .predefined),
            PassGuessQuestion(text: "If you had to get a useless tattoo right now, what would it be?", type: .predefined),
            PassGuessQuestion(text: "What is one lie you would be terrible at keeping?", type: .predefined),
            PassGuessQuestion(text: "What is your fake luxury brand name?", type: .predefined),
            PassGuessQuestion(text: "What would your wrestling entrance name be?", type: .predefined),
            PassGuessQuestion(text: "What would you rename Monday to?", type: .predefined),
            PassGuessQuestion(text: "What is the pettiest reason you'd cancel plans?", type: .predefined),
            PassGuessQuestion(text: "What is your villain origin story?", type: .predefined),
            PassGuessQuestion(text: "If your laugh had a flavor, what would it be?", type: .predefined),
            PassGuessQuestion(text: "What is a fake excuse for being late that sounds real?", type: .predefined),
            PassGuessQuestion(text: "What would your autobiography be called?", type: .predefined),
            PassGuessQuestion(text: "What is the dumbest thing you'd fight a goose over?", type: .predefined),
            PassGuessQuestion(text: "What is your cursed startup idea?", type: .predefined),
            PassGuessQuestion(text: "What is your signature move in a pillow fight?", type: .predefined),
            PassGuessQuestion(text: "What is the most suspicious thing in your fridge right now?", type: .predefined),
            PassGuessQuestion(text: "If aliens landed today, what job would you pretend to have?", type: .predefined),
            PassGuessQuestion(text: "What is your most chaotic road trip role?", type: .predefined),
            PassGuessQuestion(text: "What tiny thing makes you feel powerful?", type: .predefined),
            PassGuessQuestion(text: "What would your signature perfume or cologne be named?", type: .predefined)
        ]
    }

    private func finalizePassGuessRound(session: GameSession) {
        guard let state = session.passGuessState else { return }

        let playerNames = Dictionary(uniqueKeysWithValues: session.players.map { ($0.id, $0.username) })
        let answerByID = Dictionary(uniqueKeysWithValues: state.answers.map { ($0.id, $0) })
        var scoreDeltaByPlayerID: [UUID: Int] = [:]

        for vote in state.votes {
            guard let answer = answerByID[vote.answerID] else { continue }
            if vote.guessedPlayerID == answer.playerID {
                scoreDeltaByPlayerID[vote.voterID, default: 0] += 2
            }
        }

        for answer in state.answers {
            let correctGuessCount = state.votes.filter { $0.answerID == answer.id && $0.guessedPlayerID == answer.playerID }.count
            if correctGuessCount == 0 {
                scoreDeltaByPlayerID[answer.playerID, default: 0] += 3
            }
        }

        let updatedPlayers = session.players.map { player in
            PlayerProfile(
                id: player.id,
                username: player.username,
                isHost: player.isHost,
                isReady: player.isReady,
                isOnline: player.isOnline,
                score: player.score + (scoreDeltaByPlayerID[player.id] ?? 0)
            )
        }

        let revealItems = state.answers.map { answer in
            let correctGuessCount = state.votes.filter { $0.answerID == answer.id && $0.guessedPlayerID == answer.playerID }.count
            return PassGuessRevealItem(
                answerID: answer.id,
                answerText: answer.text,
                playerID: answer.playerID,
                playerName: playerNames[answer.playerID] ?? "Player",
                correctGuessCount: correctGuessCount
            )
        }

        let archiveItem = PassGuessArchivedRound(
            roundNumber: session.currentRoundIndex + 1,
            question: state.question,
            answers: state.answers,
            votes: state.votes,
            revealItems: revealItems
        )

        let revealState = PassGuessRoundState(
            settings: state.settings,
            phase: .reveal,
            question: state.question,
            answers: state.answers,
            votes: state.votes,
            revealItems: revealItems,
            archivedRounds: state.archivedRounds + [archiveItem]
        )

        let awardedPoints = scoreDeltaByPlayerID.values.reduce(0, +)
        updateSession(
            GameSession(
                id: session.id,
                game: session.game,
                mode: session.mode,
                roomCode: session.roomCode,
                players: updatedPlayers,
                rounds: session.rounds,
                currentRoundIndex: session.currentRoundIndex,
                phase: .roundResult,
                secondsRemaining: 0,
                latestAwardedPoints: awardedPoints,
                latestFeedback: "Reveal ready.",
                results: session.results,
                liveState: session.liveState,
                passGuessState: revealState
            )
        )
    }

    private func continuePassGuessMatch() {
        guard let session = activeSession, let state = session.passGuessState else { return }
        let nextIndex = session.currentRoundIndex + 1
        if nextIndex >= state.settings.rounds {
            finishSession()
            return
        }

        let nextState = PassGuessRoundState(
            settings: state.settings,
            phase: .intro,
            question: resolvePassGuessQuestion(settings: state.settings),
            archivedRounds: state.archivedRounds
        )

        updateSession(
            GameSession(
                id: session.id,
                game: session.game,
                mode: session.mode,
                roomCode: session.roomCode,
                players: session.players,
                rounds: session.rounds,
                currentRoundIndex: nextIndex,
                phase: .intro,
                secondsRemaining: 0,
                latestAwardedPoints: 0,
                latestFeedback: "",
                results: session.results,
                liveState: session.liveState,
                passGuessState: nextState
            )
        )
    }

    private func updateSession(_ session: GameSession, syncToPeers: Bool = true) {
        // Increment monotonic version for every local mutation that will be broadcast.
        if !isApplyingRemoteSessionState,
           (session.mode == .multiDevice || session.mode == .teamMode) {
            currentStateVersion += 1
        }
        let versioned = GameSession(
            id: session.id, game: session.game, mode: session.mode, roomCode: session.roomCode,
            players: session.players, rounds: session.rounds, currentRoundIndex: session.currentRoundIndex,
            phase: session.phase, secondsRemaining: session.secondsRemaining,
            latestAwardedPoints: session.latestAwardedPoints, latestFeedback: session.latestFeedback,
            results: session.results, liveState: session.liveState,
            passGuessState: session.passGuessState,
            guessTheSecondsState: session.guessTheSecondsState, memoryGridState: session.memoryGridState,
            memoryPathState: session.memoryPathState, tapInOrderState: session.tapInOrderState,
            colorTrapState: session.colorTrapState, rematchPlayerIDs: session.rematchPlayerIDs,
            stateVersion: currentStateVersion
        )
        activeSession = versioned
        guard !isApplyingRemoteSessionState else { return }
        guard versioned.mode == .multiDevice || versioned.mode == .teamMode else { return }
        let state = makeSessionStateRecord(from: versioned)

        if syncToPeers, let service = casualRoomService, versioned.roomCode != nil {
            let origin = casualSessionOriginPlayerID ?? sessionPlayerID ?? UUID()
            let payload = CasualGameStatePayload(sessionId: versioned.id.uuidString, originPlayerId: origin.uuidString, state: state)
            Task { await service.broadcastGameState(payload) }
        }

        guard let activeSessionRecordID else { return }
        if session.phase != .finished {
            resilienceService.storeActiveSession(sessionID: activeSessionRecordID, roomCode: session.roomCode)
        } else {
            resilienceService.clearActiveSession()
        }
        let status = session.phase == .finished ? "finalized" : "active"
        Task {
            do {
                try await databaseService.updateSessionState(sessionID: activeSessionRecordID, state: state, status: status)
            } catch {
                syncErrorMessage = "Failed to sync game state."
            }
        }
    }

    private func makeSessionStateRecord(from session: GameSession) -> SessionStateRecord {
        SessionStateRecord(
            gameKey: session.game.rawValue,
            mode: session.mode.rawValue,
            roomCode: session.roomCode,
            players: session.players.map { SessionStatePlayerRecord(id: $0.id, username: $0.username, isHost: $0.isHost, isReady: $0.isReady, isOnline: $0.isOnline, score: $0.score) },
            rounds: session.rounds.map { SessionStateRoundRecord(id: $0.id, index: $0.index, prompt: $0.prompt, activePlayerName: $0.activePlayerName, targetAnswer: $0.targetAnswer, forbiddenWords: $0.forbiddenWords, targetSeconds: $0.targetSeconds) },
            currentRoundIndex: session.currentRoundIndex,
            phase: session.phase.realtimeValue,
            secondsRemaining: session.secondsRemaining,
            latestAwardedPoints: session.latestAwardedPoints,
            latestFeedback: session.latestFeedback,
            results: session.results.map { SessionStateResultRecord(id: $0.id, name: $0.name, score: $0.score, rank: $0.rank, starsWon: $0.starsWon) },
            liveState: SessionStateLiveStateRecord(guessText: session.liveState.guessText, hasStartedTiming: session.liveState.hasStartedTiming, measuredElapsedTime: session.liveState.measuredElapsedTime, hasSubmittedTiming: session.liveState.hasSubmittedTiming, promptVisibleToPerformer: session.liveState.promptVisibleToPerformer),
            passGuessState: session.passGuessState.map { state in
                SessionStatePassGuessRoundStateRecord(
                    settings: SessionStatePassGuessSettingsRecord(rounds: state.settings.rounds, questionMode: state.settings.questionMode.rawValue, selectedQuestionID: state.settings.selectedQuestionID, customQuestion: state.settings.customQuestion, answerTimeLimit: state.settings.answerTimeLimit, guessTimeLimit: state.settings.guessTimeLimit),
                    phase: state.phase.rawValue,
                    question: SessionStatePassGuessQuestionRecord(id: state.question.id, text: state.question.text, type: state.question.type.rawValue),
                    answers: state.answers.map { SessionStatePassGuessAnswerRecord(id: $0.id, playerID: $0.playerID, text: $0.text) },
                    votes: state.votes.map { SessionStatePassGuessVoteRecord(id: $0.id, answerID: $0.answerID, voterID: $0.voterID, guessedPlayerID: $0.guessedPlayerID) },
                    revealItems: state.revealItems.map { SessionStatePassGuessRevealItemRecord(id: $0.id, answerID: $0.answerID, answerText: $0.answerText, playerID: $0.playerID, playerName: $0.playerName, correctGuessCount: $0.correctGuessCount) },
                    archivedRounds: state.archivedRounds.map { archivedRound in
                        SessionStatePassGuessArchivedRoundRecord(
                            id: archivedRound.id,
                            roundNumber: archivedRound.roundNumber,
                            question: SessionStatePassGuessQuestionRecord(id: archivedRound.question.id, text: archivedRound.question.text, type: archivedRound.question.type.rawValue),
                            answers: archivedRound.answers.map { SessionStatePassGuessAnswerRecord(id: $0.id, playerID: $0.playerID, text: $0.text) },
                            votes: archivedRound.votes.map { SessionStatePassGuessVoteRecord(id: $0.id, answerID: $0.answerID, voterID: $0.voterID, guessedPlayerID: $0.guessedPlayerID) },
                            revealItems: archivedRound.revealItems.map { SessionStatePassGuessRevealItemRecord(id: $0.id, answerID: $0.answerID, answerText: $0.answerText, playerID: $0.playerID, playerName: $0.playerName, correctGuessCount: $0.correctGuessCount) }
                        )
                    }
                )
            },
            guessTheSecondsState: session.guessTheSecondsState.map { gts in
                SessionStateGuessTheSecondsRecord(
                    activeTurnIndex: gts.activeTurnIndex,
                    roundTargets: gts.roundTargets.map { SessionStateGTSRoundTargetRecord(round: $0.key, target: $0.value) },
                    turnResults: gts.turnResults.map { SessionStateGTSTurnResultRecord(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, round: $0.round, targetTime: $0.targetTime, actualTime: $0.actualTime, difference: $0.difference) },
                    selectedTime: gts.selectedTime,
                    roundsPerPlayer: gts.roundsPerPlayer,
                    totalTurns: gts.totalTurns
                )
            },
            memoryGridState: session.memoryGridState.map { mg in
                SessionStateMemoryGridRecord(
                    gridSize: mg.gridSize,
                    currentPlayerIndex: mg.currentPlayerIndex,
                    playerResults: mg.playerResults.map { SessionStateMGPlayerResultRecord(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, elapsedSeconds: $0.elapsedSeconds, moveCount: $0.moveCount) },
                    isFinished: mg.isFinished,
                    spectator: mg.spectator.map { snap in
                        SessionStateMGSpectatorRecord(
                            playerID: snap.playerID,
                            playerName: snap.playerName,
                            tiles: snap.tiles.map { SessionStateMGSpectatorTileRecord(pairId: $0.pairId, symbol: $0.symbol, colorIndex: $0.colorIndex, isFlipped: $0.isFlipped, isMatched: $0.isMatched) },
                            matchedPairs: snap.matchedPairs,
                            moveCount: snap.moveCount,
                            elapsedSeconds: snap.elapsedSeconds
                        )
                    }
                )
            },
            memoryPathState: session.memoryPathState.map { mp in
                SessionStateMemoryPathRecord(
                    difficulty: mp.difficulty,
                    gameMode: mp.gameMode,
                    targetSteps: mp.targetSteps,
                    pathIndices: mp.pathIndices,
                    gridSize: mp.gridSize,
                    currentPlayerIndex: mp.currentPlayerIndex,
                    playerResults: mp.playerResults.map { SessionStateMPPlayerResultRecord(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, progress: $0.progress, attempts: $0.attempts, completionTime: $0.completionTime, isFinished: $0.isFinished, score: $0.score) },
                    isFinished: mp.isFinished
                )
            },
            tapInOrderState: session.tapInOrderState.map { tio in
                SessionStateTapInOrderRecord(
                    variant: tio.variant,
                    gridSize: tio.gridSize,
                    tileCount: tio.tileCount,
                    seed: String(tio.seed),
                    selectedCells: tio.selectedCells,
                    currentPlayerIndex: tio.currentPlayerIndex,
                    playerResults: tio.playerResults.map { SessionStateTIOResultRecord(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, variant: $0.variant, elapsedSeconds: $0.elapsedSeconds, correctCount: $0.correctCount, totalTargets: $0.totalTargets, missTaps: $0.missTaps, didFinish: $0.didFinish) },
                    isFinished: tio.isFinished
                )
            },
            colorTrapState: session.colorTrapState.map { ct in
                SessionStateColorTrapRecord(
                    difficulty: ct.difficulty,
                    seed: String(ct.seed),
                    forbiddenColorIndex: ct.forbiddenColorIndex,
                    currentPlayerIndex: ct.currentPlayerIndex,
                    playerResults: ct.playerResults.map { SessionStateCTResultRecord(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, hits: $0.hits, fails: $0.fails, survivalTime: $0.survivalTime, eliminated: $0.eliminated) },
                    isFinished: ct.isFinished
                )
            },
            rematchPlayerIDs: session.rematchPlayerIDs.map { $0.uuidString },
            stateVersion: session.stateVersion
        )
    }

    private func applyRemoteSessionRecord(_ record: GameSessionRecord) {
        guard let state = record.sessionState else { return }
        let session = buildSession(fromState: state, sessionID: record.id)
        isApplyingRemoteSessionState = true
        defer { isApplyingRemoteSessionState = false }
        activeSessionRecordID = record.id
        updateSession(session)
    }

    private func buildSession(fromState state: SessionStateRecord, sessionID: UUID) -> GameSession {
        let game = GameType(rawValue: state.gameKey)
        let modeString = state.mode
        let mode: GameMode
        switch modeString {
        case "singleDevice": mode = .singleDevice
        case "multiDevice": mode = .multiDevice
        case "teamMode": mode = .teamMode
        default: mode = .multiDevice
        }
        return GameSession(
            id: sessionID, game: game, mode: mode, roomCode: state.roomCode,
            players: state.players.map { PlayerProfile(id: $0.id, username: $0.username, isHost: $0.isHost, isReady: $0.isReady, isOnline: $0.isOnline, score: $0.score) },
            rounds: state.rounds.map { GameRound(id: $0.id, index: $0.index, prompt: $0.prompt, activePlayerName: $0.activePlayerName, targetAnswer: $0.targetAnswer, forbiddenWords: $0.forbiddenWords, targetSeconds: $0.targetSeconds) },
            currentRoundIndex: state.currentRoundIndex,
            phase: MatchPhase(realtimeValue: state.phase) ?? .intro,
            secondsRemaining: state.secondsRemaining,
            latestAwardedPoints: state.latestAwardedPoints,
            latestFeedback: state.latestFeedback,
            results: state.results.map { GameResultRow(id: $0.id, name: $0.name, score: $0.score, rank: $0.rank, starsWon: $0.starsWon) },
            liveState: RoundLiveState(guessText: state.liveState.guessText, hasStartedTiming: state.liveState.hasStartedTiming, measuredElapsedTime: state.liveState.measuredElapsedTime, hasSubmittedTiming: state.liveState.hasSubmittedTiming, promptVisibleToPerformer: state.liveState.promptVisibleToPerformer),
            passGuessState: state.passGuessState.map { passGuessState in
                PassGuessRoundState(
                    settings: PassGuessSettings(rounds: passGuessState.settings.rounds, questionMode: PassGuessQuestionMode(rawValue: passGuessState.settings.questionMode) ?? .predefined, selectedQuestionID: passGuessState.settings.selectedQuestionID, customQuestion: passGuessState.settings.customQuestion, answerTimeLimit: passGuessState.settings.answerTimeLimit, guessTimeLimit: passGuessState.settings.guessTimeLimit),
                    phase: PassGuessRoundPhase(rawValue: passGuessState.phase) ?? .intro,
                    question: PassGuessQuestion(id: passGuessState.question.id, text: passGuessState.question.text, type: PassGuessQuestionMode(rawValue: passGuessState.question.type) ?? .predefined),
                    answers: passGuessState.answers.map { PassGuessAnswer(id: $0.id, playerID: $0.playerID, text: $0.text) },
                    votes: passGuessState.votes.map { PassGuessVote(id: $0.id, answerID: $0.answerID, voterID: $0.voterID, guessedPlayerID: $0.guessedPlayerID) },
                    revealItems: passGuessState.revealItems.map { PassGuessRevealItem(id: $0.id, answerID: $0.answerID, answerText: $0.answerText, playerID: $0.playerID, playerName: $0.playerName, correctGuessCount: $0.correctGuessCount) },
                    archivedRounds: passGuessState.archivedRounds.map { archivedRound in
                        PassGuessArchivedRound(
                            id: archivedRound.id,
                            roundNumber: archivedRound.roundNumber,
                            question: PassGuessQuestion(id: archivedRound.question.id, text: archivedRound.question.text, type: PassGuessQuestionMode(rawValue: archivedRound.question.type) ?? .predefined),
                            answers: archivedRound.answers.map { PassGuessAnswer(id: $0.id, playerID: $0.playerID, text: $0.text) },
                            votes: archivedRound.votes.map { PassGuessVote(id: $0.id, answerID: $0.answerID, voterID: $0.voterID, guessedPlayerID: $0.guessedPlayerID) },
                            revealItems: archivedRound.revealItems.map { PassGuessRevealItem(id: $0.id, answerID: $0.answerID, answerText: $0.answerText, playerID: $0.playerID, playerName: $0.playerName, correctGuessCount: $0.correctGuessCount) }
                        )
                    }
                )
            },
            guessTheSecondsState: state.guessTheSecondsState.map { gts in
                let targets = Dictionary(uniqueKeysWithValues: gts.roundTargets.map { ($0.round, $0.target) })
                return GuessTheSecondsGameState(
                    activeTurnIndex: gts.activeTurnIndex,
                    roundTargets: targets,
                    turnResults: gts.turnResults.map { GTSTurnResult(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, round: $0.round, targetTime: $0.targetTime, actualTime: $0.actualTime, difference: $0.difference) },
                    selectedTime: gts.selectedTime,
                    roundsPerPlayer: gts.roundsPerPlayer,
                    totalTurns: gts.totalTurns
                )
            },
            memoryGridState: state.memoryGridState.map { mg in
                MemoryGridGameState(
                    gridSize: mg.gridSize,
                    currentPlayerIndex: mg.currentPlayerIndex,
                    playerResults: mg.playerResults.map { MGPlayerResult(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, elapsedSeconds: $0.elapsedSeconds, moveCount: $0.moveCount) },
                    isFinished: mg.isFinished,
                    spectator: mg.spectator.map { snap in
                        MGSpectatorSnapshot(
                            playerID: snap.playerID,
                            playerName: snap.playerName,
                            tiles: snap.tiles.map { MGSpectatorTile(pairId: $0.pairId, symbol: $0.symbol, colorIndex: $0.colorIndex, isFlipped: $0.isFlipped, isMatched: $0.isMatched) },
                            matchedPairs: snap.matchedPairs,
                            moveCount: snap.moveCount,
                            elapsedSeconds: snap.elapsedSeconds
                        )
                    }
                )
            },
            memoryPathState: state.memoryPathState.map { mp in
                MemoryPathGameState(
                    difficulty: mp.difficulty,
                    gameMode: mp.gameMode,
                    targetSteps: mp.targetSteps,
                    pathIndices: mp.pathIndices,
                    gridSize: mp.gridSize,
                    currentPlayerIndex: mp.currentPlayerIndex,
                    playerResults: mp.playerResults.map { MPPlayerResult(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, progress: $0.progress, attempts: $0.attempts, completionTime: $0.completionTime, isFinished: $0.isFinished, score: $0.score) },
                    isFinished: mp.isFinished
                )
            },
            tapInOrderState: state.tapInOrderState.map { tio in
                TapInOrderGameState(
                    variant: tio.variant,
                    gridSize: tio.gridSize,
                    tileCount: tio.tileCount,
                    seed: UInt64(tio.seed) ?? 0,
                    selectedCells: tio.selectedCells,
                    currentPlayerIndex: tio.currentPlayerIndex,
                    playerResults: tio.playerResults.map { TIOPlayerResult(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, variant: $0.variant, elapsedSeconds: $0.elapsedSeconds, correctCount: $0.correctCount, totalTargets: $0.totalTargets, missTaps: $0.missTaps, didFinish: $0.didFinish) },
                    isFinished: tio.isFinished
                )
            },
            colorTrapState: state.colorTrapState.map { ct in
                ColorTrapGameState(
                    difficulty: ct.difficulty,
                    seed: UInt64(ct.seed) ?? 0,
                    forbiddenColorIndex: ct.forbiddenColorIndex,
                    currentPlayerIndex: ct.currentPlayerIndex,
                    playerResults: ct.playerResults.map { CTPlayerResult(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, hits: $0.hits, fails: $0.fails, survivalTime: $0.survivalTime, eliminated: $0.eliminated) },
                    isFinished: ct.isFinished
                )
            },
            rematchPlayerIDs: state.rematchPlayerIDs.compactMap { UUID(uuidString: $0) },
            stateVersion: state.stateVersion
        )
    }

    private func applySignedOutState() {
        applyGuestState()
        isAuthenticated = false
    }

    private func applyGuestState() {
        Task {
            await realtimeService.unsubscribeFromRoom()
            await realtimeService.unsubscribeFromSocialUpdates()
            await realtimeService.untrackPresence()
        }
        timerTask?.cancel()
        timerTask = nil
        selectedTab = .home
        isAuthenticated = true
        username = "Guest"
        displayName = "Guest"
        email = nil
        publicUserID = nil
        avatarSymbol = "person.crop.circle.fill"
        currentProvider = .guest
        currentUserID = nil
        currentProfileID = nil
        sessionOverridePlayerID = nil
        currentRoom = nil
        quickRejoinRoom = nil
        activeSession = nil
        activeSessionRecordID = nil
        isApplyingRemoteSessionState = false
        showHostLeftAlert = false
        showRejoinPrompt = false
        pendingRejoinSessionID = nil
        syncErrorMessage = nil
        currentRoomAccess = .privateRoom
        invitedOnlineFriendIDs = []
        friends = []
        requests = []
        activities = [
            ActivityItem(title: "Guest mode", subtitle: "Login is skipped for testing.", systemImage: "sparkles")
        ]
        friendSearchResults = []
        roomInvites = []
        visibleRooms = []
        offlineFriends = Self.loadOfflineFriends()
        starWallet = StarWallet(balance: 100)
        subscription = .none
        inviteCode = ""
        inviteTotalCount = 0
        inviteStarsEarned = 0
        currentImposterSettings = nil
        currentMemoryGridSettings = nil
        currentMemoryPathSettings = nil
        currentPassGuessSettings = .default
        currentTapInOrderSettings = nil
        currentColorTrapSettings = nil
        currentSpinBottleDifficulty = .classic
        gameUnlocks = []
        games = [
            GameDefinition(id: .reverseSinging, accentName: "purple"),
            GameDefinition(id: .guessTheSeconds, accentName: "blue"),
            GameDefinition(id: .imposter, accentName: "red"),
            GameDefinition(id: .memoryGrid, accentName: "cyan"),
            GameDefinition(id: .tenTangle, accentName: "pink"),
            GameDefinition(id: .memoryPath, accentName: "teal"),
            GameDefinition(id: .passGuess, accentName: "yellow"),
            GameDefinition(id: .tapInOrder, accentName: "orange"),
            GameDefinition(id: .colorTrap, accentName: "pink"),
            GameDefinition(id: .drawRush, accentName: "cyan"),
            GameDefinition(id: .spinBottle, accentName: "red")
        ]
        errorMessage = nil
        economyFeedback = nil
        lobbyNotice = nil
        onlineUserIDs = []
        latestFriendSearchQuery = ""
        isBusy = false
        isCheckingSession = false
        isSearchingFriends = false
        isProcessingWalletAction = false
        resilienceService.clearActiveSession()
    }

    private func loadSettings() {
        isSoundEnabled = UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true
        isVibrationEnabled = UserDefaults.standard.object(forKey: "isVibrationEnabled") as? Bool ?? true
    }

    private func persistOfflineFriends() {
        let names = offlineFriends.map(\.name)
        UserDefaults.standard.set(names, forKey: "offlineFriendNames")
    }

    private static func loadOfflineFriends() -> [Friend] {
        guard let names = UserDefaults.standard.stringArray(forKey: "offlineFriendNames") else {
            return []
        }
        return names.map { Friend(name: $0, isOnline: false, status: "Offline player", kind: .offline) }
    }

    func saveDeviceToken(_ token: String) {
        guard let currentUserID else { return }
        Task {
            try? await databaseService.upsertDeviceToken(userID: currentUserID, token: token)
        }
    }
}
