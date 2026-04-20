import SwiftUI

nonisolated struct AIGeneratedCard: Identifiable, Hashable, Sendable {
    let id = UUID()
    let text: String
    let category: CardCategory
    let subtype: CardSubtype?
    let isSpicy: Bool
    let is18Plus: Bool
}

@Observable
@MainActor
final class AICardGeneratorViewModel {
    var category: CardCategory = .talk
    var subtype: CardSubtype? = nil
    var topic: String = ""
    var includeSpicy: Bool = false
    var include18Plus: Bool = false
    var isGenerating: Bool = false
    var card: AIGeneratedCard?
    var errorMessage: String?

    var usageToday: Int {
        let key = todayKey()
        return UserDefaults.standard.integer(forKey: key)
    }

    static let freeDailyLimit: Int = 5

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "ai.cards.usage.\(f.string(from: Date()))"
    }

    func bumpUsage() {
        let key = todayKey()
        UserDefaults.standard.set(usageToday + 1, forKey: key)
    }

    func remaining(isPremium: Bool) -> Int {
        if isPremium { return .max }
        return max(0, Self.freeDailyLimit - usageToday)
    }

    func ensureSubtypeIsValid() {
        if let sub = subtype, !category.subtypes.contains(sub) {
            subtype = nil
        }
    }

    func generate(isPremium: Bool) async {
        guard !isGenerating else { return }
        if !isPremium && remaining(isPremium: false) <= 0 {
            errorMessage = "Daily limit reached. Upgrade for unlimited."
            return
        }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let spicyLine: String
        switch (includeSpicy, include18Plus) {
        case (false, false): spicyLine = "Normal level. Safe and general. Not flirty, not adult."
        case (true, false): spicyLine = "Spicy level. Playful, flirty, slightly bold, but still group-safe. Not adult."
        case (false, true): spicyLine = "18+ level. More personal or intimate, but NOT explicit. Still socially acceptable."
        case (true, true): spicyLine = "Spicy and 18+ level. Flirty and intimate but NOT explicit."
        }

        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let userRequest = trimmed.isEmpty ? "(no specific request)" : trimmed
        let subtypeLine: String
        if let sub = subtype {
            subtypeLine = "Subtype: \(sub.title). \(subtypeDescription(sub))"
        } else {
            subtypeLine = "Subtype: any subtype of this category."
        }

        let system = "You are a party game card writer. Return ONLY valid JSON. No markdown, no code fences."
        let user = """
        Generate ONE party game card.

        Category: \(category.title). \(categoryRule(category))
        \(subtypeLine)
        User request: \(userRequest)
        \(spicyLine)

        Rules:
        - Exactly ONE sentence
        - No emojis
        - No quotation marks
        - No explanation
        - Under 20 words
        - Natural, human-like
        - Must match the category behavior exactly
        - Suitable for group play

        Return strictly this JSON:
        {"text":"..."}
        """

        do {
            let completion = try await LLMService.complete(system: system, user: user)
            let cleaned = LLMService.stripCodeFences(completion)
            guard let data = cleaned.data(using: .utf8) else {
                errorMessage = "Couldn't read response."
                return
            }
            let decoded = try JSONDecoder().decode(Payload.self, from: data)
            let text = decoded.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !text.isEmpty else {
                errorMessage = "Empty response. Try again."
                return
            }
            let newCard = AIGeneratedCard(
                text: text,
                category: category,
                subtype: subtype,
                isSpicy: includeSpicy,
                is18Plus: include18Plus
            )
            withAnimation(.spring(duration: 0.4, bounce: 0.18)) {
                card = newCard
            }
            if !isPremium { bumpUsage() }
        } catch {
            errorMessage = "Generation failed. Try again."
        }
    }

    private func categoryRule(_ c: CardCategory) -> String {
        switch c {
        case .act: return "Must be something to perform physically. Short and actable."
        case .talk: return "Must be a question or discussion prompt."
        case .challenges: return "Must include a rule, time, or condition."
        case .penalty: return "Must feel like a punishment for losing. Short and immediate."
        case .couple: return "Must involve a relationship or two people."
        }
    }

    private func subtypeDescription(_ s: CardSubtype) -> String {
        switch s {
        case .pantomime: return "Silent acting, no words."
        case .dare: return "A bold thing to do right now."
        case .funnyAction: return "A silly physical performance."
        case .starters: return "Easy conversation starter for new people."
        case .personal: return "Personal question about the player."
        case .discussion: return "Open topic the group can debate."
        case .truth: return "Honest confession question."
        case .explainGuess: return "A word or scene to explain or guess."
        case .icebreaker: return "Light playful warm up prompt."
        case .speech: return "A rule about how the player talks."
        case .behavior: return "A rule about how the player acts or moves."
        case .timeLimit: return "Must be done within a short time."
        case .penaltyFunny: return "A silly, funny consequence."
        case .embarrassing: return "A mildly embarrassing consequence."
        case .groupChoice: return "The group picks the punishment style."
        case .coupleQuestions: return "Question for a couple or pair."
        case .dynamics: return "Prompt about relationship dynamics."
        case .playful: return "Playful task between two people."
        }
    }

    nonisolated private struct Payload: Decodable, Sendable {
        let text: String
    }
}

struct AICardGeneratorView: View {
    var store: StoreViewModel
    var appModel: AppViewModel
    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var vm = AICardGeneratorViewModel()

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(spacing: 12) {
                    header
                    controlsCard
                    generateButton
                    if let error = vm.errorMessage {
                        errorBanner(error)
                    }
                    cardArea
                    usageFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: vm.category) { _, _ in
            vm.ensureSubtypeIsValid()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: .circle)
                    .overlay { Circle().strokeBorder(.white.opacity(0.1)) }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.purple)
                Text("Create a Card")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            if !store.isPremium {
                Text("\(vm.remaining(isPremium: false))/\(AICardGeneratorViewModel.freeDailyLimit)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: .capsule)
                    .overlay { Capsule().strokeBorder(.white.opacity(0.1)) }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .black))
                    Text("PRO")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                    in: .capsule
                )
            }
        }
    }

    // MARK: Controls card (combines category, type, idea, filters)

    private var controlsCard: some View {
        VStack(spacing: 10) {
            optionsContainer
            ideaContainer
        }
    }

    private var optionsContainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            categoryDropdown
            subtypeDropdown
            filterToggles
        }
        .padding(14)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.06))
        }
    }

    private var ideaContainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            inputField
        }
        .padding(14)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.06))
        }
    }

    private var categoryDropdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("CARD TYPE", icon: "square.grid.2x2.fill")
            Menu {
                ForEach(CardCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            vm.category = cat
                            vm.subtype = nil
                        }
                    } label: {
                        Label(cat.title, systemImage: cat.icon)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.category.icon)
                        .font(.system(size: 12, weight: .black))
                    Text(vm.category.title)
                        .font(.system(size: 13, weight: .heavy))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(vm.category.accentColor)
                .background(vm.category.accentColor.opacity(0.12), in: .capsule)
                .overlay {
                    Capsule().strokeBorder(vm.category.accentColor.opacity(0.4))
                }
            }
        }
    }

    private var subtypeDropdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("STYLE", icon: "tag.fill")
            Menu {
                Button {
                    withAnimation(.spring(duration: 0.2)) { vm.subtype = nil }
                } label: {
                    Label("Any", systemImage: "sparkles")
                }
                ForEach(vm.category.subtypes) { sub in
                    Button {
                        withAnimation(.spring(duration: 0.2)) { vm.subtype = sub }
                    } label: {
                        Text(sub.title)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.subtype == nil ? "sparkles" : "tag.fill")
                        .font(.system(size: 11, weight: .black))
                    Text(vm.subtype?.title ?? "Any")
                        .font(.system(size: 13, weight: .heavy))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(.white.opacity(0.9))
                .background(.white.opacity(0.05), in: .capsule)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.1))
                }
            }
        }
    }

    // MARK: Category chips

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CARD TYPE", icon: "square.grid.2x2.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CardCategory.allCases) { cat in
                        categoryChip(cat)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private func categoryChip(_ cat: CardCategory) -> some View {
        let isSelected = vm.category == cat
        return Button {
            withAnimation(.spring(duration: 0.22)) {
                vm.category = cat
                vm.subtype = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 11, weight: .black))
                Text(cat.title)
                    .font(.system(size: 12, weight: .heavy))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : cat.accentColor)
            .background(
                isSelected ? cat.accentColor : cat.accentColor.opacity(0.12),
                in: .capsule
            )
            .overlay {
                Capsule().strokeBorder(isSelected ? .clear : cat.accentColor.opacity(0.4))
            }
            .shadow(color: isSelected ? cat.accentColor.opacity(0.4) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: Subtype chips

    private var subtypeChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("STYLE", icon: "tag.fill")
            FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                subtypeChip(title: "Any", isSelected: vm.subtype == nil) {
                    withAnimation(.spring(duration: 0.2)) { vm.subtype = nil }
                }
                ForEach(vm.category.subtypes) { sub in
                    subtypeChip(
                        title: sub.title,
                        isSelected: vm.subtype == sub,
                        isFeatured: sub.isFeatured
                    ) {
                        withAnimation(.spring(duration: 0.2)) {
                            vm.subtype = (vm.subtype == sub) ? nil : sub
                        }
                    }
                }
            }
        }
    }

    private func subtypeChip(title: String, isSelected: Bool, isFeatured: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isFeatured {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .black))
                }
                Text(title)
            }
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .black : isFeatured ? vm.category.accentColor : .white.opacity(0.75))
            .background(
                isSelected ? Color.white
                : isFeatured ? vm.category.accentColor.opacity(0.15) : Color.white.opacity(0.05),
                in: .capsule
            )
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? .clear
                    : isFeatured ? vm.category.accentColor.opacity(0.4) : .white.opacity(0.08)
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Input

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("YOUR IDEA (OPTIONAL)", icon: "text.cursor")
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                TextField(placeholder(for: vm.category), text: $vm.topic, axis: .vertical)
                    .lineLimit(1...2)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(.purple)
                    .submitLabel(.go)
                    .onSubmit {
                        if appModel.spendStarsForAI(isPremium: store.isPremium) {
                            Task { await vm.generate(isPremium: true) }
                        }
                    }
                if !vm.topic.isEmpty {
                    Button { vm.topic = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08))
            }
        }
    }

    private func placeholder(for category: CardCategory) -> String {
        switch category {
        case .talk: return "e.g. create a conversation starter for new friends"
        case .couple: return "e.g. create a playful question about their relationship"
        case .act: return "e.g. create a funny acting scenario"
        case .challenges: return "e.g. create a short speaking challenge"
        case .penalty: return "e.g. create a funny punishment for the loser"
        }
    }

    // MARK: Filter toggles

    private var filterToggles: some View {
        HStack(spacing: 8) {
            compactToggleChip(title: "Spicy", icon: "flame.fill", isOn: vm.includeSpicy, tint: .orange) {
                withAnimation(.spring(duration: 0.25, bounce: 0.2)) { vm.includeSpicy.toggle() }
            }
            compactToggleChip(title: "18+", icon: "lock.fill", isOn: vm.include18Plus, tint: .red) {
                withAnimation(.spring(duration: 0.25, bounce: 0.2)) { vm.include18Plus.toggle() }
            }
        }
    }

    private func compactToggleChip(title: String, icon: String, isOn: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(isOn ? tint : .white.opacity(0.5))
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                iosSwitch(isOn: isOn, tint: tint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                (isOn ? tint.opacity(0.09) : Color.white.opacity(0.04)),
                in: .rect(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isOn ? tint.opacity(0.35) : .white.opacity(0.07))
            }
        }
        .buttonStyle(.plain)
    }

    private func iosSwitch(isOn: Bool, tint: Color) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? tint : Color.white.opacity(0.18))
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .padding(2)
        }
        .frame(width: 36, height: 22)
        .animation(.spring(duration: 0.25, bounce: 0.2), value: isOn)
    }

    // MARK: Generate button

    private var generateButton: some View {
        let cost = appModel.aiStarCost(isPremium: store.isPremium)
        let outOfStars = appModel.starsBalance < cost
        return Button {
            if outOfStars {
                onUnlock()
            } else {
                if appModel.spendStarsForAI(isPremium: store.isPremium) {
                    Task { await vm.generate(isPremium: true) }
                }
            }
            SoundManager.shared.playButtonTap()
        } label: {
            HStack(spacing: 8) {
                if vm.isGenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: outOfStars ? "cart.fill" : "sparkles")
                        .font(.system(size: 14, weight: .black))
                }
                Text(
                    outOfStars ? "Get More Stars"
                    : vm.isGenerating ? "Generating…"
                    : (vm.card == nil ? "Generate for \(cost) ★" : "Generate Again (\(cost) ★)")
                )
                .font(.system(size: 15, weight: .black))
                .tracking(0.3)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: outOfStars ? [.orange, .pink] : [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .capsule
            )
            .shadow(color: (outOfStars ? Color.orange : Color.purple).opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(vm.isGenerating)
    }

    // MARK: Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
            Button {
                if appModel.spendStarsForAI(isPremium: store.isPremium) {
                    Task { await vm.generate(isPremium: true) }
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.15), in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.3))
        }
    }

    // MARK: Card area

    @ViewBuilder
    private var cardArea: some View {
        if let card = vm.card {
            cardFace(card: card)
                .id(card.id)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                    removal: .opacity
                ))
        } else if vm.isGenerating {
            placeholder(icon: "sparkles", title: "Creating your card…", subtitle: "Just a moment")
        } else {
            placeholder(icon: "wand.and.stars", title: "Your card appears here", subtitle: "Pick a category and hit generate")
        }
    }

    private func placeholder(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.7))
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(.white.opacity(0.1))
        }
    }

    private func cardFace(card: AIGeneratedCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.99), Color(white: 0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Accent ribbon
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [card.category.accentColor, card.category.accentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 6)
                Spacer()
            }
            .clipShape(.rect(cornerRadius: 24))

            // Watermark
            Image(systemName: card.category.icon)
                .font(.system(size: 150, weight: .black))
                .foregroundStyle(card.category.accentColor.opacity(0.06))
                .rotationEffect(.degrees(-12))
                .offset(x: 40, y: 10)
                .clipShape(.rect(cornerRadius: 24))

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .black))
                            Text("AI GENERATE")
                                .font(.system(size: 9.5, weight: .black))
                                .tracking(1.6)
                        }
                        .foregroundStyle(.purple)
                        Text(card.subtype?.title ?? card.category.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        if card.isSpicy && !card.is18Plus {
                            badge(text: "SPICY", systemImage: "flame.fill", color: .orange)
                        }
                        if card.is18Plus {
                            badge(text: "18+", systemImage: "lock.fill", color: .red)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 18)

                Text(card.text)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.black.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(7)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 22)

                Spacer(minLength: 18)

                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: card.category.icon)
                            .font(.system(size: 10, weight: .black))
                        Text(card.category.title.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                    }
                    .foregroundStyle(card.category.accentColor.opacity(0.7))
                    Spacer()
                    Text("888 · AI")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.3))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .clipShape(.rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(.black.opacity(0.06))
        }
        .shadow(color: card.category.accentColor.opacity(0.3), radius: 22, y: 12)
        .shadow(color: .black.opacity(0.35), radius: 26, y: 14)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.82, contentMode: .fit)
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

    // MARK: Usage footer

    @ViewBuilder
    private var usageFooter: some View {
        if !store.isPremium {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Free: \(AICardGeneratorViewModel.freeDailyLimit) per day. Upgrade for unlimited.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .black))
            Text(text)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.3)
        }
        .foregroundStyle(.white.opacity(0.45))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
