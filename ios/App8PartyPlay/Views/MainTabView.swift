import SwiftUI
import PhotosUI
import Supabase

struct MainTabView: View {
    let appModel: AppViewModel
    let store: StoreViewModel
    @State private var isShowingProfile: Bool = false
    @State private var homeNavigationResetID: UUID = UUID()
    @State private var homeLibraryResetID: UUID = UUID()

    var body: some View {
        TabView(selection: Binding(
            get: { appModel.selectedTab },
            set: { newValue in
                if newValue == .home {
                    homeNavigationResetID = UUID()
                    homeLibraryResetID = UUID()
                }
                SoundManager.shared.playTabSwitch()
                appModel.selectedTab = newValue
            }
        )) {
            Tab("Games", systemImage: "gamecontroller.fill", value: AppTab.home) {
                HomeRootView(
                    appModel: appModel,
                    store: store,
                    navigationResetID: homeNavigationResetID,
                    libraryResetID: homeLibraryResetID,
                    showProfile: { isShowingProfile = true }
                )
            }
            Tab("Tools", systemImage: "wrench.and.screwdriver.fill", value: AppTab.cards) {
                CardsRootView(appModel: appModel, store: store, showProfile: { isShowingProfile = true })
            }
            Tab("Friends", systemImage: "person.2.fill", value: AppTab.social) {
                SocialRootView(appModel: appModel, showProfile: { isShowingProfile = true })
            }
            .badge(appModel.requests.count)
            Tab("Factory", systemImage: "wand.and.stars", value: AppTab.generator) {
                GeneratorView(appModel: appModel, showProfile: { isShowingProfile = true })
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingProfile, onDismiss: {
            appModel.profileContextGame = nil
        }) {
            ProfileView(appModel: appModel, store: store)
        }
        .fullScreenCover(item: Binding(get: { appModel.activeSession }, set: { appModel.activeSession = $0 })) { session in
            GameSessionView(appModel: appModel, sessionID: session.id)
        }
        .toastOverlay(appModel: appModel)
    }
}

struct HomeRootView: View {
    let appModel: AppViewModel
    let store: StoreViewModel
    let navigationResetID: UUID
    let libraryResetID: UUID
    let showProfile: () -> Void
    @State private var path: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(appModel: appModel, path: $path, libraryResetID: libraryResetID, showProfile: showProfile)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .game(let game):
                        GameDetailView(appModel: appModel, game: game, path: $path, showProfile: showProfile, store: store)
                    case .imposterStyleSelection:
                        ImposterStyleSelectionView(appModel: appModel, path: $path, showProfile: showProfile)
                    case .imposterGame(let game, let style):
                        ImposterGameDetailView(appModel: appModel, game: game, gameStyle: style, path: $path, showProfile: showProfile)
                    case .lobby(let room):
                        WaitingRoomView(appModel: appModel, initialRoom: room)
                    }
                }
        }
        .onChange(of: navigationResetID) { _, _ in
            path.removeAll()
        }
    }
}

struct SocialRootView: View {
    let appModel: AppViewModel
    let showProfile: () -> Void
    @State private var path: [LobbyRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackgroundView()
                VStack(spacing: 12) {
                    socialHeader
                    FriendsView(appModel: appModel, path: $path, showProfile: showProfile)
                }
                .padding(.top, 6)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LobbyRoute.self) { route in
                switch route {
                case .room(let room):
                    WaitingRoomView(appModel: appModel, initialRoom: room)
                case .online(let game):
                    CasualCreateRoomView(appModel: appModel, game: game)
                }
            }
        }
    }

    private var socialHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Friends")
                .viralTitleStyle(size: 20, weight: .black)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            if appModel.requests.count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bell.badge.fill")
                        .font(.caption.weight(.bold))
                    Text("\(appModel.requests.count)")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.14), in: .capsule)
            }
            ProfileToolbarButton(systemImage: appModel.avatarSymbol, accessibilityLabel: "Profile", imageData: appModel.profileImageData, action: showProfile)
        }
        .padding(.horizontal, 16)
    }
}

struct HomeView: View {
    nonisolated enum GameLibraryTab: String, CaseIterable, Identifiable, Sendable {
        case playable
        case learning

        var id: String { rawValue }

        var label: String {
            switch self {
            case .playable: return "Games"
            case .learning: return "Ideas"
            }
        }

        var icon: String {
            switch self {
            case .playable: return "gamecontroller.fill"
            case .learning: return "shippingbox.fill"
            }
        }
    }

    let appModel: AppViewModel
    @Binding var path: [HomeRoute]
    let libraryResetID: UUID
    let showProfile: () -> Void
    @State private var selectedLibraryTab: GameLibraryTab = .playable
    @State private var selectedModeFilter: GameMode? = nil
    @State private var showJoinSheet: Bool = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    libraryTabs
                    if selectedLibraryTab == .playable {
                        modeFilterRow
                        gamesSection
                    } else {
                        OtherFunListView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: libraryResetID) { _, _ in
            selectedLibraryTab = .playable
        }
        .fullScreenCover(isPresented: $showJoinSheet) {
            QuickJoinSheet(appModel: appModel, onGameStarted: { showJoinSheet = false })
        }
        .onChange(of: appModel.requestCasualSheetDismiss) { _, shouldDismiss in
            if shouldDismiss { showJoinSheet = false }
        }
        .onChange(of: appModel.activeSession?.id) { _, newID in
            guard newID != nil else { return }
            showJoinSheet = false
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("8PartyPlay")
                .viralTitleStyle(size: 20, weight: .black)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                showJoinSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.system(size: 13, weight: .bold))
                    Text("Join")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.1), in: .capsule)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.12))
                }
            }
            .buttonStyle(.plain)
            ProfileToolbarButton(systemImage: appModel.avatarSymbol, accessibilityLabel: "Profile", imageData: appModel.profileImageData, action: showProfile)
        }
    }

    private var libraryTabs: some View {
        HStack {
            Spacer(minLength: 0)
            Group {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 0) {
                        compactLibraryTabsContent
                    }
                } else {
                    compactLibraryTabsContent
                        .padding(4)
                        .background(.white.opacity(0.08), in: .capsule)
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.06))
                        }
                }
            }
            .frame(maxWidth: 250)
            Spacer(minLength: 0)
        }
    }

    private var compactLibraryTabsContent: some View {
        HStack(spacing: 4) {
            ForEach(GameLibraryTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                        selectedLibraryTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption2.weight(.bold))
                        Text(tab.label)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(selectedLibraryTab == tab ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background {
                    if #available(iOS 26.0, *) {
                        EmptyView()
                    } else if selectedLibraryTab == tab {
                        Capsule()
                            .fill(.blue.opacity(0.88))
                    }
                }
                .modifier(CompactLibraryTabGlassEffect(isSelected: selectedLibraryTab == tab))
            }
        }
    }

    private var modeFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                modeFilterChip(title: "All", isSelected: selectedModeFilter == nil) {
                    withAnimation(.spring(duration: 0.22)) { selectedModeFilter = nil }
                }
                ForEach(GameMode.allCases) { mode in
                    modeFilterChip(title: mode.title, isSelected: selectedModeFilter == mode) {
                        withAnimation(.spring(duration: 0.22)) { selectedModeFilter = mode }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 0)
    }

    private func modeFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(isSelected ? .clear : .white.opacity(0.07), in: .capsule)
                .foregroundStyle(isSelected ? .blue : .secondary)
                .overlay {
                    Capsule().strokeBorder(isSelected ? .blue.opacity(0.4) : .white.opacity(0.06))
                }
        }
        .buttonStyle(.plain)
    }

    private var filteredGames: [GameDefinition] {
        let base: [GameDefinition]
        if let mode = selectedModeFilter {
            base = appModel.games.filter { $0.id.supportedModes.contains(mode) }
        } else {
            base = appModel.games
        }
        return base.sorted { lhs, rhs in
            let lhsLocked = !appModel.canPlayGame(lhs.id)
            let rhsLocked = !appModel.canPlayGame(rhs.id)
            if lhsLocked == rhsLocked { return false }
            return !lhsLocked && rhsLocked
        }
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
                    Button {
                        SoundManager.shared.playNavigation()
                        path.append(.game(game.id))
                    } label: {
                        GameCardView(game: game, isLocked: !appModel.canPlayGame(game.id))
                    }
                    .buttonStyle(CardPressStyle())
                    .slideUpOnAppear(delay: Double(index) * 0.06)
                }
            }

            if filteredGames.isEmpty {
                ContentUnavailableView("No Games", systemImage: "gamecontroller", description: Text(selectedModeFilter == nil ? "Games will appear here as they are added." : "No games support this mode yet."))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }


}

struct CompactLibraryTabGlassEffect: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    isSelected ? .regular.tint(.blue).interactive() : .regular.interactive(),
                    in: .capsule
                )
        } else {
            content
        }
    }
}

struct QuickJoinSheet: View {
    let appModel: AppViewModel
    var onGameStarted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CasualJoinRoomView(appModel: appModel, onJoinedAndStarted: { _ in })
                .navigationTitle("Join Room")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .onChange(of: appModel.requestCasualSheetDismiss) { _, shouldDismiss in
            if shouldDismiss {
                onGameStarted?()
                dismiss()
            }
        }
        .onChange(of: appModel.activeSession?.id) { _, newID in
            guard newID != nil else { return }
            onGameStarted?()
            dismiss()
        }
    }
}

struct GameCardView: View {
    let game: GameDefinition
    var isLocked: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            Text(game.id.name)
                .viralTitleStyle(size: 20, weight: .black)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

            Spacer(minLength: 6)

            Image(systemName: game.id.symbolName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.12), in: .rect(cornerRadius: 16))

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                ForEach(game.id.supportedModes) { mode in
                    if mode == .multiDevice {
                        MultiPhoneIcon(size: 7)
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.1), in: .circle)
                    } else {
                        Image(systemName: mode.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.1), in: .circle)
                    }
                }
            }

            Text(game.id.playerCountText)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(.black.opacity(0.35), in: .circle)
                    .overlay { Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1) }
                    .padding(10)
            }
        }
    }

    private var gradientColors: [Color] {
        switch game.accentName {
        case "pink": return [.pink.opacity(0.95), .red.opacity(0.65), .purple.opacity(0.5)]
        case "cyan": return [.cyan.opacity(0.95), .mint.opacity(0.7), .blue.opacity(0.5)]
        case "teal": return [.teal.opacity(0.95), .green.opacity(0.7), .mint.opacity(0.45)]
        case "orange": return [.orange.opacity(0.96), .red.opacity(0.72), .yellow.opacity(0.4)]
        case "red": return [.red.opacity(0.95), .pink.opacity(0.7), .orange.opacity(0.45)]
        case "yellow": return [.yellow.opacity(0.96), .orange.opacity(0.72), .red.opacity(0.4)]
        case "purple": return [.purple.opacity(0.95), .indigo.opacity(0.8), .pink.opacity(0.45)]
        default: return [.blue.opacity(0.95), .indigo.opacity(0.75), .purple.opacity(0.45)]
        }
    }

    private var accentColor: Color {
        switch game.accentName {
        case "pink": return .pink
        case "cyan": return .cyan
        case "teal": return .teal
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }


}

struct FriendsView: View {
    let appModel: AppViewModel
    @Binding var path: [LobbyRoute]
    let showProfile: () -> Void
    @State private var draftFriendName: String = ""
    @State private var searchText: String = ""
    @State private var editingOfflineFriendID: UUID?
    @State private var editingOfflineFriendName: String = ""
    @State private var showJoinSheet: Bool = false
    @State private var showAuthSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                quickJoinCard
                offlineFriendsSection
                onlineFriendsSection
                publicRoomsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 96)
        }
        .scrollDismissesKeyboard(.immediately)
        .dismissKeyboardOnTap()
        .onChange(of: searchText) { _, newValue in
            appModel.searchFriends(query: newValue)
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView(appModel: appModel)
        }
        .fullScreenCover(isPresented: $showJoinSheet) {
            NavigationStack {
                CasualJoinRoomView(appModel: appModel)
                    .navigationTitle("Join Room")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showJoinSheet = false }
                        }
                    }
            }
        }
        .onChange(of: appModel.requestCasualSheetDismiss) { _, shouldDismiss in
            if shouldDismiss { showJoinSheet = false }
        }
        .onChange(of: appModel.activeSession?.id) { _, newID in
            guard newID != nil else { return }
            showJoinSheet = false
        }
    }

    private var quickJoinCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "number.square.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(.blue.opacity(0.14), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("Join with Code")
                    .font(.subheadline.weight(.bold))
                Text("Enter a room code to join instantly")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            Button {
                showJoinSheet = true
            } label: {
                Text("Enter Code")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.blue, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.05))
        }
    }

    private var publicRoomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Public Rooms")
                        .viralTitleStyle(size: 20, weight: .black)
                        .foregroundStyle(.white)
                    Text("Open multiplayer rooms you can join.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)

                if appModel.currentProvider == .guest {
                    Button {
                        showAuthSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Login")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.blue.opacity(0.12), in: .capsule)
                        .overlay {
                            Capsule().strokeBorder(.blue.opacity(0.25))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            SurfaceCard {
                VStack(spacing: 14) {
                    if appModel.visibleRooms.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("No public rooms yet")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Create a room from any multiplayer game.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(Array(appModel.visibleRooms.enumerated()), id: \.element.id) { index, room in
                            Button {
                                path.append(.room(room))
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: room.game.symbolName)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.green)
                                        .frame(width: 40, height: 40)
                                        .background(.green.opacity(0.14), in: .rect(cornerRadius: 12))

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(room.game.name)
                                                .font(.subheadline.weight(.semibold))
                                            StatusPillView(title: room.mode.shortLabel, systemImage: room.mode.icon, tint: room.mode.accentColor)
                                        }
                                        Text("\(room.players.count)/\(room.maxPlayers) players • \(room.hostName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if index < appModel.visibleRooms.count - 1 {
                                Divider().overlay(.white.opacity(0.06))
                            }
                        }
                    }
                }
            }
        }
    }

    private var offlineFriendsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Offline Friends", subtitle: "Local names for Single Device games.")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Add name", text: $draftFriendName)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.05), in: .rect(cornerRadius: 10))
                        Button("Add") {
                            appModel.addOfflineFriend(named: draftFriendName)
                            draftFriendName = ""
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(width: 64)
                    }

                    if appModel.offlineFriends.isEmpty {
                        ContentUnavailableView("No Offline Friends", systemImage: "person.crop.circle.badge.plus", description: Text("Add names for local games."))
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(appModel.offlineFriends) { friend in
                                VStack(spacing: 0) {
                                    if editingOfflineFriendID == friend.id {
                                        HStack(spacing: 8) {
                                            TextField("Friend name", text: $editingOfflineFriendName)
                                                .textInputAutocapitalization(.words)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(.white.opacity(0.05), in: .rect(cornerRadius: 10))
                                            Button("Save") {
                                                appModel.updateOfflineFriend(friend, name: editingOfflineFriendName)
                                                editingOfflineFriendID = nil
                                                editingOfflineFriendName = ""
                                            }
                                            .buttonStyle(SecondaryActionButtonStyle())
                                            .frame(width: 68)
                                        }
                                        .padding(.vertical, 8)
                                    } else {
                                        HStack(spacing: 8) {
                                            compactAvatar(title: friend.name, size: 26)
                                            Text(friend.name)
                                                .font(.caption.weight(.semibold))
                                                .lineLimit(1)
                                            if friend.status == "Me" {
                                                Text("me")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.blue)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 1)
                                                    .background(.blue.opacity(0.18), in: .capsule)
                                            }
                                            Spacer(minLength: 6)
                                            if friend.status != "Me" {
                                                Button("Edit") {
                                                    editingOfflineFriendID = friend.id
                                                    editingOfflineFriendName = friend.name
                                                }
                                                .buttonStyle(.plain)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                Button(role: .destructive) {
                                                    appModel.removeOfflineFriend(friend)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.caption2.weight(.semibold))
                                                        .frame(width: 24, height: 24)
                                                        .background(.white.opacity(0.05), in: .rect(cornerRadius: 8))
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    if friend.id != appModel.offlineFriends.last?.id {
                                        Divider().overlay(.white.opacity(0.08))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var onlineFriendsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeaderView(title: "Online Friends", subtitle: "For Multi Device games and invites.")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search username, email, or ID", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.05), in: .rect(cornerRadius: 10))

                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchResultsSection
                    }

                    if !appModel.requests.isEmpty {
                        incomingRequestsSection
                    }

                    if appModel.onlineFriends.isEmpty {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.2")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No Online Friends")
                                        .font(.caption.weight(.bold))
                                    Text("Accepted friendships appear here.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4)
                            ShareLink(item: "Let\u{2019}s play 8PartyPlay together! Download: https://www.8partyplay.com") {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption2.weight(.semibold))
                                    Text("Invite friends to play")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.blue, in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(appModel.onlineFriends) { friend in
                                HStack(spacing: 8) {
                                    compactAvatar(title: friend.name, isOnline: friend.isOnline, size: 26)
                                    Text(friend.name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: 6)
                                    Button {
                                        appModel.inviteFriend(friend)
                                    } label: {
                                        Text("Invite")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(.blue, in: .capsule)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                if friend.id != appModel.onlineFriends.last?.id {
                                    Divider().overlay(.white.opacity(0.08))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if appModel.isSearchingFriends {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else if appModel.friendSearchResults.isEmpty {
                Text(appModel.currentProvider == .guest ? "Log in to search" : "No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(appModel.friendSearchResults) { result in
                    HStack(spacing: 10) {
                        compactAvatar(title: result.username)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.username)
                                .font(.subheadline.weight(.semibold))
                            Text(result.publicUserID.map { "ID #\($0)" } ?? "No public ID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            appModel.sendFriendRequest(to: result)
                        } label: {
                            Text(result.relationshipState.buttonTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(result.relationshipState.isActionable ? .white : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    result.relationshipState.isActionable ? Color.blue : .white.opacity(0.06),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!result.relationshipState.isActionable)
                    }
                    .padding(.vertical, 6)
                    .contentShape(.rect)
                }
            }
        }
    }

    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Requests")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(appModel.requests) { request in
                HStack(spacing: 10) {
                    compactAvatar(title: request.name, isOnline: true)
                    Text(request.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Decline") { appModel.declineRequest(request) }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Accept") { appModel.acceptRequest(request) }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(width: 72)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func compactAvatar(title: String, isOnline: Bool = false, size: CGFloat = 34) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: size, height: size)
            Text(String(title.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .bold))
        }
        .overlay(alignment: .bottomTrailing) {
            if isOnline {
                Circle()
                    .fill(.green)
                    .frame(width: max(7, size * 0.28), height: max(7, size * 0.28))
                    .overlay {
                        Circle().stroke(.black.opacity(0.7), lineWidth: 1.5)
                    }
            }
        }
    }
}

struct WalletView: View {
    let appModel: AppViewModel
    let store: StoreViewModel
    let showProfile: () -> Void
    @State private var purchaseSelection: PurchaseSelection?
    @State private var showInviteSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        walletHeader
                        starBalanceHero
                        if let feedback = appModel.economyFeedback {
                            feedbackCard(feedback)
                        }
                        membershipCard
                        starEconomyCard
                        starSourcesCard
                        inviteFriendsCard
                        historySection
                        restorePurchasesRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $purchaseSelection) { selection in
                PurchaseDetailView(selection: selection, store: store)
            }
            .sheet(isPresented: $showInviteSheet) {
                InviteView(appModel: appModel)
            }
        }
    }

    private var inviteFriendsCard: some View {
        Button {
            showInviteSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.pink)
                    .frame(width: 38, height: 38)
                    .background(.pink.opacity(0.16), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite Friends")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Earn +30 \u{2605} when a friend joins.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.06))
            }
        }
        .buttonStyle(.plain)
    }

    private var walletHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Wallet")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                Text(appModel.starsBalance.formatted(.number.grouping(.automatic)))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.1), in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.12))
            }
            ProfileToolbarButton(systemImage: appModel.avatarSymbol, accessibilityLabel: "Profile", imageData: appModel.profileImageData, action: showProfile)
        }
    }

    private var starBalanceHero: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.orange)
                Text(appModel.starsBalance.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .sensoryFeedback(.success, trigger: appModel.starsBalance)
            }
            Text("Stars balance")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Stars are used for AI-generated cards.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial.opacity(0.8))
                .overlay {
                    LinearGradient(
                        colors: [.orange.opacity(0.14), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(.rect(cornerRadius: 22))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.white.opacity(0.06))
                }
        }
    }

    private var membershipStatusLabel: String {
        if store.isLifetime { return "Lifetime access active" }
        if store.isPremium {
            if let tier = store.currentTier {
                return "\(tier.displayName) • Active"
            }
            return "Premium • Active"
        }
        return "Free plan"
    }

    private var membershipCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: store.isPremium ? "crown.fill" : "lock.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(store.isPremium ? .orange : .secondary)
                        .frame(width: 40, height: 40)
                        .background((store.isPremium ? Color.orange : Color.white).opacity(store.isPremium ? 0.16 : 0.06), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Membership")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(membershipStatusLabel)
                            .font(.headline.weight(.bold))
                    }
                    Spacer()
                }

                VStack(spacing: 8) {
                    planRow(tier: .weekly, price: "$4.99", stars: 40, accent: .blue)
                    planRow(tier: .monthly, price: "$6.99", stars: 120, accent: .orange)
                    planRow(tier: .yearly, price: "$29.99", stars: 500, accent: .purple, badge: "BEST VALUE")
                    planRow(tier: .lifetime, price: "$49.99", stars: nil, accent: .pink, subtitle: "One-time \u{2022} Forever access")
                }
            }
        }
    }

    private func planRow(tier: SubscriptionTier, price: String, stars: Int?, accent: Color, subtitle: String? = nil, badge: String? = nil) -> some View {
        Button {
            purchaseSelection = .subscription(tier)
        } label: {
         HStack(spacing: 12) {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(accent, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tier.displayName).font(.subheadline.weight(.bold))
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: .capsule)
                    }
                }
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                } else if let stars {
                    Text("+\(stars) ★ per period").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(price)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
         }
         .padding(.vertical, 8)
         .padding(.horizontal, 12)
         .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var starEconomyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Star Packs", subtitle: "Tap a pack to purchase.")
                VStack(spacing: 8) {
                    packRow(price: "$0.99", stars: 50, discount: nil)
                    packRow(price: "$2.99", stars: 200, discount: 25)
                    packRow(price: "$4.99", stars: 400, discount: 37)
                    packRow(price: "$9.99", stars: 1000, discount: 50, isBest: true)
                }
            }
        }
    }

    private func packRow(price: String, stars: Int, discount: Int?, isBest: Bool = false) -> some View {
        Button { purchaseSelection = .starPack(stars: stars) } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(width: 36, height: 36)
                    .background(.orange.opacity(0.16), in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(stars) Stars")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        if isBest {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: .capsule)
                        }
                    }
                    if let discount {
                        Text("Save \(discount)%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Text("Starter pack")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(price)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(isBest ? Color.green.opacity(0.4) : Color.white.opacity(0.06), lineWidth: isBest ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var starSourcesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "How You Earn Stars", subtitle: "Stars cannot be farmed from normal gameplay.")
                sourceRow(icon: "gift.fill", tint: .pink, title: "Sign-up Bonus", detail: "+100 ★ when you create an account")
                sourceRow(icon: "sun.max.fill", tint: .green, title: "Daily Reward", detail: "+10 ★ every day")
                sourceRow(icon: "crown.fill", tint: .indigo, title: "8PartyPlay+", detail: "AI cards cost just 1 ★ instead of 5")
            }
        }
    }

    private func sourceRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.bold))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var restorePurchasesRow: some View {
        Button {
            Task { await store.restore() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                Text("Restore Purchases")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func feedbackCard(_ feedback: EconomyFeedback) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedbackIcon(feedback.style))
                .font(.headline)
                .foregroundStyle(feedbackTint(feedback.style))
                .frame(width: 40, height: 40)
                .background(feedbackTint(feedback.style).opacity(0.16), in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                Text(feedback.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("OK") { appModel.clearEconomyFeedback() }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.78), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.05))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent History")
                .font(.headline)
            let recent = appModel.starWallet.recentTransactions
            if recent.isEmpty {
                ContentUnavailableView("No Activity", systemImage: "wallet.pass", description: Text("Star transactions appear here."))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            } else {
                ForEach(Array(recent.prefix(10))) { transaction in
                    HStack(spacing: 12) {
                        Image(systemName: transaction.type.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(transaction.type.tint)
                            .frame(width: 38, height: 38)
                            .background(transaction.type.tint.opacity(0.16), in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.type.displayTitle)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(transaction.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text("\(transaction.isPositive ? "+" : "")\(transaction.amount) ★")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(transaction.isPositive ? .green : .orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.04), in: .rect(cornerRadius: 16))
                }
            }
        }
    }

    private func feedbackIcon(_ style: EconomyFeedbackStyle) -> String {
        switch style {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func feedbackTint(_ style: EconomyFeedbackStyle) -> Color {
        switch style {
        case .success: return .green
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}



struct ProfileView: View {
    let appModel: AppViewModel
    let store: StoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showLogoutConfirm: Bool = false
    @State private var showLoginConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var purchaseSelection: PurchaseSelection?

    private var contextGame: GameType? { appModel.profileContextGame }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        compactIdentityCard
                        if appModel.currentProvider == .guest {
                            loginPromptCard
                        }
                        if let game = contextGame {
                            gameContextCard(game: game)
                        }
                        walletSection
                        preferencesCard
                        if appModel.currentProvider != .guest {
                            dangerZoneCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if appModel.currentProvider != .guest {
                        Button("Save") {
                            appModel.saveProfileChanges(username: username, avatarSymbol: appModel.avatarSymbol)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .dismissKeyboardOnTap()
        .onAppear {
            username = appModel.username
        }
        .sheet(item: $purchaseSelection) { selection in
            PurchaseDetailView(selection: selection, store: store)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    appModel.profileImageData = data
                }
            }
        }
        .confirmationDialog("Exit active game?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Logout & Exit Game", role: .destructive) {
                appModel.dismissSession()
                appModel.logout()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have an active game session. Logging out will end the game.")
        }
        .confirmationDialog("Exit active game?", isPresented: $showLoginConfirm, titleVisibility: .visible) {
            Button("Go to Login & Exit Game", role: .destructive) {
                appModel.dismissSession()
                appModel.goToLogin()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have an active game session. Going to login will end the game.")
        }
        .confirmationDialog("Delete Account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) {
                appModel.dismissSession()
                appModel.deleteAccount()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all game data, friends, and wallet. This action cannot be undone.")
        }
    }

    private var loginPromptCard: some View {
        Button("Login or Sign Up") {
            if appModel.activeSession != nil {
                showLoginConfirm = true
            } else {
                appModel.goToLogin()
                dismiss()
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }

    private func gameContextCard(game: GameType) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: game.symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(.blue.opacity(0.14), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.name)
                            .viralTitleStyle(size: 17, weight: .black)
                        Text("Your stats for this game")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text("Tap below to start a new round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var compactIdentityCard: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let data = appModel.profileImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 58, height: 58)
                                    .clipShape(.circle)
                            } else {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue.opacity(0.55), .purple.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 58, height: 58)
                                    .overlay {
                                        Image(systemName: appModel.avatarSymbol)
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                            }
                        }
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
                        }
                        Circle()
                            .fill(.black.opacity(0.72))
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(appModel.currentProvider == .guest ? "Guest" : "@\(appModel.username)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(appModel.currentProvider == .guest ? .orange : .green)
                            .frame(width: 6, height: 6)
                        Text(appModel.currentProvider == .guest ? "Not logged in" : "\(appModel.currentProvider.title) account")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let pid = appModel.publicUserID {
                        Text("ID #\(pid)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var dangerZoneCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Account", subtitle: "Log out or permanently delete your account.")
                Button {
                    if appModel.activeSession != nil {
                        showLogoutConfirm = true
                    } else {
                        appModel.logout()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline.weight(.semibold))
                        Text("Log Out")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.15))
                    }
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Delete Account")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.12), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.red.opacity(0.25))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var membershipStatusLabel: String {
        if store.isLifetime { return "Lifetime access active" }
        if store.isPremium {
            if let tier = store.currentTier { return "\(tier.displayName) \u{2022} Active" }
            return "Premium \u{2022} Active"
        }
        return "Free plan"
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Wallet", subtitle: "Stars, membership, and unlocks.")

            SurfaceCard {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(width: 38, height: 38)
                        .background(.orange.opacity(0.16), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Stars balance")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(appModel.starsBalance.formatted(.number.grouping(.automatic)))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                    Text("Public Rooms")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: store.isPremium ? "crown.fill" : "lock.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(store.isPremium ? .orange : .secondary)
                            .frame(width: 40, height: 40)
                            .background((store.isPremium ? Color.orange : Color.white).opacity(store.isPremium ? 0.16 : 0.06), in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Membership")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(membershipStatusLabel)
                                .font(.subheadline.weight(.bold))
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(spacing: 8) {
                        walletPlanRow(tier: .weekly, price: "$4.99", stars: 40, accent: .blue)
                        walletPlanRow(tier: .monthly, price: "$6.99", stars: 120, accent: .orange)
                        walletPlanRow(tier: .yearly, price: "$29.99", stars: 500, accent: .purple, badge: "BEST VALUE")
                        walletPlanRow(tier: .lifetime, price: "$49.99", stars: nil, accent: .pink, subtitle: "One-time \u{2022} Forever")
                    }
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderView(title: "Star Packs", subtitle: "Tap to purchase.")
                    VStack(spacing: 8) {
                        walletPackRow(price: "$0.99", stars: 50, discount: nil)
                        walletPackRow(price: "$2.99", stars: 200, discount: 25)
                        walletPackRow(price: "$4.99", stars: 400, discount: 37)
                        walletPackRow(price: "$9.99", stars: 1000, discount: 50, isBest: true)
                    }
                }
            }

            Button {
                Task { await store.restore() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                    Text("Restore Purchases")
                        .font(.footnote.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private func walletPlanRow(tier: SubscriptionTier, price: String, stars: Int?, accent: Color, subtitle: String? = nil, badge: String? = nil) -> some View {
        Button { purchaseSelection = .subscription(tier) } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(accent, lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tier.displayName).font(.subheadline.weight(.bold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: .capsule)
                        }
                    }
                    if let subtitle {
                        Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                    } else if let stars {
                        Text("+\(stars) \u{2605} per period").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(price).font(.subheadline.weight(.bold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.04), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func walletPackRow(price: String, stars: Int, discount: Int?, isBest: Bool = false) -> some View {
        Button { purchaseSelection = .starPack(stars: stars) } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(width: 36, height: 36)
                    .background(.orange.opacity(0.16), in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(stars) Stars").font(.subheadline.weight(.bold))
                        if isBest {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: .capsule)
                        }
                    }
                    if let discount {
                        Text("Save \(discount)%").font(.caption2.weight(.bold)).foregroundStyle(.green)
                    } else {
                        Text("Starter pack").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(price).font(.subheadline.weight(.heavy))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isBest ? Color.green.opacity(0.4) : Color.white.opacity(0.06), lineWidth: isBest ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var preferencesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Preferences", subtitle: "Sound and feedback settings.")

                Toggle(isOn: Binding(get: { appModel.isSoundEnabled }, set: { appModel.isSoundEnabled = $0 })) {
                    Label("Sound", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                }

                Toggle(isOn: Binding(get: { appModel.isVibrationEnabled }, set: { appModel.isVibrationEnabled = $0 })) {
                    Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.subheadline)
                }

                Divider().padding(.vertical, 2)

                Link(destination: LegalLinks.privacyPolicyURL) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Link(destination: LegalLinks.termsOfServiceURL) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(destination: url) {
                        HStack {
                            Label("Manage Subscription", systemImage: "creditcard.fill")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await store.restore() }
                } label: {
                    HStack {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

            }
        }
    }
}
