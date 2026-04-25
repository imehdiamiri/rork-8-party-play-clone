# 23 — Cards Decks + AI Card Generator

Files: `Views/CardsView.swift`, `Views/AICardGeneratorView.swift`, `Models/CardModels.swift`.

## Categories (`CardCategory`)
Five top-level categories — Act / Talk / Challenges / Penalty / Couple.

## Subtypes (`CardSubtype`)
The actual subdivision is **not** Mild / Spicy / Adult. It is a richer `CardSubtype` enum with 15+ specific values: pantomime, dare, funnyAction, starters, personal, discussion, truth, explainGuess, icebreaker, speech, behavior, timeLimit, penaltyFunny, embarrassing, groupChoice, coupleQuestions, dynamics, playful, …

`CardCategory.subtypes` returns the valid subtypes for each category.

## Card model
Defined in `Models/CardModels.swift`. Includes `isPremium: Bool` and a separate `Flag` enum (`.normal / .spicy`). There is **no `CardIntensity (mild/spicy/adult)` enum and no 18+ adult-pack gate.**

## AI Card Generator — `AICardGeneratorView`
Triggered from the cards UI. Generates **one card at a time** (single-card UI; no count picker, no batch generation, no JSON-array response shape).

### UI
- Category picker.
- **Subtype picker** (driven by the selected category's `CardCategory.subtypes`).
- `topic: String` free-text field.
- Generate button.

### Quota
- `static let freeDailyLimit: Int = 5` generations/day for free users (not 10).

### Moderation
`AIContentModeration.isSafe(_:)` is applied to **user input** before sending to the AI proxy. Unsafe input is rejected before the network call.

### Cost
Costs stars to generate. On failure ("Not enough Stars"), `economyFeedback` is set to "You need {cost} ★ to generate a card." (this is the only real spend path for stars in the app).

### Compliance
The top of `AICardGeneratorView.swift` carries an "App Store compliance" comment block documenting the moderation policy.
