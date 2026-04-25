import Foundation
import Supabase

nonisolated struct WalletSnapshot: Hashable, Sendable {
    let wallet: WalletRecord?
    let starTransactions: [StarTransactionRecord]
}

nonisolated final class SupabaseDatabaseService: Sendable {
    private let service: SupabaseService

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    func ensureBootstrap(for userID: UUID, username: String, email: String?) async throws {
        let payload = ProfileBootstrapPayload(username: username, email: email)
        _ = try await service.client
            .rpc("ensure_profile_and_wallet", params: payload)
            .execute()
    }

    func fetchProfile(for userID: UUID) async throws -> PartyProfileRecord? {
        try await service.client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .single()
            .execute()
            .value
    }

    func updateProfile(payload: ProfileUpdatePayload) async throws {
        _ = try await service.client
            .rpc("update_profile_settings", params: payload)
            .execute()
    }

    func fetchWallet(for userID: UUID) async throws -> WalletSnapshot {
        let wallet: WalletRecord? = try? await service.client
            .from("wallets")
            .select()
            .eq("user_id", value: userID)
            .limit(1)
            .single()
            .execute()
            .value

        let starTransactions: [StarTransactionRecord] = (try? await service.client
            .from("star_transactions")
            .select()
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(25)
            .execute()
            .value) ?? []

        return WalletSnapshot(wallet: wallet, starTransactions: starTransactions)
    }

    func fetchGameTrials(for userID: UUID) async throws -> [GameTrialRecord] {
        (try? await service.client
            .from("game_trials")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value) ?? []
    }

    func fetchGameUnlocks(for userID: UUID) async throws -> [GameUnlockRecord] {
        (try? await service.client
            .from("game_unlocks")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value) ?? []
    }

    func fetchSubscription(for userID: UUID) async throws -> SubscriptionRecord? {
        try? await service.client
            .from("subscriptions")
            .select()
            .eq("user_id", value: userID)
            .eq("is_active", value: true)
            .limit(1)
            .single()
            .execute()
            .value
    }

    func createRoom(game: GameType, hostUserID: UUID, access: RoomAccess) async throws -> RoomRecord {
        let room = RoomRecord(
            id: UUID(),
            code: randomRoomCode(),
            gameKey: game.rawValue,
            hostUserID: hostUserID,
            status: "lobby",
            access: access.rawValue,
            createdAt: nil
        )
        let created: RoomRecord = try await service.client
            .from("rooms")
            .insert(room)
            .select()
            .single()
            .execute()
            .value

        let hostMember = RoomMemberRecord(
            id: UUID(),
            roomID: created.id,
            userID: hostUserID,
            isHost: true,
            isReady: true,
            joinedAt: nil,
            profile: nil
        )
        _ = try await service.client
            .from("room_members")
            .insert(hostMember)
            .execute()

        return created
    }

    func syncRoomInvites(roomID: UUID, inviterUserID: UUID, invitedUserIDs: Set<UUID>) async throws {
        let existingInvites: [RoomInviteRecord] = (try? await service.client
            .from("room_invites")
            .select()
            .eq("room_id", value: roomID)
            .execute()
            .value) ?? []

        let existingUserIDs: Set<UUID> = Set(existingInvites.map(\.invitedUserID))
        let invitesToInsert: [RoomInviteInsertRecord] = invitedUserIDs
            .subtracting(existingUserIDs)
            .map {
                RoomInviteInsertRecord(
                    id: UUID(),
                    roomID: roomID,
                    inviterUserID: inviterUserID,
                    invitedUserID: $0,
                    status: "pending"
                )
            }

        if !invitesToInsert.isEmpty {
            _ = try await service.client
                .from("room_invites")
                .upsert(invitesToInsert, onConflict: "room_id,invited_user_id")
                .execute()
        }

        let inviteIDsToRevoke: [UUID] = existingInvites
            .filter { !invitedUserIDs.contains($0.invitedUserID) && $0.status == "pending" }
            .map(\.id)

        if !inviteIDsToRevoke.isEmpty {
            _ = try await service.client
                .from("room_invites")
                .update(["status": "revoked"])
                .in("id", values: inviteIDsToRevoke)
                .execute()
        }
    }

    func fetchVisibleRooms(for userID: UUID) async throws -> [GameRoom] {
        let roomRecords: [RoomRecord] = (try? await service.client
            .from("rooms")
            .select()
            .eq("status", value: "lobby")
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value) ?? []

        var rooms: [GameRoom] = []
        for roomRecord in roomRecords {
            rooms.append(try await hydrateRoom(roomRecord))
        }

        return rooms.filter { room in
            if room.players.contains(where: { $0.id == userID }) {
                return false
            }
            switch room.access {
            case .publicRoom:
                return true
            case .privateRoom:
                return room.invitedFriendIDs.contains(userID)
            }
        }
    }

    func fetchRoomInvites(for userID: UUID) async throws -> [RoomInvite] {
        let inviteRecords: [RoomInviteRecord] = (try? await service.client
            .from("room_invites")
            .select("id,room_id,inviter_user_id,invited_user_id,status,created_at,rooms(*)")
            .eq("invited_user_id", value: userID)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value) ?? []

        var invites: [RoomInvite] = []
        for inviteRecord in inviteRecords {
            guard let roomRecord = inviteRecord.room else { continue }
            let room = try await hydrateRoom(roomRecord)
            invites.append(
                RoomInvite(
                    id: inviteRecord.id,
                    roomID: inviteRecord.roomID,
                    roomCode: room.code,
                    game: room.game,
                    hostName: room.hostName,
                    invitedAt: inviteRecord.createdAt
                )
            )
        }
        return invites
    }

    func respondToRoomInvite(inviteID: UUID, status: String) async throws {
        _ = try await service.client
            .from("room_invites")
            .update(["status": status])
            .eq("id", value: inviteID)
            .execute()
    }

    func joinRoom(code: String, userID: UUID) async throws -> RoomRecord {
        let normalizedCode: String = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let room: RoomRecord = try await service.client
            .from("rooms")
            .select()
            .eq("code", value: normalizedCode)
            .limit(1)
            .single()
            .execute()
            .value

        let existing: [RoomMemberRecord] = (try? await service.client
            .from("room_members")
            .select()
            .eq("room_id", value: room.id)
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value) ?? []

        if existing.isEmpty {
            let membership = RoomMemberRecord(
                id: UUID(),
                roomID: room.id,
                userID: userID,
                isHost: false,
                isReady: false,
                joinedAt: nil,
                profile: nil
            )
            _ = try await service.client
                .from("room_members")
                .insert(membership)
                .execute()
        }

        return room
    }

    func fetchRoom(code: String) async throws -> GameRoom {
        let roomRecord: RoomRecord = try await service.client
            .from("rooms")
            .select()
            .eq("code", value: code.uppercased())
            .limit(1)
            .single()
            .execute()
            .value
        return try await hydrateRoom(roomRecord)
    }

    func fetchFriends(for userID: UUID) async throws -> [Friend] {
        let records: [FriendshipRecord] = (try? await service.client
            .from("friendships")
            .select()
            .or("user_id.eq.\(userID.uuidString),friend_id.eq.\(userID.uuidString)")
            .execute()
            .value) ?? []

        let relatedIDs: [UUID] = records.compactMap { record in
            if record.userID == userID {
                return record.friendID
            }
            if record.friendID == userID {
                return record.userID
            }
            return nil
        }

        guard !relatedIDs.isEmpty else {
            return []
        }

        let profiles: [PartyProfileRecord] = (try? await service.client
            .from("profiles")
            .select()
            .in("id", values: relatedIDs)
            .execute()
            .value) ?? []

        let roomMemberRecords: [RoomMemberRecord] = (try? await service.client
            .from("room_members")
            .select("id,room_id,user_id,is_host,is_ready,joined_at,profiles(*)")
            .in("user_id", values: relatedIDs)
            .execute()
            .value) ?? []

        let statusByUserID: [UUID: String] = Dictionary(uniqueKeysWithValues: roomMemberRecords.map { member in
            let value: String = member.isReady ? "In game" : "In lobby"
            return (member.userID, value)
        })

        return profiles.map {
            Friend(
                id: $0.id,
                name: $0.username,
                isOnline: true,
                status: statusByUserID[$0.id] ?? "Ready to invite",
                kind: .online,
                publicUserID: $0.publicID,
                avatarURL: $0.avatarURL
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func searchProfiles(query: String, currentUserID: UUID) async throws -> [FriendSearchResult] {
        let trimmedQuery: String = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        let records: [FriendSearchResponseRecord] = try await service.client
            .rpc("search_profiles", params: ["p_query": trimmedQuery])
            .execute()
            .value

        return records
            .filter { $0.id != currentUserID }
            .map {
                FriendSearchResult(
                    id: $0.id,
                    username: $0.username,
                    email: $0.email,
                    publicUserID: $0.publicID,
                    avatarURL: $0.avatarURL,
                    relationshipState: $0.relationshipState
                )
            }
    }

    func sendFriendRequest(from senderID: UUID, to receiverID: UUID) async throws {
        guard senderID != receiverID else { return }
        let payload = FriendRequestInsertPayload(receiverID: receiverID)
        _ = try await service.client
            .rpc("send_friend_request", params: payload)
            .execute()
    }

    func fetchFriendRequests(for userID: UUID) async throws -> [FriendRequest] {
        let requests: [FriendRequestRecord] = (try? await service.client
            .from("friend_requests")
            .select("id,sender_id,receiver_id,status,created_at,sender:profiles!friend_requests_sender_id_fkey(*)")
            .eq("receiver_id", value: userID)
            .eq("status", value: "pending")
            .execute()
            .value) ?? []

        return requests.map { record in
            let profile = record.senderProfile
            let displayName = profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let username = profile?.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let emailPrefix = profile?.email?.components(separatedBy: "@").first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = [displayName, username, emailPrefix]
                .compactMap { $0 }
                .first(where: { !$0.isEmpty }) ?? "Player"
            return FriendRequest(
                id: record.id,
                name: resolved,
                mutualFriends: 0,
                publicUserID: profile?.publicID,
                avatarURL: profile?.avatarURL
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func acceptFriendRequest(requestID: UUID) async throws {
        let payload = FriendRequestActionPayload(requestID: requestID)
        _ = try await service.client
            .rpc("accept_friend_request", params: payload)
            .execute()
    }

    func declineFriendRequest(requestID: UUID) async throws {
        let payload = FriendRequestActionPayload(requestID: requestID)
        _ = try await service.client
            .rpc("decline_friend_request", params: payload)
            .execute()
    }

    func updateReadyState(roomID: UUID, userID: UUID, isReady: Bool) async throws {
        _ = try await service.client
            .from("room_members")
            .update(["is_ready": isReady])
            .eq("room_id", value: roomID)
            .eq("user_id", value: userID)
            .execute()
    }

    func createGameSession(sessionID: UUID, roomID: UUID, game: GameType, mode: GameMode, userID: UUID, sessionState: SessionStateRecord) async throws -> GameSessionRecord {
        let payload = GameSessionRecord(
            id: sessionID,
            roomID: roomID,
            gameKey: game.rawValue,
            mode: mode.rawValue,
            status: "active",
            createdBy: userID,
            sessionState: sessionState,
            createdAt: nil
        )

        return try await service.client
            .from("game_sessions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateSessionState(sessionID: UUID, state: SessionStateRecord, status: String) async throws {
        let payload = SessionStateUpdatePayload(sessionID: sessionID, status: status, sessionState: state)
        _ = try await service.client
            .from("game_sessions")
            .update(payload)
            .eq("id", value: sessionID)
            .execute()
    }

    func fetchSession(sessionID: UUID) async throws -> GameSessionRecord {
        try await service.client
            .from("game_sessions")
            .select()
            .eq("id", value: sessionID)
            .limit(1)
            .single()
            .execute()
            .value
    }

    func persistResults(sessionID: UUID, results: [GameResultUpsertRecord]) async throws {
        guard !results.isEmpty else { return }
        _ = try await service.client
            .from("game_results")
            .upsert(results, onConflict: "session_id,user_id")
            .execute()

        _ = try await service.client
            .from("game_sessions")
            .update(["status": "finalized"])
            .eq("id", value: sessionID)
            .execute()
    }

    func finalizeGame(sessionID: UUID, idempotencyKey: UUID) async throws {
        let payload = RewardRPCPayload(sessionId: sessionID, idempotencyKey: idempotencyKey)
        _ = try await service.client
            .rpc("finalize_game_results", params: payload)
            .execute()
    }

    func claimDailyReward() async throws -> Int {
        let response: Int = (try? await service.client
            .rpc("claim_daily_reward")
            .execute()
            .value) ?? 0
        return response
    }

    func grantPurchasedStars(amount: Int, productID: String, idempotencyKey: UUID) async throws -> Int {
        let payload = GrantPurchasedStarsPayload(amount: amount, productID: productID, idempotencyKey: idempotencyKey)
        let response: Int = (try? await service.client
            .rpc("grant_purchased_stars", params: payload)
            .execute()
            .value) ?? 0
        return response
    }

    func grantSubscriptionStars(amount: Int, tier: String, periodKey: String, expiresAt: Date?) async throws -> Int {
        let payload = GrantSubscriptionStarsPayload(amount: amount, tier: tier, periodKey: periodKey, expiresAt: expiresAt)
        let response: Int = (try? await service.client
            .rpc("grant_subscription_stars", params: payload)
            .execute()
            .value) ?? 0
        return response
    }

    private func hydrateRoom(_ roomRecord: RoomRecord) async throws -> GameRoom {
        let memberRecords: [RoomMemberRecord] = (try? await service.client
            .from("room_members")
            .select("id,room_id,user_id,is_host,is_ready,joined_at,profiles(*)")
            .eq("room_id", value: roomRecord.id)
            .order("joined_at", ascending: true)
            .execute()
            .value) ?? []

        let players: [PlayerProfile] = memberRecords.map { member in
            let username: String = member.profile?.username ?? "Player"
            return PlayerProfile(
                id: member.userID,
                username: username,
                isHost: member.isHost,
                isReady: member.isReady,
                isOnline: true,
                score: 0
            )
        }

        let inviteRecords: [RoomInviteRecord] = (try? await service.client
            .from("room_invites")
            .select()
            .eq("room_id", value: roomRecord.id)
            .in("status", values: ["pending", "accepted"])
            .execute()
            .value) ?? []

        return GameRoom(
            id: roomRecord.id,
            code: roomRecord.code,
            game: GameType(rawValue: roomRecord.gameKey),
            mode: .multiDevice,
            hostName: players.first(where: { $0.isHost })?.username ?? "Host",
            players: players,
            message: roomRecord.status == "lobby" ? "Room synced from Supabase." : "Match is already in progress.",
            access: RoomAccess(rawValue: roomRecord.access) ?? .privateRoom,
            invitedFriendIDs: Set(inviteRecords.map(\.invitedUserID)),
            status: .waiting
        )
    }

    func deleteAccountData() async throws {
        _ = try await service.client
            .rpc("delete_my_account_data")
            .execute()
    }

    func fetchMyInviteCode() async throws -> String {
        let code: String = (try? await service.client
            .rpc("get_my_invite_code")
            .execute()
            .value) ?? ""
        return code
    }

    func fetchInviteSummary() async throws -> InviteSummaryRecord {
        let rows: [InviteSummaryRecord] = (try? await service.client
            .rpc("get_my_invite_summary")
            .execute()
            .value) ?? []
        return rows.first ?? InviteSummaryRecord(totalInvites: 0, starsEarned: 0)
    }

    func redeemInviteCode(_ code: String) async throws -> RedeemInviteResponse {
        let payload = RedeemInvitePayload(code: code)
        let response: RedeemInviteResponse = try await service.client
            .rpc("redeem_invite_code", params: payload)
            .execute()
            .value
        return response
    }

    func upsertDeviceToken(userID: UUID, token: String) async throws {
        let payload = DeviceTokenRecord(userID: userID, token: token, platform: "ios")
        _ = try await service.client
            .from("device_tokens")
            .upsert(payload, onConflict: "user_id,platform")
            .execute()
    }

    private func randomRoomCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<4).map { _ in letters.randomElement() ?? "A" })
    }
}
