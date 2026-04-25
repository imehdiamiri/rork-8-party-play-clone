# 24 — Factory Tab (AI Game Idea Generator)

Fourth tab. SF symbol `wand.and.stars`. Single screen `Views/GeneratorView.swift`.

## Purpose
Generate **fresh party-game ideas** ("ways to play together with friends") on demand using the AI proxy. These are not playable in-app — they're textual ideas you can do IRL with the people in front of you, or as inspiration for the dev team.

## Layout
- Header: title "Factory" viralTitleStyle 20/.black + `ProfileToolbarButton`.
- Hero card: "Need a new game? Generate one." with `wand.and.stars` icon and a "Generate" button.
- Options panel:
  - **Vibe**: chill / silly / competitive / spicy / family / random (chip row).
  - **Player count**: 2 / 3-5 / 6-10 / 10+.
  - **Setting**: indoor / outdoor / road trip / party / dinner / random.
  - **Includes**: phones (toggle), drinks (toggle, 18+ only), pen & paper (toggle).
- Generate button (PrimaryActionButtonStyle).
- Result card area: shows the generated idea with `name`, `description`, `how to play` numbered steps, `materials needed`, `play time`, `difficulty`. Save to favorites button (heart) and Share button.
- Below: list of "My Generated Games" (favorites). Tap to expand. Long-press to delete.

## API
Same Rork AI proxy as cards. System prompt in code (`GeneratorView` view model — internal) instructs:
- Response must be JSON: `{name, description, materials[], steps[], playTime, difficulty}`.
- Idea must be original (no copyrighted games).
- Tone matches selected vibe.
- Steps 3–6 items.

Model: `openai/gpt-4o-mini`. Streaming optional (UI uses non-streaming).

## Quota
Free users: 5 generations/day. Subscribers: 50/day. Counter in `UserDefaults`, midnight reset.

## Persistence
Favorites stored in `UserDefaults` (Codable JSON). Max 100 saved.

## Empty/error state
- First-time hint overlay using `FirstTimeHintOverlay` explaining the feature.
- Network error → inline red banner "Couldn't generate, try again".
