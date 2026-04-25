# 08 — Onboarding

Three full-screen pages in a `TabView(selection: $currentPage)` styled `.page(indexDisplayMode: .never)`. Animations: `.spring(0.45, 0.85)` on page change. `AppBackgroundView` behind everything. Bottom controls in their own VStack.

## Page 1 — Welcome (tag 0)
- 200pt blurred radial gradient halo (blue→indigo→clear) with 30pt blur.
- `gamecontroller.fill` 68pt with blue→cyan linearGradient + `.symbolEffect(.bounce, value: currentPage == 0)` + blue 50% shadow radius 20 y 8.
- "Welcome to" — `.title2 .medium .secondary`.
- "8PartyPlay" — viralTitleStyle 38/.black, white→90% white linearGradient fill, lineLimit 1.
- Body: `"The ultimate party game collection.\nPlay with friends, compete, and have fun!"` — `.body .secondary`, 4pt line spacing, 4pt top.
- Initial `appeared` animation slides content up 30pt with opacity 0→1.

## Page 2 — Showcase (tag 1)
- Same halo but green→mint→clear.
- `sparkles` 68pt with green→mint linearGradient + bounce + green shadow.
- Eyebrow: "All the Viral Games" 34pt heavy rounded green→mint linearGradient.
- "In One Place" `.title .bold .white`.
- Body copy: `"Every trending party game you've seen on social media — ready to play instantly with your friends. No setup needed."`.
- Three feature pills (icon 20pt + text caption .semibold):
  - `person.3.fill` "Multiplayer"
  - `iphone` "One Device"
  - `bolt.fill` "Instant"
  All pills mint colored.

## Page 3 — Name entry (tag 2)
- Smaller halo (180pt) purple→pink.
- `person.crop.circle.badge.plus` 60pt purple→pink linearGradient with bounce.
- Title `.title .bold` "What's Your Name?".
- Body: `"This will be your default player name in party games."`.
- `TextField` placeholder `"Enter your name"` with 30% white prompt color, .title3 .semibold white text, multiline-aligned center, 16/24 padding, ultraThinMaterial 60% bg, 16-rounded with purple 50%→pink 30% gradient stroke 1.5pt. `textInputAutocapitalization(.words)`, `autocorrectionDisabled`, submitLabel `.done` ⇒ resign focus. After `appear`, focus the field 0.5s later.
- Caption: "You can change this anytime" `.tertiary`.

## Bottom controls (always visible)
- 3 capsule indicators (8pt high, 8pt wide unfilled, 28pt active) with `.spring(0.3)` size animation.
- Pages 0–1: right-aligned `Next` button — text + `chevron.right`, 28/13 padding, blue capsule. Plays `SoundManager.shared.playNavigation()`.
- Page 2: full-width `Let's Play!` button with `play.fill` icon, 16pt vertical padding, purple→pink linearGradient (or grey if name <2 chars), 12pt purple shadow @ 40%. Disabled until trimmedName.count >= 2.
- On final tap: dismiss keyboard, play `SoundManager.shared.playGameStart()`, call `onComplete(trimmedName)` which executes `appModel.completeOnboarding(playerName:)` and triggers a background notification permission prompt (`NotificationService.shared.requestPermission()`).

## State flag
`appModel.hasCompletedOnboarding: Bool` — `false` initially, persisted via `UserDefaults` once `completeOnboarding` runs. Once `true`, the user is sent to `AuthView` (or `MainTabView` if they're already signed in / continuing as guest from a previous launch).
