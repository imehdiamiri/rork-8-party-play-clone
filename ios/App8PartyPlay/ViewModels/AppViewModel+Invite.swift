import Foundation

extension AppViewModel {
    var inviteShareLink: String {
        let code = inviteCode.isEmpty ? "" : inviteCode
        return "https://www.8partyplay.com/invite?code=\(code)"
    }

    var inviteShareMessage: String {
        "Join me on 8PartyPlay \u{1F3AE} — use my invite code \(inviteCode) to get +10 \u{2605}: \(inviteShareLink)"
    }

    func setPendingInviteCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        if currentUserID != nil {
            redeemInviteCode(trimmed)
        } else {
            pendingInviteCode = trimmed
        }
    }

    func redeemInviteCode(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty, !isRedeemingInvite, currentUserID != nil else { return }
        isRedeemingInvite = true
        Task {
            defer { isRedeemingInvite = false }
            do {
                let response = try await databaseService.redeemInviteCode(code)
                if response.ok {
                    let amount = response.inviteeReward ?? 0
                    try? await refreshDashboardData()
                    economyFeedback = EconomyFeedback(
                        title: amount > 0 ? "+\(amount) Stars" : "Invite Applied",
                        message: "Welcome bonus from your friend.",
                        style: .success
                    )
                    FeedbackService.shared.playSuccess()
                } else {
                    economyFeedback = EconomyFeedback(
                        title: "Invite Not Applied",
                        message: inviteFailureMessage(response.reason),
                        style: .warning
                    )
                }
            } catch {
                economyFeedback = EconomyFeedback(title: "Invite Failed", message: error.localizedDescription, style: .error)
            }
        }
    }

    func inviteFailureMessage(_ reason: String?) -> String {
        switch reason {
        case "already_redeemed": return "You\u{2019}ve already used an invite code."
        case "invalid_code": return "That code doesn\u{2019}t match any account."
        case "self_invite": return "You can\u{2019}t invite yourself."
        case "account_too_old": return "Invite codes can only be redeemed by new accounts."
        case "inviter_daily_limit": return "Your friend has reached today\u{2019}s invite limit."
        case "empty_code": return "Enter a valid invite code."
        default: return "Couldn\u{2019}t apply invite. Please try again."
        }
    }
}
