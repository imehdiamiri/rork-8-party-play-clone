import Foundation

extension AppViewModel {
    var starsBalance: Int { starWallet.balance }

    var hasPremiumAccess: Bool {
        subscription.hasPremiumAccess
    }

    func unlockStatus(for game: GameType) -> GameUnlockStatus {
        if game.isFreeForever { return .free }
        if !game.isPremium { return .free }
        if hasPremiumAccess { return .subscriberUnlocked }
        return .trialUsed
    }

    func canPlayGame(_ game: GameType) -> Bool {
        unlockStatus(for: game).canPlay
    }

    func purchaseGameUnlock(game: GameType) {
        economyFeedback = EconomyFeedback(
            title: "Premium Game",
            message: "Subscribe or get Lifetime access to unlock \(game.name).",
            style: .info
        )
    }

    func claimDailyReward() {
        guard currentUserID != nil, !isProcessingWalletAction else { return }
        isProcessingWalletAction = true
        Task {
            defer { isProcessingWalletAction = false }
            do {
                let amount = try await databaseService.claimDailyReward()
                try await refreshDashboardData()
                if amount > 0 {
                    economyFeedback = EconomyFeedback(title: "+\(amount) Stars", message: "Daily reward claimed.", style: .success)
                    FeedbackService.shared.playSuccess()
                } else {
                    economyFeedback = EconomyFeedback(title: "Already Claimed", message: "Come back tomorrow for more Stars.", style: .info)
                }
            } catch {
                economyFeedback = EconomyFeedback(title: "Couldn\u{2019}t Claim", message: error.localizedDescription, style: .error)
            }
        }
    }

    func grantPurchasedStars(amount: Int, productID: String) {
        guard amount > 0, currentUserID != nil else { return }
        Task {
            do {
                let granted = try await databaseService.grantPurchasedStars(amount: amount, productID: productID, idempotencyKey: UUID())
                try await refreshDashboardData()
                if granted > 0 {
                    economyFeedback = EconomyFeedback(title: "+\(granted) Stars", message: "Star pack delivered.", style: .success)
                    FeedbackService.shared.playSuccess()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func grantSubscriptionStars(amount: Int, tier: SubscriptionTier, periodKey: String, expiresAt: Date?) {
        guard amount > 0, currentUserID != nil else { return }
        Task {
            do {
                let granted = try await databaseService.grantSubscriptionStars(
                    amount: amount,
                    tier: tier.rawValue,
                    periodKey: periodKey,
                    expiresAt: expiresAt
                )
                try await refreshDashboardData()
                if granted > 0 {
                    economyFeedback = EconomyFeedback(title: "Stars Received!", message: "+\(granted) Stars from your subscription.", style: .success)
                    FeedbackService.shared.playSuccess()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearEconomyFeedback() {
        economyFeedback = nil
    }
}
