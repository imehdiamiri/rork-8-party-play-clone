# 28 — Economy, Subscriptions, Paywall

Files: `Models/EconomyModels.swift`, `ViewModels/StoreViewModel.swift`, `ViewModels/AppViewModel+Economy.swift`, `Views/PaywallView.swift`, `Views/PurchaseDetailView.swift`.

## Stars
Single soft-currency. Stored server-side (`stars_balance.balance`) with a local mirror in `appModel.starWallet`.

### Earn paths
- **Sign-up bonus**: 100 ★ once per account (`signupBonus` transaction).
- **Daily reward**: 5 ★ once per ~22h.
- **Subscription bonus**: per `SubscriptionTier.starsPerPeriod` (40 weekly / 120 monthly / 500 yearly / 500 lifetime one-time).
- **Invite reward**: 30 ★ when an invitee uses your code.
- **Star Pack purchase**: real money via RevenueCat consumable products.

### Spend paths
There are no in-app spending paths today. Stars are kept as a "satisfaction currency" / future-use balance. Premium games are unlocked via subscription, not stars. (The `unlockCostStars` field on `GameType` exists for future use; do not surface it as a spend mechanism in UI yet.)

## Subscriptions (RevenueCat)
- Configure in `App8PartyPlayApp.init()`: `Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)`.
- Tiers: `weekly`, `monthly`, `yearly`, `lifetime` (lifetime is a non-consumable). Detect tier from product identifier substring.
- `StoreViewModel`:
  - `start()` — fetches current `Offerings` and subscribes to `customerInfo` updates.
  - `currentEntitlement: EntitlementInfo?`.
  - `purchase(_ package:)` — calls `Purchases.shared.purchase(package:)`.
  - `restore()` — `Purchases.shared.restorePurchases()`.
  - Fires `onStarsGranted(amount, tier, periodKey, expiresAt)` whenever a new subscription period starts (period key = `expiresAt.formatted("yyyy-MM")` for monthly, `yyyy-WW` for weekly, etc., to dedupe). Persists last granted period in `UserDefaults`.
  - Fires `onStarPackPurchased(amount, productID)` for consumables.

## `AppViewModel+Economy`
- `grantSubscriptionStars(amount, tier, periodKey, expiresAt)` — calls `record_subscription_event` RPC; updates local wallet; shows green toast.
- `grantPurchasedStars(amount, productID)` — calls `record_star_pack_purchase` RPC.
- `claimDailyReward()` — RPC + UI feedback.
- `applyInviteCode(_ code: String)` — RPC; updates local balance.
- `economyFeedback` — `EconomyFeedback?` for the wallet card.

## Paywall — `PaywallView`
Full screen sheet. Hero: "Go Pro" 38pt black gradient + 3 feature bullets:
- 🎮 All premium games unlocked
- ✦ Free stars every period
- 💖 Support ongoing development

Three product cards in a vertical stack:
1. **Yearly** — best value badge "Save 50%". Big price + monthly equivalent. Selected by default.
2. **Monthly**.
3. **Weekly**.
Plus a "Lifetime" full-width banner at the bottom.

Selected card has 2pt blue stroke + 18% blue bg. Tap to switch.

Bottom: PrimaryActionButtonStyle "Continue" (calls `store.purchase(selectedPackage)`). Restore Purchases button + Privacy / Terms links.

State while purchasing: spinner overlay, button disabled. On success: dismiss + "🎉 Welcome to Pro!" toast. On failure: inline red error.

## Star Pack purchase — `PurchaseDetailView`
Sheet with selected pack details (name, amount, price), a single Buy button, and Terms/Privacy links. Calls `store.purchase(starPackPackage)`.

## Premium gating
A game is playable when:
- `game.isFreeForever == true`, OR
- `appModel.subscription.hasPremiumAccess == true`, OR
- `game.hasFreeTrial == true` and the trial hasn't been used (currently no game has trial; reserved field).

If none, `appModel.canPlayGame(_:)` returns false; the home grid shows a `lock.fill` overlay; tapping the card opens the GameDetail with the lock CTA → PaywallView.
