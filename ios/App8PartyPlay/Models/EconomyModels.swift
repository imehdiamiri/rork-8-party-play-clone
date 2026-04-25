import Foundation
import SwiftUI

nonisolated enum StarTransactionType: String, CaseIterable, Hashable, Sendable {
    case purchase = "purchase"
    case dailyReward = "daily_reward"
    case subscriptionReward = "subscription_reward"
    case inviteReward = "invite_reward"
    case signupBonus = "signup_bonus"
    case refund = "refund"
    case adminAdjustment = "admin_adjustment"

    init?(rawValue: String) {
        switch rawValue {
        case "purchase": self = .purchase
        case "daily_reward", "dailyReward": self = .dailyReward
        case "subscription_reward", "subscriptionReward", "subscription_grant", "subscriptionGrant": self = .subscriptionReward
        case "invite_reward", "inviteReward": self = .inviteReward
        case "signup_bonus", "signupBonus": self = .signupBonus
        case "refund": self = .refund
        case "admin_adjustment", "adminAdjustment": self = .adminAdjustment
        default: return nil
        }
    }

    var displayTitle: String {
        switch self {
        case .purchase: return "Star Pack"
        case .dailyReward: return "Daily Reward"
        case .subscriptionReward: return "Subscription Bonus"
        case .inviteReward: return "Invite Reward"
        case .signupBonus: return "Sign-up Bonus"
        case .refund: return "Refund"
        case .adminAdjustment: return "Adjustment"
        }
    }

    var icon: String {
        switch self {
        case .purchase: return "creditcard.fill"
        case .dailyReward: return "sun.max.fill"
        case .subscriptionReward: return "crown.fill"
        case .inviteReward: return "gift.fill"
        case .signupBonus: return "sparkles"
        case .refund: return "arrow.uturn.backward"
        case .adminAdjustment: return "wrench.and.screwdriver.fill"
        }
    }

    var tint: Color {
        switch self {
        case .purchase: return .blue
        case .dailyReward: return .green
        case .subscriptionReward: return .indigo
        case .inviteReward: return .pink
        case .signupBonus: return .yellow
        case .refund: return .cyan
        case .adminAdjustment: return .gray
        }
    }
}

nonisolated struct StarTransaction: Identifiable, Hashable, Sendable {
    let id: UUID
    let amount: Int
    let type: StarTransactionType
    let description: String
    let referenceID: UUID?
    let timestamp: Date?

    init(id: UUID = UUID(), amount: Int, type: StarTransactionType, description: String, referenceID: UUID? = nil, timestamp: Date? = nil) {
        self.id = id
        self.amount = amount
        self.type = type
        self.description = description
        self.referenceID = referenceID
        self.timestamp = timestamp
    }

    var isPositive: Bool { amount >= 0 }
}

nonisolated struct StarWallet: Hashable, Sendable {
    let balance: Int
    let transactions: [StarTransaction]

    init(balance: Int = 0, transactions: [StarTransaction] = []) {
        self.balance = balance
        self.transactions = transactions
    }

    var recentTransactions: [StarTransaction] {
        Array(transactions.prefix(20))
    }
}

nonisolated enum GameUnlockStatus: Hashable, Sendable {
    case free
    case trialAvailable
    case trialUsed
    case unlocked
    case subscriberUnlocked

    var canPlay: Bool {
        switch self {
        case .free, .trialAvailable, .unlocked, .subscriberUnlocked: return true
        case .trialUsed: return false
        }
    }

    var displayLabel: String {
        switch self {
        case .free: return "Free"
        case .trialAvailable: return "Free Trial"
        case .trialUsed: return "Locked"
        case .unlocked: return "Unlocked"
        case .subscriberUnlocked: return "Pro Access"
        }
    }

    var icon: String {
        switch self {
        case .free: return "checkmark.circle.fill"
        case .trialAvailable: return "play.circle.fill"
        case .trialUsed: return "lock.fill"
        case .unlocked: return "lock.open.fill"
        case .subscriberUnlocked: return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .free: return .green
        case .trialAvailable: return .blue
        case .trialUsed: return .orange
        case .unlocked: return .green
        case .subscriberUnlocked: return .purple
        }
    }
}

nonisolated struct GameUnlockInfo: Identifiable, Hashable, Sendable {
    let id: String
    let gameKey: String
    let gameName: String
    let unlockCostStars: Int
    let isFreeForever: Bool
    let hasFreeTrial: Bool
    let status: GameUnlockStatus

    init(gameKey: String, gameName: String, unlockCostStars: Int = 50, isFreeForever: Bool = false, hasFreeTrial: Bool = true, status: GameUnlockStatus = .trialAvailable) {
        self.id = gameKey
        self.gameKey = gameKey
        self.gameName = gameName
        self.unlockCostStars = unlockCostStars
        self.isFreeForever = isFreeForever
        self.hasFreeTrial = hasFreeTrial
        self.status = status
    }
}

nonisolated enum SubscriptionTier: String, CaseIterable, Identifiable, Hashable, Sendable {
    case weekly
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var starsPerPeriod: Int {
        switch self {
        case .weekly: return 40
        case .monthly: return 120
        case .yearly: return 500
        case .lifetime: return 500
        }
    }

    var monthlyStarGrant: Int { starsPerPeriod }

    var features: [String] {
        [
            "\(starsPerPeriod) Stars per period",
            "All premium games unlocked",
            "Support ongoing development"
        ]
    }

    var accentColor: Color {
        switch self {
        case .weekly: return .blue
        case .monthly: return .orange
        case .yearly: return .purple
        case .lifetime: return .pink
        }
    }

    var icon: String {
        switch self {
        case .lifetime: return "infinity.circle.fill"
        default: return "star.circle.fill"
        }
    }

    static func detect(from productIdentifier: String) -> SubscriptionTier {
        let id = productIdentifier.lowercased()
        if id.contains("lifetime") { return .lifetime }
        if id.contains("year") || id.contains("annual") { return .yearly }
        if id.contains("week") { return .weekly }
        return .monthly
    }
}

nonisolated struct UserSubscription: Hashable, Sendable {
    let tier: SubscriptionTier?
    let isActive: Bool
    let isLifetime: Bool
    let expiresAt: Date?
    let autoRenews: Bool
    let lastStarGrantDate: Date?

    init(tier: SubscriptionTier? = nil, isActive: Bool = false, isLifetime: Bool = false, expiresAt: Date? = nil, autoRenews: Bool = false, lastStarGrantDate: Date? = nil) {
        self.tier = tier
        self.isActive = isActive
        self.isLifetime = isLifetime
        self.expiresAt = expiresAt
        self.autoRenews = autoRenews
        self.lastStarGrantDate = lastStarGrantDate
    }

    var hasPremiumAccess: Bool { isActive || isLifetime }
    var monthlyStars: Int { tier?.monthlyStarGrant ?? 0 }
    var displayTier: String { tier?.displayName ?? "None" }

    static let none = UserSubscription()
}



nonisolated struct RewardPolicy: Hashable, Sendable {
    let gameKey: String
    let starsForParticipation: Int
    let starsForWin: Int
    let minimumMatchDurationSeconds: Int
    let minimumActionsRequired: Int

    init(
        gameKey: String,
        starsForParticipation: Int = 0,
        starsForWin: Int = 0,
        minimumMatchDurationSeconds: Int = 30,
        minimumActionsRequired: Int = 1
    ) {
        self.gameKey = gameKey
        self.starsForParticipation = starsForParticipation
        self.starsForWin = starsForWin
        self.minimumMatchDurationSeconds = minimumMatchDurationSeconds
        self.minimumActionsRequired = minimumActionsRequired
    }

    static let defaultPolicy = RewardPolicy(gameKey: "default")
}
