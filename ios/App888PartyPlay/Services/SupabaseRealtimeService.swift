import Foundation
import Supabase

@MainActor
final class SupabaseRealtimeService {
    private let service: SupabaseService
    private var roomChannel: RealtimeChannelV2?
    private var socialChannel: RealtimeChannelV2?
    private var presenceChannel: RealtimeChannelV2?
    private var roomTask: Task<Void, Never>?
    private var memberTask: Task<Void, Never>?
    private var sessionTask: Task<Void, Never>?
    private var socialFriendshipTask: Task<Void, Never>?
    private var socialRequestTask: Task<Void, Never>?
    private var socialInviteTask: Task<Void, Never>?
    private var socialRoomTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private(set) var onlineUserIDs: Set<UUID> = []

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    deinit {
        roomTask?.cancel()
        memberTask?.cancel()
        sessionTask?.cancel()
        socialFriendshipTask?.cancel()
        socialRequestTask?.cancel()
        socialInviteTask?.cancel()
        socialRoomTask?.cancel()
        presenceTask?.cancel()
    }

    func subscribeToRoom(
        code: String,
        onRoomUpdate: @escaping @MainActor (String) -> Void,
        onSessionUpdate: @escaping @MainActor (GameSessionRecord) -> Void
    ) {
        roomTask?.cancel()
        memberTask?.cancel()
        sessionTask?.cancel()
        roomTask = Task {
            await unsubscribeFromRoom()
            let normalizedCode: String = code.uppercased()
            let channel = service.client.channel("room-\(normalizedCode)")
            roomChannel = channel

            let roomMemberChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "room_members")
            let roomChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "rooms")
            let sessionChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "game_sessions")
            try? await channel.subscribeWithError()

            memberTask = Task {
                for await _ in roomMemberChanges {
                    onRoomUpdate(normalizedCode)
                }
            }

            sessionTask = Task {
                let decoder = JSONDecoder()
                for await change in sessionChanges {
                    switch change {
                    case .insert(let action):
                        if let sessionRecord = try? action.decodeRecord(as: GameSessionRecord.self, decoder: decoder),
                           sessionRecord.sessionState?.roomCode == normalizedCode {
                            onSessionUpdate(sessionRecord)
                        }
                        onRoomUpdate(normalizedCode)
                    case .update(let action):
                        if let sessionRecord = try? action.decodeRecord(as: GameSessionRecord.self, decoder: decoder),
                           sessionRecord.sessionState?.roomCode == normalizedCode {
                            onSessionUpdate(sessionRecord)
                        }
                        onRoomUpdate(normalizedCode)
                    case .delete:
                        onRoomUpdate(normalizedCode)
                    }
                }
            }

            for await _ in roomChanges {
                onRoomUpdate(normalizedCode)
            }
        }
    }

    func subscribeToSocialUpdates(userID: UUID, onUpdate: @escaping @MainActor () -> Void) {
        socialFriendshipTask?.cancel()
        socialRequestTask?.cancel()
        socialInviteTask?.cancel()
        socialRoomTask?.cancel()
        socialFriendshipTask = Task {
            await unsubscribeFromSocialUpdates()
            let uid = userID.uuidString.lowercased()
            let channel = service.client.channel("social-updates-\(uid)")
            socialChannel = channel

            let friendshipChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "friendships", filter: "user_id=eq.\(uid)")
            let friendshipChanges2 = channel.postgresChange(AnyAction.self, schema: "public", table: "friendships", filter: "friend_id=eq.\(uid)")
            let requestChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "friend_requests", filter: "receiver_id=eq.\(uid)")
            let inviteChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "room_invites", filter: "invited_user_id=eq.\(uid)")
            let roomChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "rooms")
            try? await channel.subscribeWithError()

            socialFriendshipTask = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in friendshipChanges {
                            await onUpdate()
                        }
                    }
                    group.addTask {
                        for await _ in friendshipChanges2 {
                            await onUpdate()
                        }
                    }
                }
            }

            socialRequestTask = Task {
                for await _ in requestChanges {
                    onUpdate()
                }
            }

            socialInviteTask = Task {
                for await _ in inviteChanges {
                    onUpdate()
                }
            }

            socialRoomTask = Task {
                for await _ in roomChanges {
                    onUpdate()
                }
            }
        }
    }

    func unsubscribeFromRoom() async {
        roomTask?.cancel()
        memberTask?.cancel()
        sessionTask?.cancel()
        roomTask = nil
        memberTask = nil
        sessionTask = nil
        guard let roomChannel else { return }
        _ = await roomChannel.unsubscribe()
        _ = await service.client.removeChannel(roomChannel)
        self.roomChannel = nil
    }

    func unsubscribeFromSocialUpdates() async {
        socialFriendshipTask?.cancel()
        socialRequestTask?.cancel()
        socialInviteTask?.cancel()
        socialRoomTask?.cancel()
        socialFriendshipTask = nil
        socialRequestTask = nil
        socialInviteTask = nil
        socialRoomTask = nil
        guard let socialChannel else { return }
        _ = await socialChannel.unsubscribe()
        _ = await service.client.removeChannel(socialChannel)
        self.socialChannel = nil
    }

    nonisolated struct UserPresence: Codable, Sendable {
        let userId: String
    }

    func trackPresence(userID: UUID, onPresenceChange: @escaping @MainActor (Set<UUID>) -> Void) {
        presenceTask?.cancel()
        presenceTask = Task {
            await unsubscribeFromPresence()
            let channel = service.client.channel("online-presence")
            presenceChannel = channel

            let presenceChanges = channel.presenceChange()
            try? await channel.subscribeWithError()
            try? await channel.track(UserPresence(userId: userID.uuidString))

            for await action in presenceChanges {
                let joinedIDs: [UUID] = (try? action.decodeJoins(as: UserPresence.self))?.compactMap { UUID(uuidString: $0.userId) } ?? []
                let leftIDs: [UUID] = (try? action.decodeLeaves(as: UserPresence.self))?.compactMap { UUID(uuidString: $0.userId) } ?? []
                for id in joinedIDs {
                    self.onlineUserIDs.insert(id)
                }
                for id in leftIDs {
                    self.onlineUserIDs.remove(id)
                }
                await onPresenceChange(self.onlineUserIDs)
            }
        }
    }

    func untrackPresence() async {
        presenceTask?.cancel()
        presenceTask = nil
        guard let presenceChannel else { return }
        await presenceChannel.untrack()
        _ = await presenceChannel.unsubscribe()
        _ = await service.client.removeChannel(presenceChannel)
        self.presenceChannel = nil
        onlineUserIDs = []
    }

    private func unsubscribeFromPresence() async {
        guard let presenceChannel else { return }
        await presenceChannel.untrack()
        _ = await presenceChannel.unsubscribe()
        _ = await service.client.removeChannel(presenceChannel)
        self.presenceChannel = nil
    }
}
