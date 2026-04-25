# 09 — Home Tab (Games)

`HomeView` is the root of `HomeRootView`'s NavigationStack. Toolbar is hidden; the content draws its own header. ScrollView with bottom padding 96.

## Layout (top → bottom)
1. **Header** (16h padding):
   - Title `8PartyPlay` viralTitleStyle 20/.black, lineLimit 1.
   - Spacer.
   - `Join` button (`number` icon 13pt + "Join" caption .bold), 12/7 padding, white-10% capsule with 12% white stroke. Tapping presents `QuickJoinSheet` (full-screen cover) → `CasualJoinRoomView` inside a NavigationStack with Cancel toolbar item.
   - `ProfileToolbarButton` trailing.
2. **Library tabs** — segmented control, max width 250, centered:
   - Two tabs: "Games" (`gamecontroller.fill`) and "Ideas" (`shippingbox.fill`).
   - On iOS 26+, wrap in `GlassEffectContainer(spacing: 0)` and use `glassEffect(.regular.tint(.blue).interactive(), in: .capsule)` on selected pill. Pre-26 uses `Capsule().fill(.blue.opacity(0.88))` for the selected tab and `.white.opacity(0.08)` capsule with 6% stroke for the container.
   - Active spring `.spring(0.28, 0.16)`.
3. **Mode filter row** (only when "Games" tab is active) — horizontal ScrollView with chips: `All`, `1 Phone`, `Multi Phone`, `Team Mode`. Selected chip = clear bg + blue text + `.blue.opacity(0.4)` 1pt stroke. Unselected = white-7% bg + secondary text + 6% stroke. caption2 .semibold, 11/6 padding.
4. **Games grid** OR **Ideas list**.

## Games grid
LazyVGrid 2 columns flexible spacing 12, items spacing 12. Items = `appModel.games.filter(byMode).sorted(unlockedFirst)` rendered via `Button { path.append(.game(game.id)) } label: { GameCardView(game:, isLocked:) }` + `CardPressStyle()` + `slideUpOnAppear(delay: index * 0.06)`.

`GameCardView` — square (aspectRatio 1:1):
- Title `viralTitleStyle(20, .black)` white, 2 lines, minScale 0.7.
- 32pt SF Symbol on white-12% rounded-16 square 56×56.
- Mode icons row: 20×20 white-10% circles. For `.multiDevice`, render the custom `MultiPhoneIcon(size: 7)` instead of an SF symbol; for others use `mode.icon` (9pt .semibold .white@60%).
- Player count text size 10 .bold @70% white.
- Background = LinearGradient from accent palette (file 03), 18pt rounded, 25% accent 1pt stroke.
- If locked, top-right `lock.fill` 13pt heavy on .black@35% circle with .white@35% 1pt stroke, padded 10.

## Ideas tab — `OtherFunListView()`
Static list of "real-life party game ideas" (no in-app implementation) loaded from `Models/QuickGameModels.swift`. Each idea has icon, name, short description, players, materials. Pure read-only marketing/help content.

## Quick Join sheet (`QuickJoinSheet`)
Full-screen cover containing a NavigationStack with `CasualJoinRoomView`, navigationTitle "Join Room" (.inline), Cancel toolbar leading. Auto-dismisses when `appModel.requestCasualSheetDismiss` flips true or `appModel.activeSession` becomes non-nil.

## Filtered game ordering
Unlocked games come first, locked games last (premium without subscription). Within each bucket, original library order is preserved (stable sort).

## Empty state
`ContentUnavailableView("No Games", systemImage: "gamecontroller", description: …)` when filter returns nothing.
