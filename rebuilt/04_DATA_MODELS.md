# 04 — Data Models

All models live in `Models/`. Every Codable / pure-data type is `nonisolated` (project default actor is `@MainActor`).

## `Models/AppModels.swift` (the big one)

### Auth + nav
- `enum AuthProvider`: `.username, .google, .apple, .guest`.
- `enum AppTab`: `.home, .cards, .social, .generator`.
- `enum AppLanguage`: only `.english = "en"` (display name "English"). No other languages.
- `enum LegalLinks` exposes the privacy / terms URLs from `AppConstants.URLs`.

### Game modes
- `enum GameMode: .singleDevice, .multiDevice, .teamMode`.
  - title: "1 Phone" / "Multi Phone" / "Team Mode"
  - icon: `iphone.gen3` / `apps.iphone` / `person.line.dotted.person.fill`
  - accentColor: `.blue / .green / .purple`.
  - shortLabel: "1-D" / "Multi-D" / "Team"

### `struct GameType: RawRepresentable, Identifiable, Hashable, Sendable`
Stores: `rawValue, name, shortDescription, minPlayers, maxPlayers, unlockCostStars, isFreeForever, hasFreeTrial, isPremium, symbolName, supportedModes, roundDuration, heroImageURL`. Provides `playerCountText` ("min–max players") and `supports(mode:)`.

The static `library` array is the **canonical game list (11 games)**. Exact entries:

| rawValue | name | min/max | symbol | modes | premium | hero URL |
|---|---|---|---|---|---|---|
| `reverse_singing` | Reverse Singing | 2/30 | `backward.fill` | single | no | `…b17e5d76…` |
| `guess_the_seconds` | Guess the Seconds | 2/30 | `stopwatch.fill` | single | no | `…d8092484…` |
| `imposter` | Imposter | 4/30 | `eye.fill` | single | no | `…01a6d899…` |
| `memory_grid` | Memory Grid | 1/30 | `square.grid.3x3.fill` | single+multi+team | no | `…630d9ac5…` |
| `ten_tangle` | Ten Tangle | 3/11 | `theatermasks.fill` | single | yes | `…e877a51b…` |
| `memory_path` | Memory Path | 2/30 | `map.fill` | single+multi+team | yes | `…8f997aac…` |
| `pass_guess` | Pass & Guess | 2/30 | `text.bubble.fill` | single | yes | `…9501d164…` |
| `tap_in_order` | Tap in Order | 1/30 | `number.square.fill` | single+multi | yes | nil |
| `color_trap` | Color Trap | 1/30 | `paintpalette.fill` | single+multi | yes | nil |
| `spin_bottle` | Truth & Dare | 3/12 | `arrow.triangle.2.circlepath` | single | no | nil |
| `draw_rush` | Draw & Rush | 2/12 | `pencil.and.scribble` | single+multi | yes | nil |

`shortDescription` strings are fixed (see Swift model). `roundDuration` (seconds): reverse_singing=75, guess_the_seconds=90, draw_rush=100, others=0.

### Library order (used by HomeView)
`[reverseSinging, guessTheSeconds, imposter, memoryGrid, tenTangle, memoryPath, passGuess, tapInOrder, colorTrap, drawRush, spinBottle]`.

### `GameDefinition { id: GameType, accentName: String }` — the home grid uses this. AppViewModel hard-codes `accentName` per game (e.g. reverse=pink, guess=cyan, imposter=purple, memoryGrid=teal, tenTangle=orange, memoryPath=red, passGuess=yellow, tapInOrder=cyan, colorTrap=pink, drawRush=purple, spinBottle=red).

### Player + room
- `struct PlayerProfile { id, username, isHost, isReady, isOnline, score }`.
- `enum RoomStatus: draft, waiting, full, starting, in_progress, completed, cancelled` with `displayTitle` + `tint`.
- `enum PlayerRoomState: invited, joined, ready, left, kicked`.
- `enum RoomAccess: privateRoom = "private", publicRoom = "public"`.
- `struct GameRoom { id, code (6 chars), game, mode, hostName, players, message, access, invitedFriendIDs, status, minPlayers, maxPlayers }` + `readyCount`, `onlineCount`, `allPlayersReady`, `isFull`.
- `struct RoomInvite` — id, roomID, roomCode, game, hostName, invitedAt, mode.

### Friends
- `enum FriendKind: offline, online`.
- `struct Friend { id, name, isOnline, status, kind, publicUserID, avatarURL }`.
- `enum FriendRelationshipState: none, existing_friend, pending_outgoing, pending_incoming, self` — provides `buttonTitle` (Add / Added / Sent / Pending / You) and `isActionable`.
- `struct FriendSearchResult` (id, username, email, publicUserID, avatarURL, relationshipState).
- `struct FriendRequest`.

### Activity / feedback
- `enum ActivityAction: none, quickJoin, invite, replay`.
- `struct ActivityItem`.
- `enum EconomyFeedbackStyle: success, info, warning, error` + `struct EconomyFeedback { id, title, message, style }`.

### Match + round
- `struct GameRound { id, index, prompt, activePlayerName, targetAnswer?, forbiddenWords, targetSeconds? }`.
- `struct RoundLiveState { guessText, hasStartedTiming, measuredElapsedTime, hasSubmittedTiming, promptVisibleToPerformer }`.
- `struct GameResultRow { id, name, score, rank, starsWon }`.
- `enum MatchPhase: intro, passToNextPlayer, liveRound, roundResult, finished` (each round-trip-converts to/from a `realtimeValue` string).
- `struct GameSession` — id, game, mode, roomCode, players, rounds, currentRoundIndex, phase, secondsRemaining, latestAwardedPoints, latestFeedback, results, liveState, **per-game state**: `passGuessState?, guessTheSecondsState?, memoryGridState?, memoryPathState?, tapInOrderState?, colorTrapState?`, plus `rematchPlayerIDs`, `stateVersion`.

### Per-game state structs (all `nonisolated`, `Hashable`, `Sendable`)

- **Pass & Guess:** `PassGuessSettings(rounds, questionMode, selectedQuestionID?, customQuestion, answerTimeLimit=45, guessTimeLimit=30)`, `enum PassGuessQuestionMode: predefined, custom`, `enum PassGuessRoundPhase: intro, answering, guessing, reveal, leaderboard`, plus `PassGuessQuestion`, `PassGuessAnswer`, `PassGuessVote`, `PassGuessRevealItem`, `PassGuessArchivedRound`, `PassGuessRoundState`.
- **Guess the Seconds:** state is **not** stored in a `GuessTheSecondsGameState` struct on the session — it lives directly on `GuessTheSecondsSessionViewModel` as `activeTurnIndex`, `roundTargets: [Int: Double]`, `results: [TurnResult]`. Computed: `totalTurns = session.rounds.count`, `currentRoundNumber`, `isFirstPlayerOfCurrentRound`. There is no `roundsPerPlayer` or `selectedTime` field on a state struct.
- **Memory Grid:** `enum MemoryGridSize: tiny3x4, small4x4, medium4x5, large5x6, xl6x6` (each maps to (rows, cols, pairCount, tileCount)), `struct MemoryGridSettings { gridSize }`. **Setup default is `tiny3x4`** (the `MemoryGridSettings.teamDefault` constant exists but is not actually wired into the setup view), `MemoryTile`, `MGPlayerResult`, `MGSpectatorTile`, `MGSpectatorSnapshot`, `MemoryGridGameState { gridSize, currentPlayerIndex, playerResults, isFinished, spectator? }`.
- **Memory Path:** `MPPlayerResult`, `MemoryPathGameState`. `MemoryPathGameMode` has only **two** cases: `.timeRace` and `.turnBased` (no `limitedAttempts`, no `onlyOneTry`). Path tiles are stored as `pathTiles` (row/col pairs) plus `startTile` and `endTile`. `MemoryPathPhase`: `setup / countdown / passDevice / turnSwitch / playing / hintActive / finished`.
- **Imposter:** `enum ImposterGameStyle: discussion, clue` (titles & 3-bullet detail lists), `enum ImposterCategoryPack: animals/food/places/jobs/movies/random` with 12 fixed words each, `struct ImposterSettings(gameStyle, rounds=3, discussionDuration=60, categoryPack=.random)`, `enum ImposterPhase: roleReveal, ready, discussion, clueGiving, voting, result`, `struct ImposterRoundState { settings, phase, secretWord, imposterPlayerID, revealedPlayerIDs, readyPlayerIDs, currentCluePlayerIndex, clues, votes, discussionTimeRemaining }`, `ImposterClue`, `ImposterVote`.
- **Tap in Order:** `TapInOrderGameState { variant, gridSize, tileCount, seed, selectedCells, currentPlayerIndex, playerResults, isFinished }`. `TapInOrderVariant`: `.numberMemory, .patternMemory` (no Classic/Hide-after-3/All-hidden). Grid sizes: `[4, 5, 6, 7]`.
- **Color Trap:** `ColorTrapGameState { difficulty, seed, forbiddenColorIndex, currentPlayerIndex, playerResults, isFinished }`. `ColorTrapDifficulty`: `.easy / .medium / .hard` (no slow/normal/fast/extreme). 4 columns, 5-colour palette.

### Team mode
- `struct TeamAssignment { id ("team_a"/"team_b"), name, playerIDs }` with `adding/removing` builders.
- `struct TeamState { teams: [TeamAssignment] }` with `default` (Team A + Team B), helpers `teamA`, `teamB`, `allAssignedPlayerIDs`, `teamFor(playerID:)`, `teammates(of:)`, `opponents(of:)`, `isValid`.

### Routes
- `enum HomeRoute: game(GameType), imposterStyleSelection, imposterGame(GameType, ImposterGameStyle), lobby(GameRoom)`.
- `enum LobbyRoute: online(GameType), room(GameRoom)`.

## `Models/EconomyModels.swift`
- `enum StarTransactionType` (purchase/dailyReward/subscriptionReward/inviteReward/signupBonus/refund/adminAdjustment) with display title/icon/tint.
- `struct StarTransaction { id, amount, type, description, referenceID?, timestamp? }` + `isPositive`.
- `struct StarWallet { balance=0, transactions=[] }` + `recentTransactions` (first 20).
- `enum GameUnlockStatus: free, trialAvailable, trialUsed, unlocked, subscriberUnlocked` (canPlay, label, icon, tint).
- `struct GameUnlockInfo { id, gameKey, gameName, unlockCostStars=50, isFreeForever, hasFreeTrial=true, status }`.
- `enum SubscriptionTier: weekly(40)/monthly(120)/yearly(500)/lifetime(500)` (starsPerPeriod). Provides `displayName`, `accentColor`, `icon`, and `static detect(from productIdentifier:)` heuristic.
- `struct UserSubscription { tier?, isActive, isLifetime, expiresAt?, autoRenews, lastStarGrantDate? }` + `hasPremiumAccess`, `monthlyStars`. `static let none`.
- `struct RewardPolicy(gameKey, starsForParticipation=0, starsForWin=0, minimumMatchDurationSeconds=30, minimumActionsRequired=1)`.

## `Models/CardModels.swift` (decks)
Deck domain for Tools→Cards. Provides categories (Act / Talk / Challenges / Penalty / Couple), card structs, saved/locked state, AI-generated card markers. Loaders return seed decks bundled with the app.

## `Models/CasualRoomModels.swift`
- `struct CasualRoom { id, code, hostID, hostName, game, mode, status, players, message, isPublic, createdAt, updatedAt, version, teamState? }`.
- `enum CasualRoomStatus: waiting, in_progress, completed, cancelled`.
- `struct CasualRoomPlayer { id, name, isHost, isReady, joinedAt, role }`.
- `enum CasualRoomRole: host, joiner`.
- `struct CasualRoomStatePayload` — realtime broadcast envelope for the host to push session/team state to joiners.

## `Models/QuickGameModels.swift`
Defines tutorial/instruction blocks shown at the top of every game's setup screen (`PartyGameTutorial.swift` provides per-game step lists). Also "ideas" cards used in the Home → Ideas tab (`OtherFunView`).

## `Models/DrawRushModels.swift`
Concept lists, drawing modes, single-device round shape, multi-device snapshot encoding (compressed stroke array).

## `Models/MemoryPathModels.swift`
Difficulty enum (easy/medium/hard/expert) → grid size + steps. Game-mode enum: only `.timeRace` and `.turnBased`.

## `Models/SpinBottleModels.swift`
Player list, last-pointed player, dare/truth pack reference.

## `Models/SupabaseModels.swift`
Codable DTOs for every table + RPC payload (Profiles, Friends, FriendRequests, GameResults, StarTransactions, Subscriptions, Sessions, Rooms, RoomPlayers, Realtime broadcast envelopes). Every struct is `nonisolated, Codable, Sendable`. Coding keys snake-case ↔ camelCase.

> Do **not** add fields for XP, levels, fakeAnswer state, hot bomb, wrong-answer, title-it, or `PerformanceBadge`/Reverse-Singing similarity scoring. Those were removed or never built. Do not add a `RewardPolicy` invocation per game — it exists in `EconomyModels.swift` as a stub but is never used.
