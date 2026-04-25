# 28 — Economy, Subscriptions, Paywall

Files: `Models/EconomyModels.swift`, `ViewModels/StoreViewModel.swift`, `ViewModels/AppViewModel+Economy.swift`, `Views/PaywallView.swift`, `Views/PurchaseDetailView.swift`.

## Stars
Single soft-currency. Stored server-side (`stars_balance.balance`) with a local mirror in `appModel.starWallet`.

### Earn paths
- **Sign-up bonus** once per account.
- **Daily reward** — server-side cooldown.
- **Subscription bonus** — `SubscriptionTier.starsPerPeriod`: weekly 40 / monthly 120 / yearly 500 / lifetime 500.
- **Invite reward** — +30 ★ when an invitee uses your code.
- **Star Pack purchase** — RevenueCat consumables.

### Spend paths
**Stars are spent on AI-generated cards.** `AICardGeneratorView` charges stars per generation; insufficient balance produces `economyFeedback = "Not enough Stars / You need \(cost) ★ to generate a card."`. This is the only spend path today.

`GameType.unlockCostStars` exists in the model but is not surfaced as a spend mechanism in the UI. Premium games are unlocked via subscription, not stars.

## Subscriptions (RevenueCat)
- Configure with `Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)`.
- Tiers: `.weekly / .monthly / .yearly / .lifetime` (`SubscriptionTier`). Lifetime is non-consumable. `SubscriptionTier.detect(from productIdentifier: String)` infers tier from the product ID substring.
- `StoreViewModel.start()` fetches Offerings and subscribes to `customerInfo` updates.
- `purchase(_ package:)` and `restore()` wrap the corresponding RevenueCat calls.
- `SubscriptionTier.features` returns `["{starsPerPeriod} Stars per period", "All premium games unlocked", "Support ongoing development"]`.

## `AppViewModel+Economy`
- `grantSubscriptionStars(...)`, `grantPurchasedStars(...)`, `claimDailyReward()`, `applyInviteCode(_ code:)`.
- `economyFeedback: EconomyFeedback?` drives the wallet feedback card.

## `StarTransactionType.subscriptionReward`
Decodes from multiple aliases: `"subscription_reward"`, `"subscriptionReward"`, `"subscription_grant"`, `"subscriptionGrant"` for legacy server data.

## `GameUnlockStatus`
Cases: `free, trialAvailable, trialUsed, unlocked, subscriberUnlocked` (the last has a crown icon and purple tint, distinct from regular `.unlocked`).

## Paywall — `PaywallView`
Has a tabbed layout including subscription tiers and **Star Packs** (`enum tab { case stars = "Star Packs" }`). Tier cards, Continue (calls `store.purchase(...)`), Restore, Privacy / Terms.

## Star Pack purchase — `PurchaseDetailView`
Sheet driven by `PurchaseSelection.starPack(stars: Int)` for consumable star packs.

## Premium gating
A game is playable when:
- `game.isFreeForever == true`, OR
- `appModel.subscription.hasPremiumAccess == true`, OR
- `game.hasFreeTrial == true` and the trial hasn't been used (currently no game has trial; the field is reserved but always false in the library).

If none, `appModel.canPlayGame(_:)` returns false and `economyFeedback` is set to `"Subscribe to 8PartyPlay+ to unlock \(game.name)."`.

## Dead / unused
- `RewardPolicy` exists in `EconomyModels.swift` but is **never invoked**. No game grants stars on win/participation through it. Treat it as an unused stub.
