# 24 — Factory Tab (AI Game Idea Generator)

Fourth tab. SF symbol `wand.and.stars`. Single screen `Views/GeneratorView.swift` driven by `GeneratorViewModel`.

## Purpose
Generate fresh party-game ideas on demand using the AI proxy. Output is textual / inspirational — not playable in-app.

## State (`GeneratorViewModel`)
- `prompt: String` — free-text user input.
- `playerCount: Int = 4` (clamped to `2...20`) — continuous integer picker, **not bucketed** (no "2 / 3-5 / 6-10 / 10+" chips).
- `vibe: GameVibe` — chip row.
- `isGenerating: Bool`, `errorMessage: String?`.
- `result: GeneratedPartyIdea?`.

## `GameVibe` cases
`couple, funny, memory, action, cards, trivia, roleplay, challenge` (8 cases). Each vibe has a `promptDescriptor` used to build the AI system prompt. There is **no `chill / silly / competitive / spicy / family / random` vibe set.**

## What does NOT exist
- ❌ no "Setting" picker (indoor / outdoor / road trip / …).
- ❌ no "Includes" toggles (phones / drinks / pen & paper).
- ❌ no favorites / saved-list of generated games.
- ❌ no daily quota counter on the Factory screen (the 5/day quota is on the AI **card** generator only).

## `GeneratedPartyIdea` shape
`{ id, title, description, steps: [String], tags: [String] }`. There are **no `materials needed`, `play time`, or `difficulty` fields.**

## UI
- Header: title + `ProfileToolbarButton`.
- Hero card with a Generate CTA.
- Vibe chip row + player-count picker + `prompt` text field.
- Result card showing `title`, `description`, numbered `steps`, and `tags` rendered as small chip labels.
- Error state: inline red banner with `errorMessage`.
