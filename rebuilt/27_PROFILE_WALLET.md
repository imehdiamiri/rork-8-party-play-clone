# 27 — Profile Sheet & Wallet

`ProfileView` and `WalletView` are **two separate views** in `Views/MainTabView.swift`. They are not tabs inside a single sheet; there is no "Profile | Wallet" tab UI.

## Profile sheet — `ProfileView`
Presented as `.sheet(isPresented: $isShowingProfile)` from any tab.

- Header avatar — driven primarily by `appModel.avatarSymbol` (an SF Symbol picker), not photo upload.
- Username / display name — editable via `set_username` RPC.
- Public ID rendered as `"ID #\(publicID)"`.
- Email + provider pill (Apple / Username / Guest — no Google provider).
- Settings list (SurfaceCards): Sound effects, Haptics, Notifications, Privacy / Terms, Restore Purchases, Sign out / Delete account.

## Wallet — `WalletView`
ScrollView. Order in `WalletView.body`:

1. **walletHeader** — title "Wallet" + `ProfileToolbarButton`.
2. **starBalanceHero** — `Text("\(balance)").font(.system(size: 52, weight: .bold, design: .rounded))` (size **52**, `.bold`, `.rounded` — not `viralTitleStyle 56/.black`). Subtitle "Stars balance" with caption "Stars are used for AI-generated cards." This card is **not tappable** — there is no `.onTapGesture`.
3. **feedbackCard** — appears conditionally when `appModel.economyFeedback != nil`.
4. **membershipCard** — shows `UserSubscription`. Renders a `planRow` per tier (weekly/monthly/yearly/lifetime) with hard-coded prices ($4.99 / $6.99 / $29.99 / $49.99) directly inside the card.
5. **starEconomyCard** — explainer rows. The Daily Reward source-row text is `"+10 ★ every day"` (icon `sun.max.fill`, green).
6. **starSourcesCard** — list of star packs.
7. **inviteFriendsCard** — `gift.fill` pink tile, title "Invite Friends", caption "Earn +30 ★ when a friend joins." Tap opens `InviteView`.
8. **historySection** — last 20 `StarTransaction`s.
9. **restorePurchasesRow** — `Button("Restore Purchases")` calls the store restore method.

## Daily reward
Server-tracked. `claimDailyReward()` RPC; UI refreshes claimable state on `scenePhase == .active`.

## Invite Friends — `InviteView`
- Big invite code (the user's invite code).
- `ShareLink` with message: `"Join me on 8PartyPlay 🎮 — use my invite code \(inviteCode) to get +10 ★: \(inviteShareLink)"`.
- "How it works" explainer.
