# 27 — Profile Sheet & Wallet

`ProfileView` is presented as a sheet from any tab. It contains tabs: **Profile** | **Wallet**. Implemented in `Views/MainTabView.swift` (ProfileView) and `WalletView`.

## Profile tab
- Header avatar (108pt circle): user's uploaded image or a SF symbol fallback. Tap → PhotosPicker → uploads to Supabase Storage `avatars/{uid}.jpg` and stores URL in `profiles.avatar_url`.
- Username (display name) — viralTitleStyle 22/.black. Edit pencil → inline TextField with `set_username` RPC.
- Public ID `#1234567` caption.
- Email (if account-bound) caption .secondary.
- "Provider" pill: Apple / Google / Username / Guest.
- **Settings list** (SurfaceCards):
  - **Sound effects** toggle (`SoundManager.shared.isEnabled`, persisted).
  - **Haptics** toggle (`FeedbackService.shared.isEnabled`).
  - **Adult cards (18+)** toggle.
  - **Notifications** row → opens iOS Settings via deep link if denied.
  - **Restore Purchases** row (in Wallet tab too).
  - **Privacy Policy** / **Terms of Service** Links.
- **Account** section:
  - **Sign out** (only when not guest).
  - **Delete account** (red, confirmation alert) → calls `auth.deleteAccount()`.
  - **Continue as Guest → Sign in** if guest (opens AuthView sheet).
- **App info** footer: version, build number, project ID, marketing site link.

## Wallet — `WalletView`
ScrollView with the following blocks (in order):

1. **Wallet header** — title "Wallet" + ProfileToolbarButton trailing.
2. **Star balance hero** — big ☆ icon + viralTitleStyle 56/.black showing balance, subtitle "Stars". Tap on this card opens the **Star Pack** purchase sheet.
3. **Economy feedback card** (conditional) — appears when `appModel.economyFeedback != nil`. Shows title + message with style-tinted icon. Auto-dismiss after 4s.
4. **Membership card** — shows current `UserSubscription`:
   - If active: tier name + "Active until {date}" + "Manage" button → opens iOS subscription management URL.
   - If lifetime: "Lifetime ✦" + crown icon, no expiry.
   - If none: "Upgrade to Pro" CTA → presents `PaywallView`.
5. **Star economy card** — explains how to earn stars: Daily Reward (sun.max.fill green) — auto-claimable button "Claim {N} ★", greyed out if cooldown active. Sign-up Bonus (`sparkles` yellow). Subscription Bonus. Invite Reward.
6. **Star sources card** — list of star packs (e.g. 100 / 500 / 1500 / 5000 stars) with prices. Tap to open `PurchaseDetailView`.
7. **Invite Friends card** — `gift.fill` pink tile + title "Invite Friends" + caption "Earn +30 ★ when a friend joins." Tap opens `InviteView`.
8. **History section** — last 20 `StarTransaction`s. Each row: type icon + title (e.g. "Daily Reward") + amount (+5 ★ green / -100 ★ red) + relative date.
9. **Restore purchases row** — `Button("Restore Purchases")` calls `store.restore()` and shows toast.

## Daily reward logic
- `last_daily_claim_at` tracked server-side. Cooldown 22h.
- App refreshes claimable state on `scenePhase == .active`.
- Tapping Claim calls `claim_daily_reward` RPC → success grants stars and inserts a `star_transaction`.

## Invite Friends — `InviteView`
- Big invite code (user's public ID).
- ShareLink with deep link `https://www.8partyplay.com/invite?code={publicID}` and message "Join me on 8PartyPlay! Use my code {code} to get bonus stars."
- "How it works" 3-step explainer.
- List of accepted invitees with their joined-date and reward status.
