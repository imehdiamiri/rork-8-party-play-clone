import SwiftUI

// MARK: - Tool Model

enum PartyTool: String, CaseIterable, Identifiable {
    case dice
    case bottle
    case hourglass
    case coin
    case teams

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dice: return "Dice"
        case .bottle: return "Bottle"
        case .hourglass: return "Hourglass"
        case .coin: return "Coin Flip"
        case .teams: return "Team Splitter"
        }
    }

    var subtitle: String {
        switch self {
        case .dice: return "Roll 1–4 dice"
        case .bottle: return "Spin to pick"
        case .hourglass: return "Set a timer"
        case .coin: return "Heads or tails"
        case .teams: return "Split into teams"
        }
    }

    var icon: String {
        switch self {
        case .dice: return "die.face.5.fill"
        case .bottle: return "waterbottle.fill"
        case .hourglass: return "hourglass"
        case .coin: return "circle.circle.fill"
        case .teams: return "person.2.badge.gearshape.fill"
        }
    }

    var isEmojiIcon: Bool { false }

    var tint: Color {
        switch self {
        case .dice: return .orange
        case .bottle: return .pink
        case .hourglass: return .cyan
        case .coin: return .yellow
        case .teams: return .green
        }
    }
}

// MARK: - Tools Row

struct PartyToolsSection: View {
    let showsHeader: Bool
    @State private var activeTool: PartyTool?

    init(showsHeader: Bool = true) {
        self.showsHeader = showsHeader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption2.weight(.bold))
                    Text("TOOLS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.4)
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.55))
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(PartyTool.allCases) { tool in
                    Button {
                        SoundManager.shared.playNavigation()
                        activeTool = tool
                    } label: {
                        ToolCard(tool: tool)
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
        }
        .sheet(item: $activeTool) { tool in
            NavigationStack {
                Group {
                    switch tool {
                    case .dice: DiceToolView()
                    case .bottle: BottleToolView()
                    case .hourglass: HourglassToolView()
                    case .coin: CoinFlipToolView()
                    case .teams: TeamSplitterToolView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { activeTool = nil }
                    }
                }
                .navigationTitle(tool.title)
                .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)
        }
    }
}

private struct ToolCard: View {
    let tool: PartyTool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tool.tint.opacity(0.35), tool.tint.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Circle().strokeBorder(tool.tint.opacity(0.35), lineWidth: 1)
                Image(systemName: tool.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .shadow(color: tool.tint.opacity(0.35), radius: 10, y: 4)

            Text(tool.title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
            Text(tool.subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.07))
        }
    }
}

// MARK: - Beer Bottle Icon

struct BeerBottleIcon: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                BeerBottleShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0.28, blue: 0.08), Color(red: 0.30, green: 0.14, blue: 0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                BeerBottleShape()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                // highlight
                RoundedRectangle(cornerRadius: w * 0.1)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: w * 0.08, height: h * 0.35)
                    .offset(x: -w * 0.22, y: h * 0.08)
                // label
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.yellow.opacity(0.9))
                    .frame(width: w * 0.55, height: h * 0.16)
                    .overlay(
                        Text("8")
                            .font(.system(size: h * 0.11, weight: .heavy))
                            .foregroundStyle(Color(red: 0.30, green: 0.14, blue: 0.04))
                    )
                    .offset(y: h * 0.15)
                // cap
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.85, green: 0.75, blue: 0.25))
                    .frame(width: w * 0.22, height: h * 0.06)
                    .offset(y: -h * 0.46)
            }
        }
    }
}

private struct BeerBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let neckW = w * 0.34
        let neckTop = h * 0.00
        let neckBottom = h * 0.30
        let shoulderBottom = h * 0.42
        let bodyBottom = h * 0.98
        let cornerR = w * 0.18

        // start top-left of neck
        p.move(to: CGPoint(x: (w - neckW) / 2, y: neckTop))
        p.addLine(to: CGPoint(x: (w - neckW) / 2, y: neckBottom))
        // shoulder curve left
        p.addQuadCurve(
            to: CGPoint(x: 0, y: shoulderBottom),
            control: CGPoint(x: (w - neckW) / 2 - w * 0.05, y: shoulderBottom - h * 0.02)
        )
        // body left
        p.addLine(to: CGPoint(x: 0, y: bodyBottom - cornerR))
        p.addQuadCurve(
            to: CGPoint(x: cornerR, y: bodyBottom),
            control: CGPoint(x: 0, y: bodyBottom)
        )
        p.addLine(to: CGPoint(x: w - cornerR, y: bodyBottom))
        p.addQuadCurve(
            to: CGPoint(x: w, y: bodyBottom - cornerR),
            control: CGPoint(x: w, y: bodyBottom)
        )
        p.addLine(to: CGPoint(x: w, y: shoulderBottom))
        p.addQuadCurve(
            to: CGPoint(x: (w + neckW) / 2, y: neckBottom),
            control: CGPoint(x: (w + neckW) / 2 + w * 0.05, y: shoulderBottom - h * 0.02)
        )
        p.addLine(to: CGPoint(x: (w + neckW) / 2, y: neckTop))
        p.closeSubpath()
        return p
    }
}

// MARK: - Dice Tool (Simple 2D)

struct DiceToolView: View {
    @State private var count: Int = 1
    @State private var values: [Int] = [1]
    @State private var isRolling: Bool = false
    @State private var rollTrigger: Int = 0
    @State private var shake: CGFloat = 0

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 20) {
                countSelector
                    .padding(.top, 12)

                Spacer(minLength: 0)

                diceArea

                Spacer(minLength: 0)

                totalLabel

                rollButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: rollTrigger)
        .onAppear { syncValues() }
    }

    private var totalLabel: some View {
        VStack(spacing: 6) {
            Text(count == 1 ? "VALUE" : "TOTAL")
                .font(.system(size: 13, weight: .heavy))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.55))
            Text("\(values.reduce(0, +))")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(Color.blue)
                .monospacedDigit()
                .contentTransition(.numericText())
                .shadow(color: .blue.opacity(0.5), radius: 20, y: 4)
        }
        .opacity(isRolling ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.2), value: isRolling)
    }

    private var countSelector: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { n in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        count = n
                        syncValues()
                    }
                    SoundManager.shared.playButtonTap()
                } label: {
                    Text("\(n) \(n == 1 ? "Die" : "Dice")")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(count == n ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(count == n ? Color.white : Color.white.opacity(0.08), in: .capsule)
                        .overlay { Capsule().strokeBorder(.white.opacity(0.1)) }
                }
                .buttonStyle(.plain)
                .disabled(isRolling)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var diceArea: some View {
        let columns = count > 2 ? 2 : count
        let side: CGFloat = count == 1 ? 150 : (count == 2 ? 120 : 100)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 20) {
            ForEach(0..<count, id: \.self) { i in
                Die2DView(value: values.indices.contains(i) ? values[i] : 1)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity)
                    .rotationEffect(.degrees(isRolling ? Double(shake * (i.isMultiple(of: 2) ? 1 : -1)) : 0))
            }
        }
        .padding(.horizontal, 28)
        .scaleEffect(isRolling ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isRolling)
    }

    private var rollButton: some View {
        Button(action: roll) {
            HStack(spacing: 10) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 16, weight: .heavy))
                Text(isRolling ? "Rolling..." : "Roll")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                in: .capsule
            )
            .shadow(color: .blue.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isRolling)
    }

    private func syncValues() {
        while values.count < count { values.append(Int.random(in: 1...6)) }
        if values.count > count { values = Array(values.prefix(count)) }
    }

    private func roll() {
        guard !isRolling else { return }
        isRolling = true
        SoundManager.shared.playDiceRoll()
        rollTrigger &+= 1

        Task {
            let ticks = 10
            for t in 0..<ticks {
                try? await Task.sleep(for: .milliseconds(70))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.07)) {
                        shake = CGFloat.random(in: -18...18)
                    }
                    for i in 0..<count {
                        if values.indices.contains(i) {
                            values[i] = Int.random(in: 1...6)
                        }
                    }
                }
            }
            await MainActor.run {
                let final = (0..<count).map { _ in Int.random(in: 1...6) }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    for i in 0..<count {
                        values[i] = final[i]
                    }
                    shake = 0
                }
                rollTrigger &+= 1
                isRolling = false
                FeedbackService.shared.playSuccess()
            }
        }
    }
}

private struct Die2DView: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.18)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 1.0), Color(white: 0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: side * 0.18)
                    .strokeBorder(.black.opacity(0.12), lineWidth: 1)
                RoundedRectangle(cornerRadius: side * 0.18)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                Pips2DView(value: value)
                    .padding(side * 0.16)
            }
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct Pips2DView: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let dot = side * 0.26
            ZStack {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: dot, height: dot)
                        .position(x: p.x * side, y: p.y * side)
                }
            }
        }
    }

    private var positions: [CGPoint] {
        let tl = CGPoint(x: 0.22, y: 0.22)
        let tr = CGPoint(x: 0.78, y: 0.22)
        let ml = CGPoint(x: 0.22, y: 0.5)
        let mc = CGPoint(x: 0.5, y: 0.5)
        let mr = CGPoint(x: 0.78, y: 0.5)
        let bl = CGPoint(x: 0.22, y: 0.78)
        let br = CGPoint(x: 0.78, y: 0.78)
        switch value {
        case 1: return [mc]
        case 2: return [tl, br]
        case 3: return [tl, mc, br]
        case 4: return [tl, tr, bl, br]
        case 5: return [tl, tr, mc, bl, br]
        case 6: return [tl, tr, ml, mr, bl, br]
        default: return [mc]
        }
    }
}

// MARK: - Bottle Tool

struct BottleToolView: View {
    @State private var names: [String] = []
    @State private var draft: String = ""
    @State private var bottleAngle: Double = 0
    @State private var isSpinning: Bool = false
    @State private var selectedIndex: Int? = nil
    @FocusState private var isInputFocused: Bool

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

                Spacer(minLength: 0)

                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height)
                    let radius = size / 2 - 44
                    ZStack {
                        centerGlow(size: size)
                        nameRing(radius: radius)
                        bottleView(size: size)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 4)

                Spacer(minLength: 0)

                if names.isEmpty {
                    Text("Add names to spin")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 6)
                }

                spinButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onTapGesture { isInputFocused = false }
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
                    .background(.pink, in: .rect(cornerRadius: 12))
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
                            if selectedIndex == i { selectedIndex = nil }
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

    private func addName() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        names.append(trimmed)
        draft = ""
        SoundManager.shared.playButtonTap()
    }

    private func centerGlow(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.pink.opacity(0.35), .purple.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: size * 0.42
                )
            )
            .blur(radius: 14)
    }

    private func nameRing(radius: CGFloat) -> some View {
        ZStack {
            if !names.isEmpty {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    let angle = (360.0 / Double(names.count)) * Double(index) - 90
                    let radians = angle * .pi / 180
                    let x = cos(radians) * radius
                    let y = sin(radians) * radius
                    Group {
                        if selectedIndex == index {
                            CurrentTurnPill(playerName: name, accent: .green)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text(name)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                                .frame(maxWidth: 110)
                        }
                    }
                    .offset(x: x, y: y)
                    .animation(.spring(duration: 0.35, bounce: 0.4), value: selectedIndex)
                }
            }
        }
    }

    private func bottleView(size: CGFloat) -> some View {
        AsyncImage(url: URL(string: "https://r2-pub.rork.com/generated-images/fd6d9d25-4377-42da-abad-0212755191ca.png")) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                BeerBottleIcon()
            }
        }
        .frame(width: size * 0.3, height: size * 0.72)
        .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
        .rotationEffect(.degrees(bottleAngle))
    }

    private var spinButton: some View {
        Button(action: spin) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .heavy))
                Text(isSpinning ? "Spinning..." : "Spin")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                in: .capsule
            )
            .shadow(color: .pink.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isSpinning)
        .opacity(isSpinning ? 0.6 : 1.0)
    }

    private func spin() {
        guard !isSpinning else { return }
        isSpinning = true
        selectedIndex = nil
        FeedbackService.shared.playRoundStart()

        let hasNames = !names.isEmpty
        let target: Int = hasNames ? Int.random(in: 0..<names.count) : 0
        let perSlice: Double = hasNames ? 360.0 / Double(names.count) : 0
        let baseRotations = Double(Int.random(in: 10...14)) * 360
        let targetAngle = perSlice * Double(target)
        let jitter = hasNames ? Double.random(in: -perSlice * 0.25...perSlice * 0.25) : Double.random(in: 0...360)
        let normalized = bottleAngle.truncatingRemainder(dividingBy: 360)
        let nextAngle = bottleAngle - normalized + baseRotations + targetAngle + jitter

        withAnimation(.timingCurve(0.15, 0.45, 0.2, 1.0, duration: 8.0)) {
            bottleAngle = nextAngle
        }

        Task {
            try? await Task.sleep(for: .seconds(8.05))
            await MainActor.run {
                if hasNames {
                    withAnimation(.spring(duration: 0.4)) {
                        selectedIndex = target
                    }
                }
                isSpinning = false
                FeedbackService.shared.playSuccess()
            }
        }
    }
}

// MARK: - Hourglass Tool

struct HourglassToolView: View {
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var remaining: Int = 60
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var task: Task<Void, Never>?
    @State private var isAlarming: Bool = false

    private static let presets: [(label: String, seconds: Int)] = [
        ("30s", 30),
        ("1min", 60),
        ("2min", 120),
        ("5min", 300),
        ("10min", 600)
    ]

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 16) {
                if !isRunning && !isPaused && !isAlarming {
                    pickers
                        .padding(.top, 8)
                    presetsRow
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    Text(timeString)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(isAlarming ? Color.red : Color.blue)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    hourglassImage
                        .frame(width: 160, height: 220)
                }
                .scaleEffect(isAlarming ? 1.05 : 1.0)
                .animation(.spring(duration: 0.4).repeatForever(autoreverses: true), value: isAlarming)

                Spacer(minLength: 0)

                controls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
        .onDisappear {
            task?.cancel()
        }
    }

    private var hourglassImage: some View {
        AsyncImage(url: URL(string: "https://r2-pub.rork.com/generated-images/cc809ffb-12b4-424b-a9f1-ea496b5f37d2.png")) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "hourglass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.cyan)
            }
        }
        .shadow(color: .cyan.opacity(0.25), radius: 16, y: 4)
    }

    private var presetsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.label) { preset in
                    Button {
                        SoundManager.shared.playButtonTap()
                        withAnimation(.spring(duration: 0.25)) {
                            minutes = preset.seconds / 60
                            seconds = preset.seconds % 60
                        }
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(isPresetActive(preset.seconds) ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isPresetActive(preset.seconds) ? Color.white : Color.white.opacity(0.08),
                                in: .capsule
                            )
                            .overlay { Capsule().strokeBorder(.white.opacity(0.1)) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isPresetActive(_ secs: Int) -> Bool {
        (minutes * 60 + seconds) == secs
    }

    private var totalSet: Int {
        max(1, minutes * 60 + seconds)
    }

    private var progress: Double {
        guard totalSet > 0 else { return 0 }
        return Double(remaining) / Double(totalSet)
    }

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var pickers: some View {
        HStack(spacing: 14) {
            wheel(title: "MIN", value: $minutes, range: 0...59)
            Text(":")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            wheel(title: "SEC", value: $seconds, range: 0...59)
        }
        .onChange(of: minutes) { _, _ in if !isRunning && !isPaused { remaining = totalSet } }
        .onChange(of: seconds) { _, _ in if !isRunning && !isPaused { remaining = totalSet } }
    }

    private func wheel(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            Picker(title, selection: value) {
                ForEach(range, id: \.self) { v in
                    Text(String(format: "%02d", v))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 130)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if isAlarming {
                Button(action: stopAlarm) {
                    controlLabel("Stop", icon: "stop.fill", colors: [.red, .orange])
                }
                .buttonStyle(.plain)
            } else if isRunning {
                Button(action: pause) {
                    controlLabel("Pause", icon: "pause.fill", colors: [.orange, .yellow])
                }
                .buttonStyle(.plain)
                Button(action: cancel) {
                    controlLabel("Cancel", icon: "xmark", colors: [.gray, .gray.opacity(0.7)])
                }
                .buttonStyle(.plain)
            } else if isPaused {
                Button(action: resume) {
                    controlLabel("Resume", icon: "play.fill", colors: [.cyan, .blue])
                }
                .buttonStyle(.plain)
                Button(action: cancel) {
                    controlLabel("Cancel", icon: "xmark", colors: [.gray, .gray.opacity(0.7)])
                }
                .buttonStyle(.plain)
            } else {
                Button(action: start) {
                    controlLabel("Start", icon: "play.fill", colors: [.cyan, .blue])
                }
                .buttonStyle(.plain)
                .disabled(totalSet == 0)
            }
        }
    }

    private func controlLabel(_ title: String, icon: String, colors: [Color]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .heavy))
            Text(title)
                .font(.system(size: 16, weight: .heavy))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
            in: .capsule
        )
        .shadow(color: colors.first?.opacity(0.4) ?? .clear, radius: 14, y: 6)
    }

    private func start() {
        remaining = totalSet
        isRunning = true
        isPaused = false
        FeedbackService.shared.playTimerStart()
        runTimer()
    }

    private func pause() {
        isRunning = false
        isPaused = true
        task?.cancel()
        FeedbackService.shared.playClick()
    }

    private func resume() {
        isRunning = true
        isPaused = false
        FeedbackService.shared.playClick()
        runTimer()
    }

    private func runTimer() {
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                await MainActor.run {
                    guard isRunning else { return }
                    if remaining > 0 {
                        remaining -= 1
                        if remaining <= 3 && remaining > 0 {
                            FeedbackService.shared.playCountdownTick()
                        }
                    }
                    if remaining == 0 {
                        triggerAlarm()
                    }
                }
                if remaining == 0 { break }
            }
        }
    }

    private func triggerAlarm() {
        isRunning = false
        isAlarming = true
        FeedbackService.shared.playGameEnd()
        task?.cancel()
        task = Task {
            for _ in 0..<8 {
                if Task.isCancelled { break }
                await MainActor.run {
                    FeedbackService.shared.playWarning()
                    SoundManager.shared.playTimerUrgent()
                }
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    private func cancel() {
        isRunning = false
        isPaused = false
        task?.cancel()
        remaining = totalSet
        FeedbackService.shared.playTimerStop()
    }

    private func stopAlarm() {
        isAlarming = false
        task?.cancel()
        remaining = totalSet
        FeedbackService.shared.playClick()
    }
}

// MARK: - Realistic Hourglass View

private struct RealisticHourglassView: View {
    let progress: Double // 1.0 = just started (full top), 0.0 = done (empty top)
    let isRunning: Bool

    private static let stageURLs: [String] = [
        "https://r2-pub.rork.com/generated-images/78c5fcee-8aa7-4dfd-b7ea-f172199c5379.png", // 100% top
        "https://r2-pub.rork.com/generated-images/66eedb95-d55e-4e8f-a692-33e3cf5c79ea.png", // 75%
        "https://r2-pub.rork.com/generated-images/cc809ffb-12b4-424b-a9f1-ea496b5f37d2.png", // 50%
        "https://r2-pub.rork.com/generated-images/11d8d6aa-472b-493a-8d47-41817ecc11a6.png", // 25%
        "https://r2-pub.rork.com/generated-images/256779c5-8b00-4986-9571-a0bb26478349.png"  // 0% top (full bottom)
    ]

    @State private var grainPhase: CGFloat = 0
    @State private var jitter: CGFloat = 0

    private var stageIndex: Int {
        // progress 1.0 -> 0 (full top), 0.0 -> 4 (empty top)
        let p = max(0.0, min(1.0, progress))
        let idx = Int(round((1.0 - p) * 4.0))
        return max(0, min(4, idx))
    }

    private var nextStageIndex: Int {
        min(4, stageIndex + 1)
    }

    private var blend: Double {
        let p = max(0.0, min(1.0, progress))
        let continuous = (1.0 - p) * 4.0
        return continuous - Double(Int(continuous.rounded(.down)))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Preload all stages, fade between current and next for smooth transitions
                ForEach(0..<Self.stageURLs.count, id: \.self) { i in
                    AsyncImage(url: URL(string: Self.stageURLs[i])) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: w, height: h)
                    .opacity(opacity(for: i))
                    .animation(.easeInOut(duration: 0.4), value: stageIndex)
                    .animation(.easeInOut(duration: 0.4), value: blend)
                }
                .shadow(color: .cyan.opacity(0.25), radius: 16, y: 4)

                // Subtle grain jitter suggesting flow
                if isRunning && progress > 0.001 && progress < 0.999 {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(Color(red: 1.0, green: 0.72, blue: 0.2))
                            .frame(width: 2.5, height: 2.5)
                            .offset(
                                x: CGFloat.random(in: -1.5...1.5) + jitter * 0.5,
                                y: (grainPhase + CGFloat(i) * 0.18).truncatingRemainder(dividingBy: 1) * h * 0.3 - h * 0.04
                            )
                            .position(x: w / 2, y: h / 2)
                            .opacity(0.85)
                            .blur(radius: 0.3)
                    }
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                    grainPhase = 1
                }
                withAnimation(.easeInOut(duration: 0.08).repeatForever(autoreverses: true)) {
                    jitter = 1
                }
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        if index == stageIndex {
            return 1.0 - blend * 0.9
        } else if index == nextStageIndex && nextStageIndex != stageIndex {
            return blend
        }
        return 0
    }
}

// MARK: - Hourglass Shape

private struct HourglassShape: View {
    let progress: Double // 1.0 = full (just started), 0.0 = done
    let isRunning: Bool

    @State private var sandPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let capH: CGFloat = 8
            let bulbH = (h - capH * 2) / 2

            ZStack {
                // outer hourglass frame
                HourglassGlass()
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.9), .blue.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 4, lineJoin: .round)
                    )

                // glass fill
                HourglassGlass()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.04), .white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // top sand (shrinks as progress goes to 0)
                TopSandShape(progress: progress)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.95, green: 0.6, blue: 0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(HourglassGlass())

                // bottom sand (grows as progress goes to 0)
                BottomSandShape(progress: progress)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.55, blue: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(HourglassGlass())

                // falling sand stream
                if isRunning && progress > 0.001 && progress < 0.999 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.95, green: 0.6, blue: 0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3, height: bulbH * 0.9)
                        .position(x: w / 2, y: h / 2)
                        .opacity(0.9)
                        .blur(radius: 0.5)

                    // animated grains
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Color(red: 1.0, green: 0.75, blue: 0.2))
                            .frame(width: 3, height: 3)
                            .offset(y: (sandPhase + CGFloat(i) * 0.25).truncatingRemainder(dividingBy: 1) * bulbH * 0.9 - bulbH * 0.45)
                            .position(x: w / 2, y: h / 2)
                    }
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                    sandPhase = 1
                }
            }
        }
    }
}

private struct HourglassGlass: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let capH: CGFloat = 8
        let inset: CGFloat = 6
        // top cap
        p.move(to: CGPoint(x: inset, y: 0))
        p.addLine(to: CGPoint(x: rect.width - inset, y: 0))
        p.addLine(to: CGPoint(x: rect.width - inset, y: capH))
        // right side down to neck
        p.addCurve(
            to: CGPoint(x: rect.width / 2 + 6, y: rect.height / 2),
            control1: CGPoint(x: rect.width - inset, y: rect.height * 0.3),
            control2: CGPoint(x: rect.width / 2 + 10, y: rect.height * 0.45)
        )
        // neck to bottom right
        p.addCurve(
            to: CGPoint(x: rect.width - inset, y: rect.height - capH),
            control1: CGPoint(x: rect.width / 2 + 10, y: rect.height * 0.55),
            control2: CGPoint(x: rect.width - inset, y: rect.height * 0.7)
        )
        p.addLine(to: CGPoint(x: rect.width - inset, y: rect.height))
        p.addLine(to: CGPoint(x: inset, y: rect.height))
        p.addLine(to: CGPoint(x: inset, y: rect.height - capH))
        // left side up
        p.addCurve(
            to: CGPoint(x: rect.width / 2 - 6, y: rect.height / 2),
            control1: CGPoint(x: inset, y: rect.height * 0.7),
            control2: CGPoint(x: rect.width / 2 - 10, y: rect.height * 0.55)
        )
        p.addCurve(
            to: CGPoint(x: inset, y: capH),
            control1: CGPoint(x: rect.width / 2 - 10, y: rect.height * 0.45),
            control2: CGPoint(x: inset, y: rect.height * 0.3)
        )
        p.closeSubpath()
        return p
    }
}

private struct TopSandShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.height / 2
        // sand fills top half based on progress, dropping from top
        let fillY = rect.minY + (1 - progress) * midY
        p.move(to: CGPoint(x: rect.minX, y: fillY))
        p.addLine(to: CGPoint(x: rect.maxX, y: fillY))
        p.addLine(to: CGPoint(x: rect.maxX, y: midY))
        p.addLine(to: CGPoint(x: rect.minX, y: midY))
        p.closeSubpath()
        return p
    }
}

private struct BottomSandShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.height / 2
        let filled = (1 - progress) * midY
        let startY = rect.maxY - filled
        p.move(to: CGPoint(x: rect.minX, y: startY))
        p.addLine(to: CGPoint(x: rect.maxX, y: startY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
