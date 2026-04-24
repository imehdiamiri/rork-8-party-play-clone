# 8PartyPlay — Per-Screen State Matrix

Every screen must implement these four states explicitly. Never ship a screen that only handles the "success" path.

| State | When | Visual |
|---|---|---|
| **Loading** | Awaiting first data fetch | Skeleton shimmer (preferred) or `LoadingStateView` (centered ProgressView + caption) |
| **Empty** | Fetch returned 0 items | `EmptyStateView` (icon + title + body + optional CTA) |
| **Error** | Fetch failed / network / permission | `ErrorStateView` (icon + title + body + Retry) + global toast |
| **Success** | Data ready | The actual UI from `02B` |

Plus where applicable:
- **Offline** — connection banner pinned top, content shows cached data with "Last synced X min ago" caption.
- **Reconnecting** — same banner (yellow), inputs disabled.
- **Stale / partial** — show data + a small "Refresh" pill.

---

## Per-screen matrix

| Screen | Loading | Empty | Error | Offline behavior |
|---|---|---|---|---|
| Splash | Logo + spinner | n/a | Retry CTA "Try again" | Bypass to last cached profile |
| Onboarding | n/a | n/a | n/a | Works fully offline |
| Auth | Spinner inside the pressed button | n/a | Toast + inline message under field | Disable Apple/Google, allow Guest |
| Home (Games) | Skeleton 6 GameCards (gray gradient + shimmer) | "No games available" + Retry | Full-screen ErrorStateView | Cached game list works |
| Friends | 6 row skeletons | "No friends yet" + "Find Friends" CTA | ErrorStateView + Retry | Read-only from cache, send disabled |
| Public Rooms | 4 row skeletons | "No public rooms — be the first" + Create | ErrorStateView | Disabled banner: "Connect to browse rooms" |
| Profile sheet | Avatar + name skeleton | n/a | Inline error chip on failed action | All toggles work; sync deferred |
| Wallet | Hero number "—" with shimmer | "No transactions yet" | ErrorStateView | Cached balance + "offline" badge |
| Paywall | Tier card skeleton (2 cards shimmer) | n/a (always has tiers) | ErrorStateView with Retry | Disable purchase, show "Reconnect to subscribe" |
| Lobby | "Connecting…" with spinner | "Waiting for players…" body | "Connection lost" + Reconnect | Auto-reconnect banner |
| In-game HUD | Phase-specific loader (e.g. countdown 3-2-1) | n/a | "Game error" full-screen + Return Home | Banner + auto-pause |
| Tools | n/a (instant) | n/a | n/a | n/a |
| Cards (decks) | Skeleton card stack (3 placeholders) | "No cards in this deck" | ErrorStateView | Cached cards work |
| Factory | Inline spinner over Generate button | "No generations yet" | Toast + error caption under button | Disable Generate, show "Connect to generate" |
| Notifications | 5 row skeletons | "All caught up" + envelope icon | ErrorStateView + Retry | Cached list |
| Settings | n/a (instant local) | n/a | Toast on save failure | Local writes queued |
| Web Marketing | n/a | n/a | n/a | n/a (static) |

---

## Skeleton component spec

`SkeletonView` — implement once per platform.
- Background: white 6%.
- Animated highlight: linear gradient sweep, 1.4s loop, ease-in-out.
- Corner radius matches the placeholder shape (text rows 6, avatars circle, cards 18 / 20).
- Respects Reduce Motion → static white 6% block.

Skeleton recipes per surface:
- **GameCard skeleton** — 1:1 rounded 20, 3 inner rows: 64×64 square top-left, two 14-high text bars (60% / 40% widths) bottom-left.
- **List row skeleton** — 56 high: avatar 40 circle + two bars (title 60%, subtitle 40%).
- **PackCard skeleton** — 1:1 rounded 18, 3 bars stacked center.

---

## Error copy library (use these exact strings)

| Code | Title | Body | CTA |
|---|---|---|---|
| `network` | "You're offline" | "Check your connection and try again." | "Retry" |
| `auth` | "Couldn't sign in" | "Please try a different method." | "Try again" |
| `quota_exceeded` | "Daily limit reached" | "Come back tomorrow or go Premium." | "Go Premium" |
| `room_full` | "Room is full" | "Ask the host to remove a player." | "Back" |
| `room_not_found` | "Room not found" | "Double-check the code." | "OK" |
| `unknown` | "Something went wrong" | "Please try again in a moment." | "Retry" |

Localize every string (see `14_LOCALIZATION_ACCESSIBILITY_PROMPT.md`).

---

## Connection banner state machine
States: `online` (hidden) → `connecting` (yellow, "Reconnecting…") → `disconnected` (red, "No connection") → `reconnected` (green, "Back online", auto-hide 2s) → `online`.
Driven by `SessionResilienceService` per `06_MULTI_DEVICE_PROMPT.md`. Never hide the banner while a multiplayer game is live and the socket is down.

---

## Done checklist
- [ ] Every list/grid screen has a skeleton.
- [ ] Every screen has an empty + error + retry path.
- [ ] All error copy comes from the localized library above.
- [ ] Offline behavior verified by toggling airplane mode.
- [ ] Reduce Motion replaces shimmer with static placeholder.
