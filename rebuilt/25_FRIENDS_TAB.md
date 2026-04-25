# 25 — Friends Tab

Third tab. Files: `Views/MainTabView.swift` → `FriendsView`. ViewModel ext: `AppViewModel+Friends.swift`.

## Sections (top → bottom in a single ScrollView)
1. **Quick Join card** — `number.square.fill` icon (blue tile) + title "Join with Code" + subtitle "Enter a room code to join instantly" + "Enter Code" blue capsule button on right. Tapping opens the same `QuickJoinSheet` as the Home header.
2. **Offline Friends** — local names for shared-phone games.
3. **Online Friends** — accepted friendships (account-bound).
4. **Public Rooms** — list of currently open rooms.

## Offline friends (`offlineFriendsSection`)
- Section header "Offline Friends" + subtitle "Local names for Single Device games."
- SurfaceCard:
  - `Add name` TextField (.words capitalization) + `Add` SecondaryAction button (64pt wide). Calls `appModel.addOfflineFriend(named:)`.
  - List rows: 26pt avatar (initial), name, "me" pill if `friend.status == "Me"` (the user's own onboarding name is always present and non-deletable), Edit + delete (`trash`) buttons. Edit toggles inline TextField. Save calls `updateOfflineFriend(_:name:)`.
- Empty: `ContentUnavailableView("No Offline Friends", "person.crop.circle.badge.plus", "Add names for local games.")`.

## Online friends (`onlineFriendsSection`)
- Section header "Online Friends" + subtitle "For Multi Device games and invites."
- SurfaceCard:
  - Search TextField "Search username, email, or ID" — `.never` capitalization, `.emailAddress` keyboard. `onChange(query) → appModel.searchFriends(query:)` (debounced 300ms inside the VM).
  - **Search results section** (visible when search is non-empty):
    - Loading: `ProgressView`.
    - Empty: "Log in to search" if guest, else "No matches".
    - Each result: 34pt avatar + username (.subheadline .semibold) + "ID #1234" or "No public ID" caption + action button driven by `relationshipState.buttonTitle`.
  - **Incoming requests section** (visible when `requests.isEmpty == false`): rows with avatar + name + "Decline" + "Accept" buttons. Calls `appModel.acceptRequest(_:)` / `declineRequest(_:)`.
  - **Friends list**: rows with 26pt online-dotted avatar + name + "Invite" blue capsule. Empty state shows "No Online Friends" + a `ShareLink` "Invite friends to play" with marketing copy "Let's play 8PartyPlay together! Download: https://www.8partyplay.com".

## Public rooms (`publicRoomsSection`)
- Section header "Public Rooms" + subtitle "Open multiplayer rooms you can join." + (only if guest) a "Login" capsule button on the right that opens the AuthView sheet.
- SurfaceCard:
  - Empty: `person.3.sequence.fill` + "No public rooms yet" + "Create a room from any multiplayer game.".
  - Rows: 40pt accent tile with `room.game.symbolName`, game name + StatusPillView for mode, "X/Y players • {host}", chevron. Tapping pushes `LobbyRoute.room(room)` → `WaitingRoomView`.

## Friends data sources
- `appModel.offlineFriends` — local-only `[Friend]` from UserDefaults.
- `appModel.onlineFriends` — `[Friend]` synced from Supabase `friends` view + profile join.
- `appModel.requests` — incoming `[FriendRequest]`.
- `appModel.friendSearchResults` — `[FriendSearchResult]` from `search_users` RPC.
- `appModel.visibleRooms` — `[GameRoom]` from `casual_rooms` realtime subscription filtered by `is_public = true AND status = waiting`.
