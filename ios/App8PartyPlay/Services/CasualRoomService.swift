import Foundation
import Supabase

nonisolated struct CasualRPCResponse: Codable, Sendable {
    let success: Bool?
    let error: String?
    let room_id: String?
    let reconnected: Bool?
    let new_host_id: String?
    let room_closed: Bool?
    let stale_marked: Int?
}

nonisolated struct CasualTurnAdvanceResponse: Codable, Sendable {
    let success: Bool?
    let error: String?
    let server_index: Int?
    let active_player_id: String?
    let turn_version: Int?
}

@MainActor
final class CasualRoomService {
    private let supabase: SupabaseService
    private var channel: RealtimeChannelV2?
    private var broadcastTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    var onRoomUpdated: (() -> Void)?
    var onGameStarting: ((CasualRoom) -> Void)?
    var onPlayerKicked: ((UUID) -> Void)?
    var onRoomClosed: (() -> Void)?
    var onHostChanged: ((UUID) -> Void)?
    var onReadyCheckRequested: ((UUID) -> Void)?
    var onReadyCheckConfirmed: ((UUID) -> Void)?
    var onReadyCheckCancelled: (() -> Void)?
    var onRoomStateBroadcast: ((CasualRoom) -> Void)?
    var onGameStateSync: ((CasualGameStatePayload) -> Void)?
    var onSnapshotRequest: (() -> Void)?

    init(supabase: SupabaseService = .shared) {
        self.supabase = supabase
    }

    func createRoom(gameType: GameType, host: GuestPlayer) async throws -> CasualRoom {
        let maxRetries = 3
        var lastError: Error?

        for _ in 0..<maxRetries {
            let code = generateRoomCode()
            let roomID = UUID()

            let params: [String: AnyJSON] = [
                "p_room_id": .string(roomID.uuidString),
                "p_room_code": .string(code),
                "p_game_type": .string(gameType.rawValue),
                "p_status": .string(CasualRoomStatus.waiting.rawValue),
                "p_host_player_id": .string(host.id.uuidString),
                "p_session_token": .string(host.sessionToken),
                "p_host_display_name": .string(host.displayName),
                "p_max_players": .integer(gameType.maxPlayers),
                "p_min_players": .integer(gameType.minPlayers),
                "p_settings_rounds": .integer(0),
                "p_settings_answer_time": .integer(0),
                "p_settings_vote_time": .integer(0),
                "p_settings_question_pack": .string("random")
            ]

            let response: CasualRPCResponse = try await supabase.client
                .rpc("casual_create_room", params: params)
                .execute()
                .value

            if let error = response.error {
                if error.contains("unique_violation") || error.contains("duplicate") || error.contains("23505") {
                    lastError = CasualRoomError.databaseError(error)
                    continue
                }
                throw CasualRoomError.databaseError(error)
            }

            await joinChannelBestEffort(code: code)
            return try await fetchRoom(roomID: roomID, gameType: gameType)
        }

        throw lastError ?? CasualRoomError.databaseError("Failed to create room after \(maxRetries) attempts.")
    }

    func joinRoom(code: String, player: GuestPlayer) async throws -> CasualRoom {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.count >= 4 else { throw CasualRoomError.invalidRoomCode }

        let normalizedName = GuestPlayer.normalize(player.displayName)

        let params: [String: AnyJSON] = [
            "p_room_code": .string(normalizedCode),
            "p_player_id": .string(player.id.uuidString),
            "p_display_name": .string(player.displayName),
            "p_normalized_name": .string(normalizedName),
            "p_session_token": .string(player.sessionToken)
        ]

        let response: CasualRPCResponse = try await supabase.client
            .rpc("casual_join_room", params: params)
            .execute()
            .value

        if let error = response.error {
            switch error {
            case "room_not_found": throw CasualRoomError.roomNotFound
            case "room_already_started": throw CasualRoomError.roomAlreadyStarted
            case "room_full": throw CasualRoomError.roomFull
            case "duplicate_name": throw CasualRoomError.duplicateName
            default: throw CasualRoomError.databaseError(error)
            }
        }

        guard let roomIDStr = response.room_id, let roomID = UUID(uuidString: roomIDStr) else {
            throw CasualRoomError.connectionFailed
        }

        await joinChannelBestEffort(code: normalizedCode)
        await notifyRoomUpdate()

        let roomRecord: CasualRoomRecord = try await supabase.client
            .from("casual_rooms")
            .select()
            .eq("id", value: roomID)
            .single()
            .execute()
            .value

        let gameType = GameType(rawValue: roomRecord.gameType)

        return try await fetchRoom(roomID: roomID, gameType: gameType)
    }

    func fetchRoomFromDB(roomID: UUID) async throws -> (CasualRoomRecord, [CasualRoomPlayerRecord]) {
        let roomRecord: CasualRoomRecord = try await supabase.client
            .from("casual_rooms")
            .select()
            .eq("id", value: roomID)
            .single()
            .execute()
            .value

        let playerRecords: [CasualRoomPlayerRecord] = try await supabase.client
            .from("casual_room_players")
            .select()
            .eq("room_id", value: roomID)
            .order("joined_at", ascending: true)
            .execute()
            .value

        return (roomRecord, playerRecords)
    }

    func fetchRoom(roomID: UUID, gameType: GameType) async throws -> CasualRoom {
        let (roomRecord, playerRecords) = try await fetchRoomFromDB(roomID: roomID)
        let players = playerRecords.map { $0.toGuestPlayer() }
        let status = CasualRoomStatus(rawValue: roomRecord.status) ?? .waiting

        return CasualRoom(
            id: roomRecord.id,
            code: roomRecord.roomCode,
            gameType: gameType,
            players: players,
            status: status,
            maxPlayers: roomRecord.maxPlayers,
            minPlayers: roomRecord.minPlayers,
            createdAt: roomRecord.createdAt ?? Date()
        )
    }

    func kickPlayer(roomID: UUID, guestPlayerID: UUID, hostSessionToken: String) async throws {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_target_player_id": .string(guestPlayerID.uuidString),
            "p_host_session_token": .string(hostSessionToken)
        ]

        let response: CasualRPCResponse = try await supabase.client
            .rpc("casual_kick_player", params: params)
            .execute()
            .value

        if let error = response.error {
            throw CasualRoomError.databaseError(error)
        }

        // Broadcast kick multiple times so the target client definitely sees it
        // even if the realtime channel was briefly unhealthy.
        for attempt in 0..<3 {
            await broadcastEvent(.playerKicked, payload: ["playerId": guestPlayerID.uuidString])
            await notifyRoomUpdate()
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    func updateRoomStatus(roomID: UUID, status: CasualRoomStatus, hostSessionToken: String) async throws {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_status": .string(status.rawValue),
            "p_host_session_token": .string(hostSessionToken)
        ]

        let response: CasualRPCResponse = try await supabase.client
            .rpc("casual_update_room_status", params: params)
            .execute()
            .value

        if let error = response.error {
            throw CasualRoomError.databaseError(error)
        }
    }

    func clearAllReady(roomID: UUID, hostSessionToken: String) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_host_session_token": .string(hostSessionToken)
        ]

        _ = try? await supabase.client
            .rpc("casual_clear_all_ready", params: params)
            .execute()
    }

    // MARK: - Authoritative turn advance

    @discardableResult
    func claimTurnAdvance(roomID: UUID, sessionToken: String, expectedIndex: Int) async -> CasualTurnAdvanceResponse {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_session_token": .string(sessionToken),
            "p_expected_index": .integer(expectedIndex)
        ]
        do {
            let resp: CasualTurnAdvanceResponse = try await supabase.client
                .rpc("casual_claim_turn_advance", params: params)
                .execute()
                .value
            return resp
        } catch {
            return CasualTurnAdvanceResponse(success: false, error: "rpc_failed", server_index: nil, active_player_id: nil, turn_version: nil)
        }
    }

    func resetTurnCounter(roomID: UUID, hostSessionToken: String) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_host_session_token": .string(hostSessionToken)
        ]
        _ = try? await supabase.client
            .rpc("casual_reset_turn", params: params)
            .execute()
    }

    // MARK: - Per-player rematch readiness

    func setRematchReady(roomID: UUID, sessionToken: String, isReady: Bool) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_session_token": .string(sessionToken),
            "p_ready": .bool(isReady)
        ]
        _ = try? await supabase.client
            .rpc("casual_set_rematch_ready", params: params)
            .execute()
    }

    func clearAllRematch(roomID: UUID, hostSessionToken: String) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_host_session_token": .string(hostSessionToken)
        ]
        _ = try? await supabase.client
            .rpc("casual_clear_all_rematch", params: params)
            .execute()
    }

    func fetchRematchReadyPlayerIDs(roomID: UUID) async -> Set<UUID> {
        do {
            let records: [CasualRoomPlayerRecord] = try await supabase.client
                .from("casual_room_players")
                .select()
                .eq("room_id", value: roomID)
                .execute()
                .value
            return Set(records.compactMap { $0.rematchReadyAt == nil ? nil : $0.guestPlayerId })
        } catch {
            return []
        }
    }

    func setPlayerReady(roomID: UUID, sessionToken: String, isReady: Bool) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_session_token": .string(sessionToken),
            "p_ready": .bool(isReady)
        ]

        _ = try? await supabase.client
            .rpc("casual_set_ready", params: params)
            .execute()
    }

    func leaveRoom(roomID: UUID, playerID: UUID, sessionToken: String) async throws {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_player_id": .string(playerID.uuidString),
            "p_session_token": .string(sessionToken)
        ]

        let response: CasualRPCResponse = try await supabase.client
            .rpc("casual_leave_room", params: params)
            .execute()
            .value

        if response.room_closed == true {
            // Fire roomClosed broadcast several times so every guest on the
            // channel sees it even through transient network blips.
            for attempt in 0..<3 {
                await broadcastEvent(.roomClosed, payload: ["closed": "true"])
                await notifyRoomUpdate()
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(400))
                }
            }
        } else if let newHostStr = response.new_host_id {
            await broadcastEvent(.hostChanged, payload: ["newHostId": newHostStr])
            await notifyRoomUpdate()
        } else {
            await notifyRoomUpdate()
        }
    }

    var onSyncError: ((String) -> Void)?

    func markPlayerDisconnected(roomID: UUID, guestPlayerID: UUID, sessionToken: String) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_player_id": .string(guestPlayerID.uuidString),
            "p_session_token": .string(sessionToken)
        ]

        do {
            _ = try await supabase.client
                .rpc("casual_mark_disconnected", params: params)
                .execute()
        } catch {
            onSyncError?("Failed to mark disconnect: \(error.localizedDescription)")
        }
    }

    func sendHeartbeat(roomID: UUID, sessionToken: String) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_session_token": .string(sessionToken)
        ]

        do {
            _ = try await supabase.client
                .rpc("casual_heartbeat", params: params)
                .execute()
        } catch {
            onSyncError?("Heartbeat failed: \(error.localizedDescription)")
        }
    }

    func reconnectPlayer(sessionToken: String) async throws -> (CasualRoom, GuestPlayer)? {
        let params: [String: AnyJSON] = [
            "p_session_token": .string(sessionToken)
        ]

        let records: [CasualRoomPlayerRecord] = try await supabase.client
            .from("casual_room_players")
            .select()
            .eq("session_token", value: sessionToken)
            .eq("is_connected", value: true)
            .limit(1)
            .execute()
            .value

        guard let playerRecord = records.first else { return nil }

        // Allow reconnecting into a match that is already starting or in progress,
        // so a guest who backgrounds during gameplay can re-enter the active
        // session instead of being dropped to Home.
        let roomRecords: [CasualRoomRecord] = try await supabase.client
            .from("casual_rooms")
            .select()
            .eq("id", value: playerRecord.roomId)
            .in("status", values: ["waiting", "full", "starting", "in_progress"])
            .limit(1)
            .execute()
            .value

        guard let roomRecord = roomRecords.first else { return nil }

        let gameType = GameType(rawValue: roomRecord.gameType)

        let room = try await fetchRoom(roomID: roomRecord.id, gameType: gameType)
        let player = playerRecord.toGuestPlayer()

        await joinChannelBestEffort(code: roomRecord.roomCode)

        return (room, player)
    }

    func cleanupStalePlayers(roomID: UUID, graceSeconds: Int = 120) async {
        let params: [String: AnyJSON] = [
            "p_room_id": .string(roomID.uuidString),
            "p_grace_seconds": .integer(graceSeconds)
        ]

        _ = try? await supabase.client
            .rpc("casual_cleanup_stale_players", params: params)
            .execute()
    }

    func startGame(room: CasualRoom, hostSessionToken: String) async throws {
        try await updateRoomStatus(roomID: room.id, status: .starting, hostSessionToken: hostSessionToken)
        let payload = CasualRoomStatePayload(from: room)
        // Fire gameStarting repeatedly so guests reliably transition even if the
        // realtime channel dropped a packet or is briefly unhealthy. The DB
        // watchdog is a much slower fallback (several seconds).
        for attempt in 0..<4 {
            try? await channel?.broadcast(event: CasualBroadcastEvent.gameStarting.rawValue, message: payload)
            try? await channel?.broadcast(event: CasualBroadcastEvent.roomStateFull.rawValue, message: payload)
            await notifyRoomUpdate()
            if attempt < 3 {
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    func broadcastGameStarting(_ room: CasualRoom) async {
        let updatedRoom = CasualRoom(
            id: room.id,
            code: room.code,
            gameType: room.gameType,
            players: room.players,
            status: .starting,
            maxPlayers: room.maxPlayers,
            minPlayers: room.minPlayers,
            createdAt: room.createdAt
        )
        let payload = CasualRoomStatePayload(from: updatedRoom)
        try? await channel?.broadcast(event: CasualBroadcastEvent.gameStarting.rawValue, message: payload)
    }

    func startHeartbeat(roomID: UUID, sessionToken: String) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            // Immediate first heartbeat so the backend knows we're alive without
            // waiting a full tick — drastically improves perceived join speed.
            await self?.sendHeartbeat(roomID: roomID, sessionToken: sessionToken)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                await self?.sendHeartbeat(roomID: roomID, sessionToken: sessionToken)
            }
        }
    }

    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    func disconnect() async {
        stopHeartbeat()
        broadcastTask?.cancel()
        broadcastTask = nil

        if let channel {
            _ = await channel.unsubscribe()
            await supabase.client.removeChannel(channel)
        }
        channel = nil
        onRoomUpdated = nil
        onGameStarting = nil
        onPlayerKicked = nil
        onRoomClosed = nil
        onHostChanged = nil
        onReadyCheckRequested = nil
        onReadyCheckConfirmed = nil
        onReadyCheckCancelled = nil
        onRoomStateBroadcast = nil
        onGameStateSync = nil
        onSnapshotRequest = nil
    }

    private func joinChannelBestEffort(code: String) async {
        for attempt in 0..<3 {
            do {
                try await joinChannel(code: code)
                return
            } catch is CancellationError {
                if attempt < 2 { try? await Task.sleep(for: .milliseconds(400)) }
            } catch {
                if attempt < 2 { try? await Task.sleep(for: .milliseconds(400)) }
            }
        }
    }

    private func joinChannel(code: String) async throws {
        broadcastTask?.cancel()
        broadcastTask = nil

        if let channel {
            _ = await channel.unsubscribe()
            await supabase.client.removeChannel(channel)
        }

        let ch = supabase.client.channel("casual-room-\(code)") {
            $0.broadcast.receiveOwnBroadcasts = true
        }
        channel = ch

        let startStream = ch.broadcastStream(event: CasualBroadcastEvent.gameStarting.rawValue)
        let kickStream = ch.broadcastStream(event: CasualBroadcastEvent.playerKicked.rawValue)
        let closeStream = ch.broadcastStream(event: CasualBroadcastEvent.roomClosed.rawValue)
        let refreshStream = ch.broadcastStream(event: CasualBroadcastEvent.roomStateSync.rawValue)
        let hostStream = ch.broadcastStream(event: CasualBroadcastEvent.hostChanged.rawValue)
        let readyReqStream = ch.broadcastStream(event: CasualBroadcastEvent.readyCheckRequested.rawValue)
        let readyConfStream = ch.broadcastStream(event: CasualBroadcastEvent.readyCheckConfirmed.rawValue)
        let readyCancelStream = ch.broadcastStream(event: CasualBroadcastEvent.readyCheckCancelled.rawValue)
        let fullStateStream = ch.broadcastStream(event: CasualBroadcastEvent.roomStateFull.rawValue)
        let gameStateStream = ch.broadcastStream(event: CasualBroadcastEvent.gameStateSync.rawValue)
        let snapshotReqStream = ch.broadcastStream(event: CasualBroadcastEvent.snapshotRequest.rawValue)

        try await ch.subscribeWithError()

        broadcastTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await message in startStream {
                        guard !Task.isCancelled else { return }
                        await self?.handleGameStartingMessage(message)
                    }
                }
                group.addTask {
                    for await message in kickStream {
                        guard !Task.isCancelled else { return }
                        await self?.handlePlayerKickedMessage(message)
                    }
                }
                group.addTask {
                    for await _ in closeStream {
                        guard !Task.isCancelled else { return }
                        await self?.onRoomClosed?()
                    }
                }
                group.addTask {
                    for await _ in refreshStream {
                        guard !Task.isCancelled else { return }
                        await self?.onRoomUpdated?()
                    }
                }
                group.addTask {
                    for await message in hostStream {
                        guard !Task.isCancelled else { return }
                        await self?.handleHostChangedMessage(message)
                    }
                }
                group.addTask {
                    for await message in readyReqStream {
                        guard !Task.isCancelled else { return }
                        await self?.handleReadyCheckMessage(message, kind: .request)
                    }
                }
                group.addTask {
                    for await message in readyConfStream {
                        guard !Task.isCancelled else { return }
                        await self?.handleReadyCheckMessage(message, kind: .confirm)
                    }
                }
                group.addTask {
                    for await _ in readyCancelStream {
                        guard !Task.isCancelled else { return }
                        await self?.onReadyCheckCancelled?()
                    }
                }
                group.addTask {
                    for await message in fullStateStream {
                        guard !Task.isCancelled else { return }
                        await self?.handleRoomStateBroadcast(message)
                    }
                }
                group.addTask {
                    for await message in gameStateStream {
                        guard !Task.isCancelled else { return }
                        await self?.handleGameStateSync(message)
                    }
                }
                group.addTask {
                    for await _ in snapshotReqStream {
                        guard !Task.isCancelled else { return }
                        await self?.onSnapshotRequest?()
                    }
                }
            }
        }
    }

    private func handleGameStateSync(_ message: JSONObject) {
        guard let payload = decodeMessage(message, as: CasualGameStatePayload.self) else { return }
        onGameStateSync?(payload)
    }

    private func handleRoomStateBroadcast(_ message: JSONObject) {
        guard let payload = decodeMessage(message, as: CasualRoomStatePayload.self),
              let room = payload.toCasualRoom() else { return }
        onRoomStateBroadcast?(room)
    }

    private enum ReadyKind { case request, confirm }

    func broadcastReadyCheckRequested(hostID: UUID) async {
        await broadcastEvent(.readyCheckRequested, payload: ["hostId": hostID.uuidString])
    }

    func broadcastReadyCheckConfirmed(playerID: UUID) async {
        await broadcastEvent(.readyCheckConfirmed, payload: ["playerId": playerID.uuidString])
    }

    func broadcastReadyCheckCancelled() async {
        await broadcastEvent(.readyCheckCancelled, payload: ["cancelled": "true"])
    }

    func broadcastRoomState(_ room: CasualRoom) async {
        let payload = CasualRoomStatePayload(from: room)
        try? await channel?.broadcast(event: CasualBroadcastEvent.roomStateFull.rawValue, message: payload)
    }

    func broadcastRoomRefresh() async {
        await notifyRoomUpdate()
    }

    func broadcastGameState(_ payload: CasualGameStatePayload) async {
        try? await channel?.broadcast(event: CasualBroadcastEvent.gameStateSync.rawValue, message: payload)
    }

    /// Broadcast a lightweight snapshot-request so the authoritative active player
    /// / host immediately rebroadcasts its game state. Used by spectators on
    /// resume so they don't wait for the next rebroadcast pump tick.
    func requestGameStateSnapshot() async {
        await broadcastEvent(.snapshotRequest, payload: ["ts": "\(Date().timeIntervalSince1970)"])
    }

    private func handleReadyCheckMessage(_ message: JSONObject, kind: ReadyKind) {
        switch kind {
        case .request:
            guard let payload = decodeMessage(message, as: CasualReadyCheckRequestPayload.self),
                  let uuid = UUID(uuidString: payload.hostId) else { return }
            onReadyCheckRequested?(uuid)
        case .confirm:
            guard let payload = decodeMessage(message, as: CasualPlayerEventPayload.self),
                  let uuid = UUID(uuidString: payload.playerId) else { return }
            onReadyCheckConfirmed?(uuid)
        }
    }

    private func notifyRoomUpdate() async {
        let payload: [String: AnyJSON] = ["ts": .string("\(Date().timeIntervalSince1970)")]
        try? await channel?.broadcast(event: CasualBroadcastEvent.roomStateSync.rawValue, message: payload)
    }

    private func broadcastEvent(_ event: CasualBroadcastEvent, payload: [String: String]) async {
        let converted: [String: AnyJSON] = payload.mapValues { .string($0) }
        try? await channel?.broadcast(event: event.rawValue, message: converted)
    }

    private func decodeMessage<T: Decodable>(_ message: JSONObject, as type: T.Type) -> T? {
        if let payload = message["payload"]?.objectValue,
           let data = try? JSONEncoder().encode(payload),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }

        guard let data = try? JSONEncoder().encode(message) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func handleGameStartingMessage(_ message: JSONObject) {
        guard let payload = decodeMessage(message, as: CasualRoomStatePayload.self),
              let room = payload.toCasualRoom() else { return }
        onGameStarting?(room)
    }

    private func handlePlayerKickedMessage(_ message: JSONObject) {
        guard let payload = decodeMessage(message, as: CasualPlayerEventPayload.self),
              let uuid = UUID(uuidString: payload.playerId) else { return }
        onPlayerKicked?(uuid)
    }

    private func handleHostChangedMessage(_ message: JSONObject) {
        guard let payload = decodeMessage(message, as: CasualHostChangedPayload.self),
              let uuid = UUID(uuidString: payload.newHostId) else { return }
        onHostChanged?(uuid)
    }

    private func generateRoomCode() -> String {
        let digits = Array("0123456789")
        return String((0..<6).map { _ in digits.randomElement() ?? "0" })
    }
}
