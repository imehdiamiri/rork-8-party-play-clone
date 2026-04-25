# 23 — Cards Decks + AI Card Generator

Lives at the top of the Tools tab. Files: `Views/CardsView.swift`, `Views/AICardGeneratorView.swift`, `ViewModels/CardsViewModel.swift`, `Models/CardModels.swift`.

## Categories (fixed)
1. **Act** — physical / acting prompts ("Pretend you're a robot for 30s").
2. **Talk** — conversation / icebreakers ("What's the weirdest food you've eaten?").
3. **Challenges** — group dares / mini-games.
4. **Penalty** — punishments for losers ("Sing the chorus of a song everyone knows").
5. **Couple** — for romantic partners (clean and spicy variants).

Each category has Mild / Spicy / Adult sub-pack, with Adult requiring an 18+ confirmation toggle in the profile (stored in `UserDefaults` as `adultPackUnlocked`).

## Card model
`Card { id: UUID, text: String, category: CardCategory, intensity: CardIntensity (mild/spicy/adult), isAIGenerated: Bool, createdAt: Date }`.

## Layout
1. **Category tabs** — horizontal ScrollView with 5 chips (one per category).
2. **Intensity filter** — segmented Mild / Spicy / Adult (Adult disabled if not unlocked).
3. **Deck stack** — top 3 cards visible (Tinder-style stack with offsets/scales). Drag/swipe horizontally:
   - Swipe right → "Save" (heart icon overlay green).
   - Swipe left → "Skip".
   - Swipe up → "Share" (uses `ShareLink`).
4. **Bottom toolbar** — Saved (`heart.fill`), AI generator (`sparkles`), Settings (`slider.horizontal.3`).

## Saved cards
Persisted to `UserDefaults` (Codable JSON). Tappable list with delete. Re-share or copy.

## AI Card Generator — `AICardGeneratorView`
- Triggered from the toolbar `sparkles` button.
- UI: category picker + intensity picker + free-text prompt ("Tell me what kind of cards you want") + count picker (5/10/20).
- Tap **Generate** → calls Rork AI proxy at `Config.EXPO_PUBLIC_RORK_API_BASE_URL/text/llm/` with a chat completion request. System prompt instructs the model to return a JSON array of `{text, category, intensity}` objects. Model: `openai/gpt-4o-mini` or equivalent.
- Use `AIContentModeration.swift` to filter outputs: bans hate/violence/illegal. If any card flagged, regenerate that card.
- On success, append generated cards to the saved deck for that category, mark `isAIGenerated = true`. Toast: "10 cards generated".
- On error, inline red error message + Retry.
- Quota: free users limited to 10 generations/day (counter in `UserDefaults`, resets at local midnight); subscribers unlimited. Show paywall CTA on quota hit.

## Seed data
A small bundled JSON of ~50 cards per category × 3 intensities, loaded once on first launch into the saved deck. The "deck" the user swipes through is `seed + AI generated + saved (already)` minus dismissed.
