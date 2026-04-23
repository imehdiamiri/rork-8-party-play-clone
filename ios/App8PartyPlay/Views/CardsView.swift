import SwiftUI

enum CardsDestination: Hashable {
    case deck(CardCategory)
    case aiGenerate
}

// MARK: - Root

struct CardsRootView: View {
    let appModel: AppViewModel
    let store: StoreViewModel
    let showProfile: () -> Void
    @State private var viewModel = CardsViewModel()
    @State private var path: [CardsDestination] = []
    @State private var showPaywall: Bool = false
    @State private var showSaved: Bool = false

    private let compactColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        PartyToolsSection(showsHeader: false)
                        cardsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CardsDestination.self) { dest in
                switch dest {
                case .deck(let category):
                    CardsDeckView(
                        category: category,
                        viewModel: viewModel,
                        store: store,
                        onUnlock: { showPaywall = true }
                    )
                case .aiGenerate:
                    AICardGeneratorView(store: store, appModel: appModel, onUnlock: { showPaywall = true })
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
            .sheet(isPresented: $showSaved) {
                SavedCardsSheet(viewModel: viewModel)
            }
        }
    }

    private var totalCardsCount: Int {
        CardCategory.allCases.reduce(0) { $0 + viewModel.count(for: $1) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PARTY KIT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
                Text("Tools")
                    .viralTitleStyle(size: 20, weight: .black)
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            Button {
                showSaved = true
            } label: {
                Image(systemName: viewModel.savedCardIDs.isEmpty ? "bookmark" : "bookmark.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.08), in: .circle)
                    .overlay { Circle().strokeBorder(.white.opacity(0.1)) }
            }
            .buttonStyle(.plain)
            ProfileToolbarButton(
                systemImage: appModel.avatarSymbol,
                accessibilityLabel: "Profile",
                imageData: appModel.profileImageData,
                action: showProfile
            )
        }
        .padding(.top, 4)
    }

    private var heroBanner: some View {
        let count = totalCardsCount
        return HStack(alignment: .center, spacing: 14) {
            // Stacked deck visual on the left
            ZStack {
                deckLayer(rot: -12, offset: CGSize(width: -10, height: 6), colors: [Color(white: 0.22), Color(white: 0.16)])
                deckLayer(rot: 6, offset: CGSize(width: 6, height: -4), colors: [Color(white: 0.28), Color(white: 0.20)])
                deckLayer(rot: -2, offset: .zero, colors: [.white.opacity(0.95), .white.opacity(0.85)], glyph: true)
            }
            .frame(width: 82, height: 108)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(count)")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("cards")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text("Pre-ready prompts for anything.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.black
                .clipShape(.rect(cornerRadius: 22))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.08))
        }
    }

    private func deckLayer(rot: Double, offset: CGSize, colors: [Color], glyph: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
            }
            .overlay {
                if glyph {
                    Text("8")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black.opacity(0.75))
                }
            }
            .frame(width: 62, height: 90)
            .rotationEffect(.degrees(rot))
            .offset(offset)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }

    private var aiGenerateRow: some View {
        Button {
            SoundManager.shared.playNavigation()
            path.append(.aiGenerate)
        } label: {
            AIGenerateRow()
        }
        .buttonStyle(CardPressStyle())
        .slideUpOnAppear(delay: 0)
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CARD LIBRARY")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                    Text("Ready to Use Cards")
                        .viralTitleStyle(size: 20, weight: .black)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(totalCardsCount)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.08), in: .capsule)
                    Image(systemName: "rectangle.on.rectangle.angled.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(spacing: 10) {
                aiGenerateRow
                VStack(spacing: 8) {
                    ForEach(Array(CardCategory.allCases.enumerated()), id: \.element.id) { index, category in
                        Button {
                            SoundManager.shared.playNavigation()
                            path.append(.deck(category))
                        } label: {
                            CategoryListRow(
                                category: category,
                                count: viewModel.count(for: category)
                            )
                        }
                        .buttonStyle(CardPressStyle())
                        .slideUpOnAppear(delay: Double(index + 1) * 0.04)
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.03), in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.06))
            }
        }
        .padding(.top, 4)
    }
}

private struct AIGenerateRow: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .purple.opacity(0.45), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("AI Generate")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("NEW")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                            in: .capsule
                        )
                }
                Text("Give a topic. Get instant cards.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.08), in: .circle)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.22), .blue.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [.purple.opacity(0.55), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct CategoryListRow: View {
    let category: CardCategory
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [category.accentColor.opacity(0.55), category.accentColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(category.accentColor.opacity(0.5), lineWidth: 1)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .shadow(color: category.accentColor.opacity(0.35), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .viralTitleStyle(size: 19, weight: .black)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(category.subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(category.accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(category.accentColor.opacity(0.15), in: .capsule)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.06))
        }
    }
}

private struct CategoryRow: View {
    let category: CardCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [category.accentColor.opacity(0.55), category.accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(category.accentColor.opacity(0.5), lineWidth: 1)
                    Image(systemName: category.icon)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .shadow(color: category.accentColor.opacity(0.35), radius: 6, y: 3)

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundStyle(category.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(category.accentColor.opacity(0.15), in: .capsule)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .viralTitleStyle(size: 19, weight: .black)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(category.subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("Open")
                Image(systemName: "arrow.right")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(category.accentColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06))
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + verticalSpacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Deck View

struct CardsDeckView: View {
    let category: CardCategory
    var viewModel: CardsViewModel
    var store: StoreViewModel
    let onUnlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentCard: PartyCard?
    @State private var selectedSubtype: CardSubtype?
    @State private var includeSpicy: Bool = false
    @State private var flipTrigger: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var cardCounter: Int = 0
    @State private var showFilters: Bool = true

    var body: some View {
        ZStack {
            AppBackgroundView()
            // Ambient glow that reflects the category tint
            RadialGradient(
                colors: [category.accentColor.opacity(0.22), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                if showFilters {
                    filtersPanel
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                cardArea
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                actionBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if currentCard == nil {
                loadNext(animated: false)
            }
        }
        .onChange(of: selectedSubtype) { _, _ in loadNext() }
        .onChange(of: includeSpicy) { _, _ in loadNext() }
        .sensoryFeedback(.impact(weight: .light), trigger: flipTrigger)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.08), in: .circle)
                    .overlay { Circle().strokeBorder(.white.opacity(0.1)) }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(category.accentColor)
                    .frame(width: 26, height: 26)
                    .background(category.accentColor.opacity(0.18), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .viralTitleStyle(size: 22, weight: .black)
                        .foregroundStyle(.white)
                    Text("Card #\(max(1, cardCounter))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.5)
                }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showFilters.toggle()
                }
            } label: {
                Image(systemName: showFilters ? "slider.horizontal.3" : "slider.horizontal.below.rectangle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(showFilters ? .black : .white)
                    .frame(width: 38, height: 38)
                    .background(showFilters ? Color.white : Color.white.opacity(0.08), in: .circle)
                    .overlay { Circle().strokeBorder(.white.opacity(0.1)) }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Filters Panel

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("TYPE")
                        .font(.system(size: 9.5, weight: .heavy))
                        .tracking(1.4)
                }
                .foregroundStyle(.white.opacity(0.5))

                FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    subtypeChip(title: "All", isSelected: selectedSubtype == nil) {
                        withAnimation(.spring(duration: 0.2)) { selectedSubtype = nil }
                    }
                    ForEach(category.subtypes) { sub in
                        subtypeChip(
                            title: sub.title,
                            isSelected: selectedSubtype == sub,
                            isFeatured: sub.isFeatured
                        ) {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedSubtype = (selectedSubtype == sub) ? nil : sub
                            }
                        }
                    }
                }
            }

            Divider().overlay(.white.opacity(0.06))

            // Content toggles
            // SAFETY NOTE: Only a single "Spicy" toggle exists. No 18+ gating is
            // present in the app. All cards are reviewable in `CardDeckSeed`
            // and are appropriate for general social settings.
            HStack(spacing: 8) {
                contentToggle(
                    title: "Spicy",
                    icon: "flame.fill",
                    isOn: includeSpicy,
                    tint: .orange
                ) {
                    withAnimation(.spring(duration: 0.2)) { includeSpicy.toggle() }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.06))
        }
    }

    private func subtypeChip(title: String, isSelected: Bool, isFeatured: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isFeatured {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .black))
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.2)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .black : isFeatured ? category.accentColor : .white.opacity(0.75))
            .background(
                isSelected ? Color.white
                : isFeatured ? category.accentColor.opacity(0.15) : Color.white.opacity(0.05),
                in: .capsule
            )
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? .clear
                    : isFeatured ? category.accentColor.opacity(0.45) : .white.opacity(0.08)
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func contentToggle(title: String, icon: String, isOn: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .heavy))
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                ZStack {
                    Capsule()
                        .fill(isOn ? tint : .white.opacity(0.12))
                        .frame(width: 24, height: 14)
                    Circle()
                        .fill(.white)
                        .frame(width: 11, height: 11)
                        .offset(x: isOn ? 5 : -5)
                        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(isOn ? tint : .white.opacity(0.65))
            .background(isOn ? tint.opacity(0.14) : .white.opacity(0.05), in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(isOn ? tint.opacity(0.4) : .white.opacity(0.06))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Card Area

    @ViewBuilder
    private var cardArea: some View {
        if let card = currentCard {
            let locked = viewModel.isLocked(card, isPremium: store.isPremium)
            ZStack {
                // Back stack cards (parallax feel)
                RoundedRectangle(cornerRadius: 26)
                    .fill(.white.opacity(0.05))
                    .aspectRatio(0.78, contentMode: .fit)
                    .scaleEffect(0.88)
                    .offset(y: 22)
                    .blur(radius: 0.5)

                RoundedRectangle(cornerRadius: 26)
                    .fill(.white.opacity(0.08))
                    .aspectRatio(0.78, contentMode: .fit)
                    .scaleEffect(0.94)
                    .offset(y: 11)

                cardFace(card: card, locked: locked)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 22), anchor: .bottom)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !locked else { return }
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                if abs(value.translation.width) > 110 || abs(value.translation.height) > 130 {
                                    withAnimation(.spring(duration: 0.3)) {
                                        dragOffset = CGSize(
                                            width: value.translation.width * 3,
                                            height: value.translation.height * 2
                                        )
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                        loadNext()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    .id(card.id)
                    .transition(.asymmetric(
                        insertion: .modifier(
                            active: CardEnterModifier(progress: 0),
                            identity: CardEnterModifier(progress: 1)
                        ),
                        removal: .opacity
                    ))
            }
            .frame(maxWidth: .infinity)
        } else {
            RoundedRectangle(cornerRadius: 26)
                .fill(.white.opacity(0.04))
                .aspectRatio(0.78, contentMode: .fit)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No cards match those filters")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text("Try turning off Spicy")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.08))
                }
        }
    }

    private func cardFace(card: PartyCard, locked: Bool) -> some View {
        ZStack {
            // Base
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.99), Color(white: 0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Accent ribbon at top
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [category.accentColor, category.accentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 6)
                Spacer()
            }
            .clipShape(.rect(cornerRadius: 26))

            // Faint watermark icon
            Image(systemName: category.icon)
                .font(.system(size: 180, weight: .black))
                .foregroundStyle(category.accentColor.opacity(0.05))
                .rotationEffect(.degrees(-12))
                .offset(x: 40, y: 20)
                .clipShape(.rect(cornerRadius: 26))

            VStack(spacing: 0) {
                // Top meta
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title.uppercased())
                            .viralTitleStyle(size: 11, weight: .black)
                            .tracking(1.8)
                            .foregroundStyle(category.accentColor)
                        Text(card.subtype.title)
                            .viralTitleStyle(size: 13, weight: .heavy)
                            .foregroundStyle(.black.opacity(0.4))
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        if card.isSpicy {
                            badge(text: "SPICY", systemImage: "flame.fill", color: .orange)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                Spacer(minLength: 0)

                // Prompt text
                Text(card.text)
                    .viralTitleStyle(size: 30, weight: .black)
                    .foregroundStyle(.black.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 26)
                    .blur(radius: locked ? 18 : 0)

                Spacer(minLength: 0)

                // Bottom meta
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10, weight: .black))
                        Text("8PartyPlay")
                            .viralTitleStyle(size: 11, weight: .heavy)
                            .tracking(0.5)
                    }
                    .foregroundStyle(.black.opacity(0.3))
                    Spacer()
                    Text(String(format: "N°%03d", max(1, cardCounter)))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.35))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }

            if locked {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                    Text("Premium Card")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                    Button {
                        onUnlock()
                    } label: {
                        Text("Unlock")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background(.black.opacity(0.6), in: .rect(cornerRadius: 20))
            }
        }
        .clipShape(.rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.black.opacity(0.08))
        }
        .shadow(color: category.accentColor.opacity(0.25), radius: 24, y: 14)
        .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.78, contentMode: .fit)
        .onTapGesture {
            if locked { onUnlock() }
        }
    }

    private func badge(text: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .black))
            Text(text)
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color, in: .capsule)
    }

    // MARK: Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            iconButton(
                systemImage: (currentCard.map { viewModel.isSaved($0) } ?? false) ? "bookmark.fill" : "bookmark",
                tint: (currentCard.map { viewModel.isSaved($0) } ?? false) ? .yellow : .white
            ) {
                if let card = currentCard {
                    viewModel.toggleSaved(card)
                    SoundManager.shared.playButtonTap()
                }
            }
            .disabled(currentCard == nil)

            Button {
                loadNext()
                SoundManager.shared.playButtonTap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.accentColor.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(category.accentColor)
                    }
                    Text("Draw Next")
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(0.2)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.12), in: .circle)
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.16), Color(white: 0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [category.accentColor.opacity(0.55), category.accentColor.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: category.accentColor.opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(.plain)

            iconButton(systemImage: "shuffle", tint: .white) {
                loadNext()
                SoundManager.shared.playButtonTap()
            }
        }
    }

    private func iconButton(systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.06), in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.1)) }
        }
        .buttonStyle(.plain)
    }

    private func loadNext(animated: Bool = true) {
        let next = viewModel.randomCard(
            category: category,
            subtype: selectedSubtype,
            includeSpicy: includeSpicy,
            excluding: currentCard?.id
        )
        if animated {
            withAnimation(.spring(duration: 0.4, bounce: 0.18)) {
                currentCard = next
                dragOffset = .zero
            }
        } else {
            currentCard = next
            dragOffset = .zero
        }
        if next != nil { cardCounter += 1 }
        flipTrigger &+= 1
    }
}

private struct CardEnterModifier: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.88 + 0.12 * progress)
            .opacity(progress)
            .offset(y: (1 - progress) * 24)
    }
}

private struct SavedCardsSheet: View {
    var viewModel: CardsViewModel
    @Environment(\.dismiss) private var dismiss

    private var saved: [PartyCard] {
        CardDeckSeed.all.filter { viewModel.savedCardIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if saved.isEmpty {
                    ContentUnavailableView(
                        "No Saved Cards",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark on any card to save it here.")
                    )
                } else {
                    List {
                        ForEach(saved) { card in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.category.title.uppercased())
                                    .viralTitleStyle(size: 11, weight: .heavy)
                                    .tracking(1.2)
                                    .foregroundStyle(card.category.accentColor)
                                Text(card.text)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.toggleSaved(card)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
