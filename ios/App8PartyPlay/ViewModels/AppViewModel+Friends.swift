import Foundation

extension AppViewModel {
    var onlineFriends: [Friend] {
        friends.filter { $0.kind == .online }.map { friend in
            let isReallyOnline = onlineUserIDs.contains(friend.id)
            return Friend(
                id: friend.id,
                name: friend.name,
                isOnline: isReallyOnline,
                status: isReallyOnline ? friend.status : "Offline",
                kind: friend.kind,
                publicUserID: friend.publicUserID,
                avatarURL: friend.avatarURL
            )
        }
    }

    var selectedInviteFriends: [Friend] {
        onlineFriends.filter { invitedOnlineFriendIDs.contains($0.id) }
    }

    func addOfflineFriend(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, offlineFriends.count < 12 else { return }
        guard !offlineFriends.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        offlineFriends.append(Friend(name: trimmed, isOnline: false, status: "Offline player", kind: .offline))
        offlineFriends.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func updateOfflineFriend(_ friend: Friend, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !offlineFriends.contains(where: { $0.id != friend.id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        guard let index = offlineFriends.firstIndex(where: { $0.id == friend.id }) else { return }
        offlineFriends[index] = Friend(id: friend.id, name: trimmed, isOnline: false, status: friend.status, kind: .offline)
        offlineFriends.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func removeOfflineFriend(_ friend: Friend) {
        offlineFriends.removeAll { $0.id == friend.id }
    }

    func searchFriends(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        latestFriendSearchQuery = trimmed
        guard !trimmed.isEmpty else {
            friendSearchResults = []
            isSearchingFriends = false
            return
        }
        guard let currentUserID else {
            friendSearchResults = []
            isSearchingFriends = false
            return
        }
        isSearchingFriends = true
        errorMessage = nil
        Task {
            do {
                let results = try await databaseService.searchProfiles(query: trimmed, currentUserID: currentUserID)
                guard latestFriendSearchQuery == trimmed else { return }
                friendSearchResults = results
                isSearchingFriends = false
            } catch {
                guard latestFriendSearchQuery == trimmed else { return }
                friendSearchResults = []
                isSearchingFriends = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func sendFriendRequest(to result: FriendSearchResult) {
        guard result.relationshipState.isActionable, let currentUserID else { return }
        guard result.id != currentUserID else { return }
        Task {
            do {
                try await databaseService.sendFriendRequest(from: currentUserID, to: result.id)
                friendSearchResults = friendSearchResults.map { item in
                    guard item.id == result.id else { return item }
                    return FriendSearchResult(id: item.id, username: item.username, email: item.email, publicUserID: item.publicUserID, avatarURL: item.avatarURL, relationshipState: .pendingOutgoing)
                }
                try await refreshDashboardData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func acceptRequest(_ request: FriendRequest) {
        Task {
            do {
                try await databaseService.acceptFriendRequest(requestID: request.id)
                try await refreshDashboardData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func declineRequest(_ request: FriendRequest) {
        Task {
            do {
                try await databaseService.declineFriendRequest(requestID: request.id)
                try await refreshDashboardData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
