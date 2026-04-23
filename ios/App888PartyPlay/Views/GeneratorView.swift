import SwiftUI

nonisolated struct GeneratedPartyIdea: Identifiable, Sendable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let steps: [String]
    let tags: [String]
}

nonisolated enum GameVibe: String, CaseIterable, Identifiable, Sendable {
    case couple, funny, memory, action, cards, trivia, roleplay, challenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .couple: "Couple"
        case .funny: "Funny"
        case .memory: "Memory"
        case .action: "Action"
        case .cards: "Cards"
        case .trivia: "Trivia"
        case .roleplay: "Roleplay"
        case .challenge: "Challenge"
        }
    }

    var subtitle: String {
        switch self {
        case .couple: "games for two, dates & partners"
        case .funny: "silly, hilarious, laugh out loud"
        case .memory: "remember, recall and match"
        case .action: "physical, fast and energetic"
        case .cards: "card-based games and decks"
        case .trivia: "quiz, questions and knowledge"
        case .roleplay: "acting, characters and storytelling"
        case .challenge: "dares, missions and tasks"
        }
    }

    var promptDescriptor: String {
        switch self {
        case .couple: "romantic / couple games designed for two players or dating couples"
        case .funny: "humor-first games built around jokes, silly prompts and laughs"
        case .memory: "memory and recall games where players remember sequences, facts or details"
        case .action: "physical action games with movement, speed or body challenges"
        case .cards: "games that use a deck of playing cards or custom drawn cards"
        case .trivia: "trivia and quiz games with questions and answers"
        case .roleplay: "roleplay and acting games where players take on characters or improvise stories"
        case .challenge: "challenge and dare games with tasks, missions and bold prompts"
        }
    }

    var icon: String {
        switch self {
        case .couple: "heart.fill"
        case .funny: "face.smiling.fill"
        case .memory: "brain.head.profile"
        case .action: "figure.run"
        case .cards: "suit.club.fill"
        case .trivia: "questionmark.circle.fill"
        case .roleplay: "theatermasks.fill"
        case .challenge: "flame.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .couple: .pink
        case .funny: .yellow
        case .memory: .teal
        case .action: .orange
        case .cards: .blue
        case .trivia: .mint
        case .roleplay: .purple
        case .challenge: .red
        }
    }
}

@Observable
@MainActor
final class GeneratorViewModel {
    var prompt: String = ""
    var playerCount: Int = 4
    var vibe: GameVibe = .funny
    var isGenerating: Bool = false
    var ideas: [GeneratedPartyIdea] = []
    var errorMessage: String?

    let minPlayers: Int = 2
    let maxPlayers: Int = 20

    func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        // SAFETY: Moderate user-provided context before calling the model.
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty && !AIContentModeration.isSafe(trimmedPrompt) {
            errorMessage = "Please choose a different context."
            return
        }

        let system = """
        \(AIContentModeration.safetySystemRules)
        You are a creative party game designer.
        Return ONLY valid JSON. No markdown, no code fences.
        """
        let userPrompt = """
        Generate 3 fresh, original, safe party game ideas for \(playerCount) players. Style: \(vibe.title) — \(vibe.promptDescriptor). Every idea MUST clearly be a \(vibe.title.lowercased()) style game and reflect that activity type in its title, description and steps. All ideas must be appropriate for a general-audience social setting.
        \(trimmedPrompt.isEmpty ? "" : "Extra context: \(trimmedPrompt)")

        Return strictly this JSON shape:
        {"ideas":[{"title":"...","description":"one sentence hook","steps":["step1","step2","step3","step4"],"tags":["tag1","tag2"]}]}
        Keep titles punchy (2-4 words). Steps should be concise and playable without materials if possible.
        """

        do {
            let completion = try await LLMService.complete(system: system, user: userPrompt)
            let cleaned = LLMService.stripCodeFences(completion)
            guard let data = cleaned.data(using: .utf8) else {
                errorMessage = "Couldn't read response."
                return
            }
            let decoded = try JSONDecoder().decode(IdeasResponse.self, from: data)
            // Final on-device moderation: filter out any idea whose fields
            // contain unsafe content. If nothing remains, surface a neutral error.
            let mapped: [GeneratedPartyIdea] = decoded.ideas.compactMap { idea in
                let fields = [idea.title, idea.description] + idea.steps + idea.tags
                for field in fields where !AIContentModeration.isSafe(field) {
                    return nil
                }
                return GeneratedPartyIdea(title: idea.title, description: idea.description, steps: idea.steps, tags: idea.tags)
            }
            if mapped.isEmpty {
                errorMessage = "Could not generate safe ideas. Try a different prompt."
                return
            }
            withAnimation(.spring(duration: 0.35)) {
                ideas = mapped + ideas
            }
        } catch {
            errorMessage = "Generation failed. Try again."
        }
    }

    nonisolated private struct IdeasResponse: Decodable, Sendable {
        let ideas: [IdeaPayload]
    }
    nonisolated private struct IdeaPayload: Decodable, Sendable {
        let title: String
        let description: String
        let steps: [String]
        let tags: [String]
    }
}

nonisolated enum LLMService {
    nonisolated struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }
    nonisolated struct Request: Encodable, Sendable {
        let messages: [Message]
    }
    nonisolated struct Response: Decodable, Sendable {
        let completion: String
    }

    static func complete(system: String, user: String) async throws -> String {
        var base = Config.EXPO_PUBLIC_TOOLKIT_URL
        if base.isEmpty {
            #if DEBUG
            assertionFailure("EXPO_PUBLIC_TOOLKIT_URL is not configured")
            #endif
            base = "https://toolkit.rork.com"
        }
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/text/llm/") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Request(messages: [
            Message(role: "system", content: system),
            Message(role: "user", content: user)
        ])
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.completion
    }

    static func stripCodeFences(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let range = s.range(of: "\n") { s = String(s[range.upperBound...]) }
            if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GeneratorView: View {
    let appModel: AppViewModel
    let showProfile: () -> Void
    @State private var vm = GeneratorViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        heroCard
                        vibeSection
                        playersAndDetailsCard
                        generateButton
                        if let error = vm.errorMessage {
                            errorBanner(error)
                        }
                        resultsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 96)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Factory")
                .viralTitleStyle(size: 20, weight: .black)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            ProfileToolbarButton(systemImage: appModel.avatarSymbol, accessibilityLabel: "Profile", imageData: appModel.profileImageData, action: showProfile)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.purple.opacity(0.55), Color.blue.opacity(0.35), Color.pink.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RadialGradient(
                    colors: [.white.opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 200
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("AI POWERED")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.15), in: .capsule)

                Text("Invent your\nnext party game")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("Pick a vibe, set your crew, and we'll cook up fresh games in seconds.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
            .padding(18)

            Image(systemName: "wand.and.stars")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(.white.opacity(0.12))
                .rotationEffect(.degrees(12))
                .offset(x: 240, y: 20)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.1))
        }
    }

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose a vibe")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(vm.vibe.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(vm.vibe.accentColor)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(GameVibe.allCases) { vibe in
                    vibeTile(vibe)
                }
            }
        }
    }

    private func vibeTile(_ vibe: GameVibe) -> some View {
        let isSelected = vm.vibe == vibe
        return Button {
            FeedbackService.shared.playClick()
            withAnimation(.spring(duration: 0.25)) { vm.vibe = vibe }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: vibe.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? .white : vibe.accentColor)
                Text(vibe.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background {
                if isSelected {
                    LinearGradient(colors: [vibe.accentColor, vibe.accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .white.opacity(0.25) : vibe.accentColor.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: isSelected ? vibe.accentColor.opacity(0.45) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var playersAndDetailsCard: some View {
        VStack(spacing: 14) {
            playersCard
            contextCard
        }
    }

    private var playersCard: some View {
        SurfaceCard {
            HStack(spacing: 10) {
                Label("Players", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer(minLength: 0)
                Button {
                    FeedbackService.shared.playClick()
                    if vm.playerCount > vm.minPlayers {
                        withAnimation(.spring(duration: 0.2)) { vm.playerCount -= 1 }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(.green.opacity(0.12), in: .circle)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(vm.playerCount <= vm.minPlayers)
                .opacity(vm.playerCount <= vm.minPlayers ? 0.3 : 1)

                Text("\(vm.playerCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .frame(minWidth: 28)

                Button {
                    FeedbackService.shared.playClick()
                    if vm.playerCount < vm.maxPlayers {
                        withAnimation(.spring(duration: 0.2)) { vm.playerCount += 1 }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(.green.opacity(0.12), in: .circle)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(vm.playerCount >= vm.maxPlayers)
                .opacity(vm.playerCount >= vm.maxPlayers ? 0.3 : 1)
            }
        }
        .sensoryFeedback(.selection, trigger: vm.playerCount)
    }

    private var contextCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Context", systemImage: "text.alignleft")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                TextField("e.g. road trip, birthday, couples…", text: $vm.prompt, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.06))
                    }
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task { await vm.generate() }
        } label: {
            HStack(spacing: 10) {
                if vm.isGenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                }
                Text(vm.isGenerating ? "Generating…" : "Generate Ideas")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.18))
            }
            .shadow(color: .purple.opacity(0.35), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(vm.isGenerating)
        .sensoryFeedback(.success, trigger: vm.ideas.count)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.ideas.isEmpty && !vm.isGenerating {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    VStack(spacing: 4) {
                        Text("Ready when you are")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Tap Generate to craft brand new games tailored to your crew.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                if !vm.ideas.isEmpty {
                    HStack {
                        Text("Your Ideas")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(vm.ideas.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.08), in: .capsule)
                    }
                    .padding(.top, 4)
                }
                ForEach(Array(vm.ideas.enumerated()), id: \.element.id) { index, idea in
                    IdeaCard(idea: idea)
                        .slideUpOnAppear(delay: Double(index) * 0.04)
                }
            }
        }
    }
}

struct IdeaCard: View {
    let idea: GeneratedPartyIdea
    @State private var isExpanded: Bool = true

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.yellow)
                        .frame(width: 36, height: 36)
                        .background(.yellow.opacity(0.14), in: .rect(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(idea.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(idea.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(idea.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.blue)
                                    .frame(width: 20, height: 20)
                                    .background(.blue.opacity(0.14), in: .circle)
                                Text(step)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        if !idea.tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(idea.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.08), in: .capsule)
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}
