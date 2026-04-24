# 8PartyPlay — Factory Tab (AI Generator) Prompt

This document specifies the Factory tab in full: the AI Party Game Idea Generator and the AI Card Generator entry point.

---

## 1. Tab Overview

**Tab icon:** `wand.and.stars`
**Tab label:** "Factory"

The Factory tab has two sections accessible via a segmented control at the top:
1. **Game Ideas** — generates creative party game concepts using AI.
2. **Card Packs** — generates custom card deck prompts using AI.

Both sections share a quota system: free users get **3 generations per day** (enforced by the Cloud Function `generateCards`). Pro users get unlimited.

---

## 2. FactoryView — Root Layout

```
FactoryView (NavigationStack)
├── Header
│   ├── Title: "Factory" (viralTitle)
│   ├── Subtitle: "AI-powered party content"
│   └── ProfileToolbarButton (top-right)
├── Segmented control: "Game Ideas" | "Card Packs"
├── If .gameIdeas → GameIdeaGeneratorView
└── If .cardPacks  → CardPackGeneratorView
```

**Daily quota badge:** shown below segmented control when user is on free tier.
- "3 generations left today" → green pill
- "1 generation left today" → yellow pill  
- "0 generations left today" → red pill + "Upgrade to Pro for unlimited"
- Pro user → no badge

---

## 3. GameIdeaGeneratorView

### Layout (scrollable)

#### Config card (SurfaceCard)
- Section title "Generate a Party Game Idea"
- **Vibe picker** — horizontal scroll chip row, single-select:
  - `Couple` (heart.fill, pink)
  - `Funny` (face.smiling.fill, yellow)
  - `Memory` (brain.fill, purple)
  - `Action` (bolt.fill, orange)
  - `Cards` (rectangle.on.rectangle.fill, blue)
  - `Trivia` (questionmark.circle.fill, cyan)
  - `Roleplay` (theatermasks.fill, indigo)
  - `Challenge` (flag.fill, red)
- **Player count picker** (optional, "Any" default):
  - Chips: "Any", "2–4", "4–8", "8+"
- **Notes field** (optional):
  - Placeholder: "Any extra ideas? e.g. 'office setting', 'outdoor'…"
  - 3-line multiline TextField, max 150 chars
  - Character counter caption

#### Generate button
- Full-width PrimaryButton "Generate Idea" + `wand.and.stars` icon
- Accent: purple gradient
- Disabled when: quota = 0 (free user), or currently generating
- Shows ProgressView with "Generating…" text while loading

#### Generated idea card (appears after generation)
`GeneratedIdeaCard` — animated slide-up + fade-in (spring 0.45/bounce 0.2):
- Gradient header: accent gradient (purple → indigo) with `wand.and.stars` 28pt white icon
- **Title** (24pt heavy, white)
- **Description** (16pt regular, white.opacity(0.85), multiline)
- **Steps card** (SurfaceCard inside the idea card):
  - "How to Play" 14pt semibold secondary
  - Numbered list: 3–6 steps with blue number circles (same as HowToPlaySheet style)
- **Tags row**: small gray capsule pills for each tag (e.g. "4+ players", "outdoor", "no props")
- **Action bar** (HStack):
  - Save button (`bookmark.fill` / `bookmark`) — toggles saved state, stores in local list
  - Share button (`square.and.arrow.up`) — shares as text
  - Regenerate button (`arrow.clockwise`) — generates a new idea with same settings

#### Saved ideas shelf
- Below the generated idea (or above if no current idea): a horizontal scroll row of saved idea cards.
- Each: 200×120pt mini-card with title + first tag. Tap to expand in a sheet.
- "Saved Ideas" section header with `trash` button (clears all saved).

---

## 4. CardPackGeneratorView

### Layout (scrollable)

#### Config card (SurfaceCard)
- Section title "Generate Custom Cards"
- **Category picker** — same 5 categories as card decks (single-select chips):
  - Act (purple), Talk (blue), Challenges (orange), Penalty (red), Couple (pink)
- **Subtype picker** — updates dynamically based on selected category:
  - Same subtypes as defined in TOOLS_CARDS_DETAILED_PROMPT.md
  - Horizontal chips, single-select
- **Vibe picker** — horizontal chips:
  - `Mild` (shield.fill, green)
  - `Balanced` (scale.fill, blue) — default
  - `Spicy` (flame.fill, red)
  - `Custom` (pencil.fill, gray) — enables a free-text vibe input
- **Audience picker** — single-select chips:
  - `Friends` (person.3.fill)
  - `Couples` (heart.fill)
  - `Family` (house.fill)
  - `Coworkers` (briefcase.fill)
- **Card count stepper**:
  - Label "Cards to generate"
  - Minus/Plus buttons (44×44 circle), range 3–10, default 6
  - Shows count in large centered text

#### Generate button
- Full-width PrimaryButton "Generate Cards" + `sparkles` icon
- Accent: category's accent color
- Loading state: "Generating {count} cards…"

#### Generated cards (appears after generation)
Animated staggered entrance (0.06s delay per card):

Each `GeneratedCardView`:
- Category gradient background (same as card decks)
- Card text (20pt rounded bold, white)
- Category + subtype badge (bottom-left pill)
- Action row: Save (`bookmark`), Discard (`xmark`)
- Swipe left → discard, swipe right → save

**Bulk actions bar** (appears when all cards judged or via "Review All"):
- "Save All" (green) / "Discard All" (secondary)
- Shows count: "{n} saved · {m} discarded"

**Finalize button:** "Create Deck" — saves all saved cards as a new custom deck accessible from the Tools → Cards tab under a "Custom" category.

---

## 5. AI API Integration

The AI call goes through the Firebase Cloud Function `generateCards` (see FIREBASE_SETUP_PROMPT.md). The iOS client does NOT call OpenAI directly.

### Swift service

```swift
nonisolated struct GeneratedCard: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
}

nonisolated struct GeneratedPartyIdea: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let steps: [String]
    let tags: [String]
}

@Observable
@MainActor
final class FactoryViewModel {
    var currentIdea: GeneratedPartyIdea?
    var generatedCards: [GeneratedCard] = []
    var savedIdeas: [GeneratedPartyIdea] = []
    var savedCards: [GeneratedCard] = []
    var isGenerating: Bool = false
    var errorMessage: String?

    // Config
    var selectedVibe: String = "Funny"
    var selectedPlayerCount: String = "Any"
    var extraNotes: String = ""
    var selectedCategory: String = "Talk"
    var selectedSubtype: String = "Truth"
    var selectedAudience: String = "Friends"
    var cardCount: Int = 6

    private let functions = Functions.functions()

    func generateGameIdea() async {
        isGenerating = true
        errorMessage = nil
        do {
            let result = try await functions.httpsCallable("generateCards").call([
                "category": "game_idea",
                "subtype": selectedVibe,
                "vibe": selectedPlayerCount,
                "audience": extraNotes,
                "count": 1,
            ])
            // Parse result into GeneratedPartyIdea
            if let data = result.data as? [String: Any],
               let cards = data["cards"] as? [[String: Any]],
               let first = cards.first,
               let text = first["text"] as? String {
                // Parse JSON text into GeneratedPartyIdea
                currentIdea = parseIdea(from: text)
            }
        } catch let error as FunctionsError {
            if error.code == .resourceExhausted {
                errorMessage = "Daily limit reached. Upgrade to Pro for unlimited generations."
            } else {
                errorMessage = "Generation failed. Check your connection and try again."
            }
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
        isGenerating = false
    }

    func generateCards() async {
        isGenerating = true
        errorMessage = nil
        generatedCards = []
        do {
            let result = try await functions.httpsCallable("generateCards").call([
                "category": selectedCategory,
                "subtype": selectedSubtype,
                "vibe": selectedVibe,
                "audience": selectedAudience,
                "count": cardCount,
            ])
            if let data = result.data as? [String: Any],
               let cards = data["cards"] as? [[String: Any]] {
                generatedCards = cards.compactMap { dict in
                    guard let text = dict["text"] as? String else { return nil }
                    return GeneratedCard(id: UUID(), text: text)
                }
            }
        } catch let error as FunctionsError {
            if error.code == .resourceExhausted {
                errorMessage = "Daily limit reached. Upgrade to Pro for unlimited."
            } else {
                errorMessage = "Generation failed. Try again."
            }
        } catch {
            errorMessage = "Something went wrong."
        }
        isGenerating = false
    }

    func saveIdea(_ idea: GeneratedPartyIdea) {
        savedIdeas.append(idea)
        persistIdeas()
    }

    func saveCard(_ card: GeneratedCard) {
        savedCards.append(card)
    }

    private func persistIdeas() {
        // Encode savedIdeas to UserDefaults (local persistence for generated ideas)
        if let data = try? JSONEncoder().encode(savedIdeas) {
            UserDefaults.standard.set(data, forKey: "saved_generated_ideas")
        }
    }
}
```

---

## 6. Paywall Upsell

When free quota is exhausted:

- A `FactoryPaywallBanner` appears pinned to the top of the tab content (below segmented control):
  - `wand.and.stars` icon
  - "You've used today's 3 free generations"
  - Subtitle: "Go Pro for unlimited AI content, all games, and more."
  - CTA button: "Upgrade to Pro" → opens PaywallView as a sheet.
  - Dismiss button (X) — hides banner until next app launch (does not re-show until next day).

- Generate button also shows this upsell inline when tapped while quota = 0:
  - Alert: title "Daily limit reached" body "Upgrade to Pro for unlimited AI generations every day." — "Upgrade" primary / "Not now" cancel.

---

## 7. Empty States

**No generated idea yet:**
- `wand.and.stars` 56pt, purple.opacity(0.5)
- "Pick a vibe and generate your first party game idea."
- Subtle pulsing glow on the icon.

**No generated cards yet:**
- `rectangle.stack.badge.plus` 56pt, category accent color
- "Configure your card pack and tap Generate."

**No saved ideas:**
- `tray.fill` 40pt, secondary
- "Your saved game ideas will appear here."

---

## 8. Navigation & Deep Link

- Deep link `partyplay://factory` opens the Factory tab.
- If a game is in progress and user taps the Factory tab: show a toast "Finish your game first" and keep focus on the active game overlay.
