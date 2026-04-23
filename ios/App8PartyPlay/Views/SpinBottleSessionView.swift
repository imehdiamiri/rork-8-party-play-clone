import SwiftUI

struct SpinBottleSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    enum Phase: Hashable {
        case idle
        case spinning
        case landed
        case choosing
        case prompt
        case done
    }

    @State private var phase: Phase = .idle
    @State private var bottleAngle: Double = 0
    @State private var selectedPlayerIndex: Int = 0
    @State private var choice: SpinBottleChoice = .truth
    @State private var promptText: String = ""
    @State private var rerollsLeft: Int = 2
    @State private var spinCount: Int = 0
    @State private var usedTruths: Set<String> = []
    @State private var usedDares: Set<String> = []

    private var difficulty: SpinBottleDifficulty {
        appModel.currentSpinBottleDifficulty
    }

    private var players: [PlayerProfile] { session.players }
    private var selectedPlayer: PlayerProfile? {
        players.indices.contains(selectedPlayerIndex) ? players[selectedPlayerIndex] : nil
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationTitle("Truth or Dare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .spinning, .landed, .choosing:
            circleScreen
        case .prompt:
            promptScreen
        case .done:
            EmptyView()
        }
    }

    // MARK: - Circle Screen

    private var circleScreen: some View {
        VStack(spacing: 16) {
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            if (phase == .landed || phase == .choosing), let player = selectedPlayer {
                selectedPlayerBanner(player: player)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let radius = size / 2 - 56
                ZStack {
                    centerGlow(size: size)
                    playerRing(radius: radius)
                    bottleView(size: size)
                    if phase == .landed, let player = selectedPlayer {
                        landedRing(radius: radius, player: player)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay(alignment: .topTrailing) {
                    restartButton
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if phase == .idle { spin() }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            actionArea
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(phaseTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(phaseSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.caption2.weight(.bold))
                Text(difficulty.title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.red.opacity(0.14), in: .capsule)
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .idle: return "Truth or Dare"
        case .spinning: return "Spinning..."
        case .landed: return selectedPlayer.map { "It's \($0.username)!" } ?? "Picked!"
        case .choosing: return selectedPlayer.map { "\($0.username)'s turn" } ?? "Truth or Dare?"
        default: return "Truth or Dare"
        }
    }

    private var phaseSubtitle: String {
        switch phase {
        case .idle: return "Tap Spin to start the round"
        case .spinning: return "Where will it land?"
        case .landed: return "Get ready to choose"
        case .choosing: return "Pick your fate"
        default: return ""
        }
    }

    private func selectedPlayerBanner(player: PlayerProfile) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GamePlayerColor.color(for: selectedPlayerIndex), GamePlayerColor.color(for: selectedPlayerIndex).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Text(initials(for: player.username))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected Player")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(1)
                Text(player.username)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GamePlayerColor.color(for: selectedPlayerIndex))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(GamePlayerColor.color(for: selectedPlayerIndex).opacity(0.45), lineWidth: 1.2)
        }
        .shadow(color: GamePlayerColor.color(for: selectedPlayerIndex).opacity(0.3), radius: 12, y: 4)
    }

    private func centerGlow(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.red.opacity(0.35), .pink.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: size * 0.42
                )
            )
            .blur(radius: 14)
    }

    private func playerRing(radius: CGFloat) -> some View {
        ZStack {
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                let angle = anglePerPlayer * Double(index) - 90
                let radians = angle * .pi / 180
                let x = cos(radians) * radius
                let y = sin(radians) * radius
                playerNode(player: player, index: index)
                    .offset(x: x, y: y)
            }
        }
    }

    private var anglePerPlayer: Double {
        guard !players.isEmpty else { return 0 }
        return 360.0 / Double(players.count)
    }

    private func playerNode(player: PlayerProfile, index: Int) -> some View {
        let isSelected = (phase == .landed || phase == .choosing) && index == selectedPlayerIndex
        return Group {
            if isSelected {
                CurrentTurnPill(playerName: player.username, accent: .green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(player.username)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(maxWidth: 110)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: isSelected)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2, let first = parts.first?.first, let second = parts.dropFirst().first?.first {
            return "\(first)\(second)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func bottleView(size: CGFloat) -> some View {
        AsyncImage(url: URL(string: "https://r2-pub.rork.com/generated-images/fd6d9d25-4377-42da-abad-0212755191ca.png")) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "waterbottle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: size * 0.22, height: size * 0.58)
        .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
        .rotationEffect(.degrees(bottleAngle))
    }

    private var restartButton: some View {
        Button {
            FeedbackService.shared.playClick()
            withAnimation(.spring(duration: 0.4)) {
                phase = .idle
                selectedPlayerIndex = 0
                bottleAngle = 0
            }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func landedRing(radius: CGFloat, player: PlayerProfile) -> some View {
        Circle()
            .strokeBorder(GamePlayerColor.color(for: selectedPlayerIndex).opacity(0.6), lineWidth: 2)
            .frame(width: radius * 2 + 12, height: radius * 2 + 12)
            .scaleEffect(1.0)
            .opacity(0.7)
    }

    @ViewBuilder
    private var actionArea: some View {
        switch phase {
        case .idle:
            Text("Tap the bottle to spin")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        case .spinning:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Spinning...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        case .landed:
            Button {
                FeedbackService.shared.playClick()
                withAnimation(.spring(duration: 0.35)) { phase = .choosing }
            } label: {
                actionLabel(title: "Continue", icon: "arrow.right", color: .blue)
            }
            .buttonStyle(.plain)
        case .choosing:
            choiceButtons
        default:
            EmptyView()
        }
    }

    private var choiceButtons: some View {
        HStack(spacing: 12) {
            choiceButton(.truth, color: .blue)
            choiceButton(.dare, color: .red)
        }
    }

    private func choiceButton(_ value: SpinBottleChoice, color: Color) -> some View {
        Button {
            choice = value
            generatePrompt(reset: true)
            FeedbackService.shared.playRoundStart()
            withAnimation(.spring(duration: 0.4)) { phase = .prompt }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: value.icon)
                    .font(.title2.weight(.bold))
                Text(value.title)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [color.opacity(0.85), color.opacity(0.55)], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.18))
            }
            .foregroundStyle(.white)
            .shadow(color: color.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
            Text(title)
                .font(.subheadline.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [color.opacity(0.9), color.opacity(0.6)], startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: 16)
        )
        .foregroundStyle(.white)
        .shadow(color: color.opacity(0.4), radius: 10, y: 4)
    }

    // MARK: - Prompt Screen

    private var promptScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: choice.icon)
                        .font(.subheadline.weight(.bold))
                    Text(choice.title.uppercased())
                        .font(.subheadline.weight(.heavy))
                        .tracking(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(promptAccent.opacity(0.85), in: .capsule)

                if let player = selectedPlayer {
                    Text(player.username)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 32)

            Spacer(minLength: 20)

            VStack(spacing: 22) {
                Text(promptText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 28)
                    .minimumScaleFactor(0.7)

                if rerollsLeft > 0 {
                    Button {
                        rerollsLeft -= 1
                        generatePrompt(reset: false)
                        FeedbackService.shared.playClick()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.bold))
                            Text("Reroll · \(rerollsLeft) left")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.14), in: .capsule)
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.18))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                LinearGradient(
                    colors: [promptAccent.opacity(0.42), promptAccent.opacity(0.18), .black.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 28)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(promptAccent.opacity(0.45), lineWidth: 1.5)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 20)

            Button {
                FeedbackService.shared.playSuccess()
                completeRound()
            } label: {
                actionLabel(title: "Done · Next Spin", icon: "checkmark", color: .green)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var promptAccent: Color {
        choice == .truth ? .blue : .red
    }

    // MARK: - Logic

    private func spin() {
        guard !players.isEmpty else { return }
        FeedbackService.shared.playRoundStart()
        SoundManager.shared.playBottleSpin()
        spinCount += 1
        let target = Int.random(in: 0..<players.count)
        let perSlice = anglePerPlayer
        let baseRotations = Double(Int.random(in: 10...14)) * 360
        let targetAngle = perSlice * Double(target)
        let jitter = Double.random(in: -perSlice * 0.25...perSlice * 0.25)
        let normalized = bottleAngle.truncatingRemainder(dividingBy: 360)
        let nextAngle = bottleAngle - normalized + baseRotations + targetAngle + jitter

        phase = .spinning
        withAnimation(.timingCurve(0.15, 0.45, 0.2, 1.0, duration: 8.0)) {
            bottleAngle = nextAngle
        }
        Task {
            try? await Task.sleep(for: .seconds(8.05))
            await MainActor.run {
                SoundManager.shared.playBottleLand()
                SoundManager.shared.playPlayerPicked()
                selectedPlayerIndex = target
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) { phase = .landed }
            }
        }
    }

    private func generatePrompt(reset: Bool) {
        let pool: [String]
        switch choice {
        case .truth:
            pool = SpinBottleContent.truths(for: difficulty)
        case .dare:
            pool = SpinBottleContent.dares(for: difficulty)
        }
        let used = choice == .truth ? usedTruths : usedDares
        let remaining = pool.filter { !used.contains($0) && $0 != promptText }
        let next = remaining.randomElement() ?? pool.filter { $0 != promptText }.randomElement() ?? (pool.first ?? "")
        promptText = next
        if reset {
            rerollsLeft = 2
        }
        if choice == .truth {
            usedTruths.insert(next)
            if usedTruths.count >= pool.count { usedTruths.removeAll() }
        } else {
            usedDares.insert(next)
            if usedDares.count >= pool.count { usedDares.removeAll() }
        }
    }

    private func completeRound() {
        promptText = ""
        rerollsLeft = 2
        withAnimation(.spring(duration: 0.45)) {
            phase = .idle
        }
    }
}

private struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let neckWidth = w * 0.45
        let neckHeight = h * 0.28
        let shoulder = h * 0.36

        path.move(to: CGPoint(x: rect.midX - neckWidth / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + neckWidth / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + neckWidth / 2, y: rect.minY + neckHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: shoulder),
            control: CGPoint(x: rect.maxX, y: rect.minY + neckHeight)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.08))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - w * 0.18, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + w * 0.18, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.08),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: shoulder))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - neckWidth / 2, y: rect.minY + neckHeight),
            control: CGPoint(x: rect.minX, y: rect.minY + neckHeight)
        )
        path.closeSubpath()
        return path
    }
}
