import SwiftUI

// MARK: - Coin Flip Tool

struct CoinFlipToolView: View {
    @State private var coinCount: Int = 1
    @State private var coinStates: [CoinState] = [CoinState()]
    @State private var isFlipping: Bool = false
    @State private var hasResult: Bool = false
    @State private var flipTrigger: Int = 0
    @State private var headsCount: Int = 0
    @State private var tailsCount: Int = 0

    struct CoinState: Identifiable {
        let id = UUID()
        var rotation: Double = 0
        var resultIsHeads: Bool = true
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 18) {
                statsRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                countSelector
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                resultLabel

                coinsRow

                Spacer(minLength: 0)

                flipButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: flipTrigger)
    }

    private var countSelector: some View {
        HStack(spacing: 8) {
            ForEach(1...2, id: \.self) { n in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        coinCount = n
                        syncCoinStates()
                        hasResult = false
                    }
                    SoundManager.shared.playButtonTap()
                } label: {
                    Text("\(n) \(n == 1 ? "Coin" : "Coins")")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(coinCount == n ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(coinCount == n ? Color.white : Color.white.opacity(0.08), in: .capsule)
                        .overlay { Capsule().strokeBorder(.white.opacity(0.1)) }
                }
                .buttonStyle(.plain)
                .disabled(isFlipping)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(title: "HEADS", value: headsCount, color: .yellow)
            statPill(title: "TAILS", value: tailsCount, color: .orange)
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    headsCount = 0
                    tailsCount = 0
                }
                SoundManager.shared.playButtonTap()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(headsCount == 0 && tailsCount == 0)
        }
    }

    private func statPill(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.6))
            Text("\(value)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06), in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.08)) }
    }

    private var resultLabel: some View {
        VStack(spacing: 6) {
            Text(hasResult ? "RESULT" : "READY")
                .font(.system(size: 12, weight: .heavy))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.55))
            Text(resultText)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(hasResult ? Color.yellow : Color.white.opacity(0.85))
                .shadow(color: .yellow.opacity(hasResult ? 0.5 : 0), radius: 16, y: 4)
                .contentTransition(.opacity)
                .multilineTextAlignment(.center)
        }
        .opacity(isFlipping ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: isFlipping)
    }

    private var resultText: String {
        if isFlipping { return "Flipping…" }
        guard hasResult else { return "Tap to flip" }
        if coinCount == 1 {
            return coinStates[0].resultIsHeads ? "HEADS" : "TAILS"
        } else {
            let labels = coinStates.map { $0.resultIsHeads ? "H" : "T" }
            return labels.joined(separator: "  •  ")
        }
    }

    private var coinsRow: some View {
        HStack(spacing: 20) {
            ForEach(Array(coinStates.enumerated()), id: \.element.id) { index, state in
                coinView(for: state)
                    .frame(width: coinCount == 1 ? 240 : 160, height: coinCount == 1 ? 240 : 160)
                    .onTapGesture {
                        if !isFlipping { flip() }
                    }
                    .id(index)
            }
        }
    }

    private func coinView(for state: CoinState) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.yellow.opacity(0.35), .orange.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 160
                    )
                )
                .blur(radius: 18)

            coinFace(isHeads: true)
                .opacity(headsOpacity(rotation: state.rotation))
            coinFace(isHeads: false)
                .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                .opacity(tailsOpacity(rotation: state.rotation))
        }
        .rotation3DEffect(
            .degrees(state.rotation),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.6
        )
        .scaleEffect(isFlipping ? 1.05 : 1.0)
        .blur(radius: isFlipping ? 4.5 : 0)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
    }

    private func headsOpacity(rotation: Double) -> Double {
        let r = (rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return (r < 90 || r > 270) ? 1 : 0
    }

    private func tailsOpacity(rotation: Double) -> Double {
        headsOpacity(rotation: rotation) == 1 ? 0 : 1
    }

    private func coinFace(isHeads: Bool) -> some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let gold = Color(red: 0.92, green: 0.70, blue: 0.15)
            let goldLight = Color(red: 1.0, green: 0.95, blue: 0.65)
            let goldDeep = Color(red: 0.45, green: 0.27, blue: 0.02)
            let goldMid = Color(red: 0.82, green: 0.56, blue: 0.08)

            let faceURL = isHeads
                ? "https://r2-pub.rork.com/generated-images/5ed19d54-708a-4c39-bd70-944d23883fc4.png"
                : "https://r2-pub.rork.com/generated-images/592738ac-9267-4db2-99e0-714050751883.png"
            AsyncImage(url: URL(string: faceURL)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                } else {
                    fallbackCoinFace(isHeads: isHeads, size: size, gold: gold, goldLight: goldLight, goldDeep: goldDeep, goldMid: goldMid)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func fallbackCoinFace(isHeads: Bool, size: CGFloat, gold: Color, goldLight: Color, goldDeep: Color, goldMid: Color) -> some View {
        ZStack {
                // Outer rim with metallic sheen
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                goldDeep, goldMid, goldLight, gold,
                                goldLight, goldMid, goldDeep, goldMid,
                                goldLight, gold, goldMid, goldDeep
                            ],
                            center: .center
                        )
                    )

                // Inner recessed face
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.88, blue: 0.45),
                                Color(red: 0.95, green: 0.72, blue: 0.18),
                                Color(red: 0.72, green: 0.48, blue: 0.06)
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 2,
                            endRadius: size * 0.55
                        )
                    )
                    .padding(size * 0.08)
                    .shadow(color: goldDeep.opacity(0.7), radius: 1, x: 0, y: 1)

                // Reeded (milled) edge pattern
                reededEdge(size: size)
                    .opacity(0.55)

                // Inner ring groove
                Circle()
                    .strokeBorder(goldDeep.opacity(0.55), lineWidth: max(1, size * 0.006))
                    .padding(size * 0.095)
                Circle()
                    .strokeBorder(goldLight.opacity(0.7), lineWidth: max(0.5, size * 0.004))
                    .padding(size * 0.11)

                // Decorative dotted ring
                dottedRing(size: size)
                    .padding(size * 0.16)

                // Stars decoration around the emblem
                if isHeads {
                    ForEach(0..<6, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: size * 0.05, weight: .black))
                            .foregroundStyle(goldDeep.opacity(0.55))
                            .offset(y: -size * 0.33)
                            .rotationEffect(.degrees(Double(i) * 60))
                    }
                }

                // Center emblem
                if isHeads {
                    ZStack {
                        // Engraved dark shadow behind
                        Text("8")
                            .font(.system(size: size * 0.55, weight: .black, design: .rounded))
                            .foregroundStyle(goldDeep.opacity(0.55))
                            .offset(x: size * 0.008, y: size * 0.012)
                            .blur(radius: 0.5)
                        // Main gold text with embossed look
                        Text("8")
                            .font(.system(size: size * 0.55, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.97, blue: 0.75),
                                        Color(red: 1.0, green: 0.85, blue: 0.35),
                                        Color(red: 0.85, green: 0.55, blue: 0.08),
                                        Color(red: 1.0, green: 0.9, blue: 0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: goldLight.opacity(0.9), radius: 0.5, x: -0.5, y: -0.5)
                            .shadow(color: goldDeep.opacity(0.6), radius: 0.5, x: 0.5, y: 0.5)
                    }
                } else {
                    ZStack {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: size * 0.46, weight: .black))
                            .foregroundStyle(goldDeep.opacity(0.5))
                            .offset(x: size * 0.008, y: size * 0.012)
                            .blur(radius: 0.5)
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: size * 0.46, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.97, blue: 0.75),
                                        Color(red: 1.0, green: 0.82, blue: 0.3),
                                        Color(red: 0.78, green: 0.5, blue: 0.06)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: goldLight.opacity(0.8), radius: 0.5, x: -0.5, y: -0.5)
                    }
                }

                // Glossy highlight sweep
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), .clear, .clear, Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)

                // Soft top specular highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.5), .clear],
                            center: UnitPoint(x: 0.32, y: 0.22),
                            startRadius: 0,
                            endRadius: size * 0.35
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)

                // Edge darkening for 3D depth
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [goldDeep.opacity(0.0), goldDeep.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: size * 0.025
                    )
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
    }

    private func reededEdge(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<72, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.black.opacity(0.25)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.012, height: size * 0.055)
                    .offset(y: -size * 0.47)
                    .rotationEffect(.degrees(Double(i) * 5))
            }
        }
    }

    private func dottedRing(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<24, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.45, green: 0.27, blue: 0.02).opacity(0.5))
                    .frame(width: size * 0.012, height: size * 0.012)
                    .offset(y: -size * 0.32)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
        }
    }

    private var flipButton: some View {
        Button(action: flip) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .heavy))
                Text(isFlipping ? "Flipping..." : (coinCount == 1 ? "Flip Coin" : "Flip Coins"))
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.95, green: 0.6, blue: 0.15)], startPoint: .leading, endPoint: .trailing),
                in: .capsule
            )
            .shadow(color: .yellow.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isFlipping)
        .opacity(isFlipping ? 0.6 : 1)
    }

    private func syncCoinStates() {
        while coinStates.count < coinCount { coinStates.append(CoinState()) }
        if coinStates.count > coinCount { coinStates = Array(coinStates.prefix(coinCount)) }
    }

    private func flip() {
        guard !isFlipping else { return }
        isFlipping = true
        hasResult = false
        SoundManager.shared.playDiceRoll()
        flipTrigger &+= 1

        let outcomes: [Bool] = (0..<coinCount).map { _ in Bool.random() }

        // Long spin phase — outcome not visible until near the very end
        let spinDuration: Double = 2.6
        let settleDuration: Double = 0.5

        for i in 0..<coinCount {
            let current = coinStates[i].rotation
            let currentMod = (current.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let base = current - currentMod
            let extraSpins = Int.random(in: 14...18) + i
            // Spin to a neutral mid-point so final outcome isn't revealed early
            let midTarget = base + Double(extraSpins) * 360.0 + 90.0

            withAnimation(.timingCurve(0.25, 0.1, 0.35, 0.7, duration: spinDuration)) {
                coinStates[i].rotation = midTarget
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(spinDuration))
            await MainActor.run {
                for i in 0..<coinCount {
                    let current = coinStates[i].rotation
                    let endOffset: Double = outcomes[i] ? 360.0 : 180.0
                    let currentMod = (current.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                    let base = current - currentMod
                    let target = base + endOffset
                    withAnimation(.timingCurve(0.2, 0.9, 0.3, 1.0, duration: settleDuration)) {
                        coinStates[i].rotation = target
                        coinStates[i].resultIsHeads = outcomes[i]
                    }
                }
            }
            try? await Task.sleep(for: .seconds(settleDuration))
            await MainActor.run {
                hasResult = true
                isFlipping = false
                for outcome in outcomes {
                    if outcome { headsCount += 1 } else { tailsCount += 1 }
                }
                flipTrigger &+= 1
                FeedbackService.shared.playSuccess()
            }
        }
    }
}

// MARK: - Team Splitter Tool

struct TeamSplitterToolView: View {
    @State private var names: [String] = []
    @State private var draft: String = ""
    @State private var teamCount: Int = 2
    @State private var teams: [[String]] = []
    @State private var isShuffling: Bool = false
    @State private var shuffleTrigger: Int = 0
    @State private var showDuplicateAlert: Bool = false
    @State private var duplicateName: String = ""
    @FocusState private var isInputFocused: Bool

    private let teamColors: [Color] = [.orange, .cyan, .pink, .green, .purple, .yellow]
    private let teamIcons: [String] = ["flame.fill", "bolt.fill", "heart.fill", "leaf.fill", "star.fill", "sparkles"]

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 14) {
                inputRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !names.isEmpty {
                    namesChips
                        .padding(.horizontal, 16)
                }

                teamCountSelector
                    .padding(.horizontal, 16)

                ScrollView {
                    if teams.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        teamGrid
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                }
                .scrollDismissesKeyboard(.immediately)

                splitButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: shuffleTrigger)
        .onTapGesture { isInputFocused = false }
        .alert("Duplicate name", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("“\(duplicateName)” is already in the list. Please use a different name.")
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Add a name", text: $draft)
                .focused($isInputFocused)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08))
                }
                .submitLabel(.done)
                .onSubmit(addName)

            Button(action: addName) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.green, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var namesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.caption.weight(.bold))
                        Button {
                            names.remove(at: i)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .black))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: .capsule)
                }
            }
        }
    }

    private var teamCountSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TEAMS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(2...6, id: \.self) { n in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            teamCount = n
                        }
                        SoundManager.shared.playButtonTap()
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(teamCount == n ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(teamCount == n ? Color.white : Color.white.opacity(0.08), in: .capsule)
                            .overlay { Capsule().strokeBorder(.white.opacity(0.1)) }
                    }
                    .buttonStyle(.plain)
                    .disabled(isShuffling)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text("Add names then tap Split")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text("Players will be randomly distributed into teams.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var teamGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(teams.enumerated()), id: \.offset) { idx, members in
                teamCard(index: idx, members: members)
            }
        }
    }

    private func teamCard(index: Int, members: [String]) -> some View {
        let color = teamColors[index % teamColors.count]
        let icon = teamIcons[index % teamIcons.count]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Text("Team \(index + 1)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(members.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(members.enumerated()), id: \.offset) { _, name in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color.opacity(0.7))
                            .frame(width: 5, height: 5)
                        Text(name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                if members.isEmpty {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.3))
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var splitButton: some View {
        Button(action: split) {
            HStack(spacing: 10) {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .heavy))
                Text(teams.isEmpty ? "Split into Teams" : "Shuffle Again")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing),
                in: .capsule
            )
            .shadow(color: .green.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(names.count < teamCount || isShuffling)
        .opacity(names.count < teamCount ? 0.5 : 1)
    }

    private func addName() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if names.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            duplicateName = trimmed
            showDuplicateAlert = true
            FeedbackService.shared.playError()
            return
        }
        names.append(trimmed)
        draft = ""
        SoundManager.shared.playButtonTap()
    }

    private func split() {
        guard names.count >= teamCount else { return }
        isShuffling = true
        shuffleTrigger &+= 1
        SoundManager.shared.playDiceRoll()

        let shuffled = names.shuffled()
        var buckets: [[String]] = Array(repeating: [], count: teamCount)
        for (i, name) in shuffled.enumerated() {
            buckets[i % teamCount].append(name)
        }

        withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
            teams = buckets
        }

        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                isShuffling = false
                FeedbackService.shared.playSuccess()
            }
        }
    }
}
