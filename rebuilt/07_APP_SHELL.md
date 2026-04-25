# 07 — App Shell, Splash, Connection Banner, Tabs

## App entry — `App8PartyPlayApp.swift`
See file 02 for boilerplate. Key points:
- Owns `AppViewModel` and `StoreViewModel` as `@State`.
- Configures `Purchases` in `init()`.
- WindowGroup hosts `ContentView(appModel:, store:)` with `.preferredColorScheme(.dark)` and `.tint(.blue)`.
- `.onOpenURL` extracts an invite code (custom `invite://?code=…` or `https://(www|app).8partyplay.com/invite?code=…`) and calls `appModel.setPendingInviteCode(code)`. Anything else with the OAuth callback scheme goes to `appModel.handleOAuthCallback(url)`.
- `.onChange(of: scenePhase)` → `appModel.handleScenePhaseChange(to:)`.

## ContentView routing
```
isCheckingSession → SplashView
!hasCompletedOnboarding → OnboardingView
isAuthenticated → MainTabView
else → AuthView (showCloseButton: false)
```
Connection banner is overlaid on top when `appModel.connectionState` is `.reconnecting` or `.disconnected`.

Animations: `.spring(0.3)` on connectionState, `.smooth` on isAuthenticated / isCheckingSession / hasCompletedOnboarding.

`onAppear` wires `store.onStarsGranted = { amount, tier, periodKey, expiresAt in appModel.grantSubscriptionStars(...) }` and `store.onStarPackPurchased = { amount, productID in appModel.grantPurchasedStars(...) }`. Then `appModel.checkForRejoinableSession()`.

Two alerts at root:
- "Rejoin Game?" — shown when a previous in-progress session exists. Buttons: Rejoin / Dismiss.
- "Host Left" — shown when the host leaves a multiplayer session.

## SplashView
Centered `gamecontroller.fill` 52pt with blue→indigo linearGradient, `8PartyPlay` viral title 36/.black, subtle `ProgressView`. Spring entry animation.

## ConnectionBannerView
Single-line top banner, white text on orange (.reconnecting) or red (.disconnected). Fixed height, never blocks tab bar.

## MainTabView
Four `Tab` items in this order (system tab bar):
1. **Games** — `gamecontroller.fill`, value `.home`. Hosts `HomeRootView` (NavigationStack with `HomeRoute`).
2. **Tools** — `wrench.and.screwdriver.fill`, value `.cards`. Hosts `CardsRootView`.
3. **Friends** — `person.2.fill`, value `.social`. Hosts `SocialRootView`. Shows badge = `appModel.requests.count`.
4. **Factory** — `wand.and.stars`, value `.generator`. Hosts `GeneratorView`.

Tab change behaviour:
- Plays `SoundManager.shared.playTabSwitch()`.
- Setting `appModel.selectedTab = .home` resets navigation path + library tab via two `UUID` reset IDs.

Profile sheet:
- `@State isShowingProfile`; passed as `showProfile` closure to every tab. Sheet body = `ProfileView(appModel:, store:)`.
- `onDismiss` clears `appModel.profileContextGame`.

Active session full-screen cover:
- `.fullScreenCover(item: appModel.activeSession)` → `GameSessionView(appModel:, sessionID:)`. The session view internally routes to one of the per-game session views.

Toast overlay applied with `.toastOverlay(appModel:)` modifier (file 30 covers the implementation).

## SocialRootView header
Persistent custom header (toolbar hidden):
- Title "Friends" (viralTitleStyle 20/.black).
- If `requests.count > 0`, orange `bell.badge.fill` + count pill.
- Trailing `ProfileToolbarButton`.

## HomeRootView
NavigationStack with `[HomeRoute]` path. Destinations:
- `.game(GameType)` → `GameDetailView`.
- `.imposterStyleSelection` → `ImposterStyleSelectionView`.
- `.imposterGame(GameType, ImposterGameStyle)` → `ImposterGameDetailView`.
- `.lobby(GameRoom)` → `WaitingRoomView`.
On `navigationResetID` change, `path.removeAll()`.

## CardsRootView
Hosts the Tools tab content (Cards on top, Tools grid below or in segmented sub-pages). See file 22.

## SocialRootView paths
NavigationStack with `[LobbyRoute]`. Destinations:
- `.online(GameType)` → `CasualCreateRoomView`.
- `.room(GameRoom)` → `WaitingRoomView`.
