import SwiftUI

struct PassGuessSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onDismiss: () -> Void

    @State private var answerInput: String = ""
    @State private var showPrivacyScreen: Bool = false
    @State private var pendingPlayerName: String = ""
    @State private var pendingAction: PrivacyAction = .answer
    @State private var selectedGuessPlayerID: UUID? = nil
    @State private var introQuestionMode: PassGuessQuestionMode = .predefined
    @State private var introSelectedQuestionID: UUID? = nil
    @State private var introCustomQuestion: String = ""
    @FocusState private var isInputFocused: Bool

    private let predefinedQuestions: [PassGuessQuestion] = [
        PassGuessQuestion(text: "What is your most irrational fear?", type: .predefined),
        PassGuessQuestion(text: "What is the weirdest snack combo you would actually eat?", type: .predefined),
        PassGuessQuestion(text: "What would be your secret superpower in real life?", type: .predefined),
        PassGuessQuestion(text: "What is the most embarrassing song you know all the words to?", type: .predefined),
        PassGuessQuestion(text: "If you had to get a useless tattoo right now, what would it be?", type: .predefined),
        PassGuessQuestion(text: "What is one lie you would be terrible at keeping?", type: .predefined),
        PassGuessQuestion(text: "What is your fake luxury brand name?", type: .predefined),
        PassGuessQuestion(text: "What would your wrestling entrance name be?", type: .predefined),
        PassGuessQuestion(text: "What would you rename Monday to?", type: .predefined),
        PassGuessQuestion(text: "What is the pettiest reason you'd cancel plans?", type: .predefined),
        PassGuessQuestion(text: "What is your villain origin story?", type: .predefined),
        PassGuessQuestion(text: "If your laugh had a flavor, what would it be?", type: .predefined),
        PassGuessQuestion(text: "What is a fake excuse for being late that sounds real?", type: .predefined),
        PassGuessQuestion(text: "What would your autobiography be called?", type: .predefined),
        PassGuessQuestion(text: "What is the dumbest thing you'd fight a goose over?", type: .predefined),
        PassGuessQuestion(text: "What is your cursed startup idea?", type: .predefined),
        PassGuessQuestion(text: "What is your signature move in a pillow fight?", type: .predefined),
        PassGuessQuestion(text: "What is the most suspicious thing in your fridge right now?", type: .predefined),
        PassGuessQuestion(text: "If aliens landed today, what job would you pretend to have?", type: .predefined),
        PassGuessQuestion(text: "What is your most chaotic road trip role?", type: .predefined),
        PassGuessQuestion(text: "What tiny thing makes you feel powerful?", type: .predefined),
        PassGuessQuestion(text: "What would your signature perfume or cologne be named?", type: .predefined)
    ]

    private var isIntroQuestionValid: Bool {
        switch introQuestionMode {
        case .predefined:
            return introSelectedQuestionID != nil
        case .custom:
            return !introCustomQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private enum PrivacyAction {
        case answer
        case guess

        var subtitle: String {
            switch self {
            case .answer:
                return "They'll write their answer privately."
            case .guess:
                return "They'll guess who wrote this answer."
            }
        }
    }

    private var state: PassGuessRoundState? {
        session.passGuessState
    }

    private var roundNumber: Int {
        session.currentRoundIndex + 1
    }

    private var totalRounds: Int {
        state?.settings.rounds ?? session.rounds.count
    }

    private var currentPlayerID: UUID? {
        appModel.sessionPlayerID
    }

    private var currentAnsweringPlayer: PlayerProfile? {
        guard let state else { return nil }
        if session.mode == .singleDevice {
            guard state.answers.count < session.players.count else { return nil }
            return session.players[state.answers.count]
        }
        guard let currentPlayerID else { return nil }
        guard !state.answers.contains(where: { $0.playerID == currentPlayerID }) else { return nil }
        return session.players.first(where: { $0.id == currentPlayerID })
    }

    private var currentGuessingAnswer: PassGuessAnswer? {
        guard let state else { return nil }
        if session.mode == .singleDevice {
            let answerIndex = state.votes.count / session.players.count
            guard answerIndex < state.answers.count else { return nil }
            return state.answers[answerIndex]
        }
        guard let currentPlayerID else { return nil }
        return state.answers.first { answer in
            !state.votes.contains(where: { $0.answerID == answer.id && $0.voterID == currentPlayerID })
        }
    }

    private var currentGuessingPlayer: PlayerProfile? {
        guard let state else { return nil }
        if session.mode == .singleDevice {
            let voterIndex = state.votes.count % session.players.count
            guard voterIndex < session.players.count, !state.answers.isEmpty else { return nil }
            return session.players[voterIndex]
        }
        guard let currentPlayerID else { return nil }
        guard !state.answers.isEmpty else { return nil }
        return session.players.first(where: { $0.id == currentPlayerID })
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            if session.phase == .finished {
                finalResultsView
            } else if showPrivacyScreen {
                privacyScreenView
            } else if let state {
                switch state.phase {
                case .intro:
                    introView(state: state)
                case .answering:
                    if let player = currentAnsweringPlayer {
                        answeringView(state: state, player: player)
                    } else {
                        waitingView(message: "All answers collected...")
                    }
                case .guessing:
                    if let answer = currentGuessingAnswer, let player = currentGuessingPlayer {
                        guessingView(state: state, answer: answer, player: player)
                    } else {
                        waitingView(message: "All guesses collected...")
                    }
                case .reveal:
                    revealView(state: state)
                case .leaderboard:
                    leaderboardView(state: state)
                }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Pass & Guess")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: state?.phase) { _, newPhase in
            answerInput = ""
            selectedGuessPlayerID = nil
            guard session.mode == .singleDevice else { return }
            if newPhase == .answering, let player = currentAnsweringPlayer {
                pendingPlayerName = player.username
                pendingAction = .answer
                showPrivacyScreen = true
            } else if newPhase == .guessing, let player = currentGuessingPlayer {
                pendingPlayerName = player.username
                pendingAction = .guess
                showPrivacyScreen = true
            }
        }
        .preferredColorScheme(.dark)
    }

    private var privacyScreenView: some View {
        let playerColor = playerColorForName(pendingPlayerName)
        return GamePassPhoneView(
            playerName: pendingPlayerName,
            subtitle: pendingAction.subtitle,
            accentColor: playerColor,
            buttonTitle: "I'm Ready"
        ) {
            withAnimation(.spring(duration: 0.28)) {
                showPrivacyScreen = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }

    private func introView(state: PassGuessRoundState) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 84, height: 84)
                    .background(.yellow.opacity(0.14), in: .rect(cornerRadius: 24))
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text("Round \(roundNumber) / \(totalRounds)")
                        .font(.title2.weight(.bold))
                    Text(session.mode == .singleDevice ? "Everyone writes a private answer first. No reveals until the end." : "Everyone answers on their own phone. Anonymous reveals start after all submissions or timeout.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Choose a Question", systemImage: "questionmark.bubble.fill")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 8) {
                            introQuestionModeChip(title: "Predefined", mode: .predefined)
                            introQuestionModeChip(title: "Custom", mode: .custom)
                        }

                        if introQuestionMode == .predefined {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(predefinedQuestions) { question in
                                        Button {
                                            FeedbackService.shared.playClick()
                                            introSelectedQuestionID = question.id
                                        } label: {
                                            HStack(spacing: 10) {
                                                ZStack {
                                                    Circle()
                                                        .strokeBorder(introSelectedQuestionID == question.id ? Color.blue : .white.opacity(0.15), lineWidth: 2)
                                                        .frame(width: 20, height: 20)
                                                    if introSelectedQuestionID == question.id {
                                                        Circle()
                                                            .fill(.blue)
                                                            .frame(width: 10, height: 10)
                                                    }
                                                }
                                                Text(question.text)
                                                    .font(.caption.weight(.medium))
                                                    .multilineTextAlignment(.leading)
                                                    .foregroundStyle(.primary)
                                                Spacer(minLength: 0)
                                            }
                                            .padding(12)
                                            .background(introSelectedQuestionID == question.id ? .blue.opacity(0.16) : .white.opacity(0.04), in: .rect(cornerRadius: 14))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .strokeBorder(introSelectedQuestionID == question.id ? .blue.opacity(0.45) : .white.opacity(0.06))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 260)
                        } else {
                            TextField("Write your custom question", text: $introCustomQuestion, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                                .textInputAutocapitalization(.sentences)
                                .font(.subheadline)
                                .padding(12)
                                .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.white.opacity(0.05))
                                }
                        }
                    }
                }

                Button("Start Round") {
                    FeedbackService.shared.playRoundStart()
                    let updated = PassGuessSettings(
                        rounds: state.settings.rounds,
                        questionMode: introQuestionMode,
                        selectedQuestionID: introQuestionMode == .predefined ? introSelectedQuestionID : nil,
                        customQuestion: introQuestionMode == .custom ? introCustomQuestion : "",
                        answerTimeLimit: state.settings.answerTimeLimit,
                        guessTimeLimit: state.settings.guessTimeLimit
                    )
                    appModel.updatePassGuessSettings(updated)
                    appModel.advancePassGuessRoundIfPossible()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!isIntroQuestionValid)
                .opacity(isIntroQuestionValid ? 1 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .onAppear {
            if introSelectedQuestionID == nil {
                introSelectedQuestionID = predefinedQuestions.first?.id
            }
        }
    }

    private func introQuestionModeChip(title: String, mode: PassGuessQuestionMode) -> some View {
        Button {
            FeedbackService.shared.playClick()
            introQuestionMode = mode
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(introQuestionMode == mode ? .blue.opacity(0.18) : .white.opacity(0.06), in: .capsule)
                .foregroundStyle(introQuestionMode == mode ? .blue : .secondary)
                .overlay {
                    Capsule().strokeBorder(introQuestionMode == mode ? .blue.opacity(0.35) : .white.opacity(0.06))
                }
        }
        .buttonStyle(.plain)
    }

    private func answeringView(state: PassGuessRoundState, player: PlayerProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                roundBadge(playersText: "\(session.players.count) players")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            CurrentTurnPill(playerName: player.username, prefix: session.mode == .singleDevice ? "Now" : "Answer", accent: .green)
                            Spacer()
                            Text("\(state.answers.count)/\(session.players.count) answered")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(state.question.text)
                            .font(.title3.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeaderView(title: "Private Answer", subtitle: session.mode == .singleDevice ? "No previous answers are shown." : "Only your device sees your answer until the final reveal.")

                        TextField("Write your answer", text: $answerInput, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .focused($isInputFocused)
                            .textInputAutocapitalization(.sentences)
                            .onChange(of: answerInput) { _, newValue in
                                if newValue.count > 120 {
                                    answerInput = String(newValue.prefix(120))
                                }
                            }
                            .padding(14)
                            .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.05))
                            }

                        HStack {
                            Text("\(answerInput.count)/120")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Button(session.mode == .singleDevice ? "Done & Pass" : "Submit Answer") {
                            FeedbackService.shared.playClick()
                            let answer = answerInput
                            answerInput = ""
                            if session.mode == .singleDevice {
                                appModel.submitPassGuessAnswer(playerID: player.id, text: answer)
                                let nextIndex = state.answers.count + 1
                                if nextIndex < session.players.count {
                                    let nextPlayer = session.players[nextIndex]
                                    pendingPlayerName = nextPlayer.username
                                    pendingAction = .answer
                                    showPrivacyScreen = true
                                }
                            } else {
                                appModel.submitPassGuessAnswer(answer)
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(answerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(answerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func guessingView(state: PassGuessRoundState, answer: PassGuessAnswer, player: PlayerProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                roundBadge(playersText: session.mode == .singleDevice ? "Answer \(state.votes.count / session.players.count + 1) of \(state.answers.count)" : "Votes \(state.votes.count)/\(state.answers.count * session.players.count)")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anonymous Answer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(answer.text)
                            .font(.title3.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.username)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(playerColorForID(player.id))
                                Text("Who wrote this?")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(session.mode == .singleDevice ? "Vote \((state.votes.count % session.players.count) + 1)/\(session.players.count)" : "\(state.votes.filter { $0.answerID == answer.id }.count)/\(session.players.count) votes")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 10) {
                            ForEach(session.players) { candidate in
                                Button {
                                    if session.mode == .singleDevice {
                                        appModel.submitPassGuessVote(answerID: answer.id, voterID: player.id, guessedPlayerID: candidate.id)
                                        if let nextPlayer = nextGuessingPlayer(state: state) {
                                            pendingPlayerName = nextPlayer.username
                                            pendingAction = .guess
                                            showPrivacyScreen = true
                                        }
                                    } else {
                                        selectedGuessPlayerID = candidate.id
                                    }
                                } label: {
                                    let candidateColor = playerColorForID(candidate.id)
                                    HStack(spacing: 12) {
                                        GamePlayerAvatar(name: candidate.username, color: candidateColor, size: 34)
                                        Text(candidate.username)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(candidateColor)
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background((session.mode != .singleDevice && selectedGuessPlayerID == candidate.id) ? .blue.opacity(0.16) : .white.opacity(0.04), in: .rect(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder((session.mode != .singleDevice && selectedGuessPlayerID == candidate.id) ? .blue.opacity(0.45) : .white.opacity(0.06))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if session.mode != .singleDevice {
                            Button("Submit Vote") {
                                guard let selectedGuessPlayerID else { return }
                                appModel.submitPassGuessVote(answerID: answer.id, guessedPlayerID: selectedGuessPlayerID)
                                self.selectedGuessPlayerID = nil
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(selectedGuessPlayerID == nil)
                            .opacity(selectedGuessPlayerID == nil ? 0.5 : 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func revealView(state: PassGuessRoundState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                roundBadge(playersText: state.question.text)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderView(title: "Reveal", subtitle: "Now everyone sees who wrote each answer.")

                    ForEach(state.revealItems) { item in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.answerText)
                                    .font(.title3.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Label(item.playerName, systemImage: "person.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.yellow)
                                    Spacer()
                                    Text("\(item.correctGuessCount) correct")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Button("See Round Scores") {
                    FeedbackService.shared.playResultReveal()
                    appModel.advancePassGuessRoundIfPossible()
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func leaderboardView(state: PassGuessRoundState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                roundBadge(playersText: "Round complete")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeaderView(title: "Leaderboard", subtitle: "Scores after round \(roundNumber) of \(totalRounds)")

                        ForEach(Array(session.players.sorted { $0.score > $1.score }.enumerated()), id: \.element.id) { index, player in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 24, height: 24)
                                    .background(rankColor(index).opacity(0.22), in: .circle)
                                    .foregroundStyle(rankColor(index))
                                Text(player.username)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(playerColorForID(player.id))
                                Spacer()
                                Text("\(player.score)")
                                    .font(.headline.weight(.bold))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Button(roundNumber >= totalRounds ? "Finish Game" : "Next Round") {
                    FeedbackService.shared.playPhaseTransition()
                    appModel.advancePassGuessRoundIfPossible()
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var finalResultsView: some View {
        let archivedRounds = state?.archivedRounds ?? []
        let sortedPlayers = session.players.sorted { $0.score > $1.score }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 92, height: 92)
                        .background(.yellow.opacity(0.14), in: .rect(cornerRadius: 26))
                        .padding(.top, 8)
                    Text("Final Results")
                        .font(.title.weight(.bold))
                    Text("Everything stays hidden until this screen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeaderView(title: "Leaderboard", subtitle: "Highest score wins")

                        ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 24, height: 24)
                                    .background(rankColor(index).opacity(0.22), in: .circle)
                                    .foregroundStyle(rankColor(index))
                                Text(player.username)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(playerColorForID(player.id))
                                Spacer()
                                Text("\(player.score)")
                                    .font(.headline.weight(.bold))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeaderView(title: "Accuracy", subtitle: "Correct guesses per player")

                        ForEach(session.players) { player in
                            let stats = accuracyStats(for: player, rounds: archivedRounds)
                            HStack {
                                Text(player.username)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(playerColorForID(player.id))
                                Spacer()
                                Text("\(stats.correct)/\(stats.total)")
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                Text(stats.total == 0 ? "0%" : "\(Int((Double(stats.correct) / Double(stats.total)) * 100))%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                    }
                }

                if let hardest = hardestToGuess(rounds: archivedRounds) {
                    SurfaceCard {
                        HStack(spacing: 12) {
                            Image(systemName: "eye.slash.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.purple)
                                .frame(width: 40, height: 40)
                                .background(.purple.opacity(0.14), in: .rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hardest to Guess")
                                    .font(.subheadline.weight(.semibold))
                                Text(hardest.playerName)
                                    .font(.headline.weight(.bold))
                                Text("\(hardest.correctGuessCount) correct guesses across all rounds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderView(title: "Full Reveal", subtitle: "All answers and their real owners")

                    ForEach(archivedRounds) { round in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Round \(round.roundNumber)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(round.question.text)
                                    .font(.headline.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)

                                ForEach(round.revealItems) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.answerText)
                                            .font(.subheadline.weight(.semibold))
                                            .fixedSize(horizontal: false, vertical: true)
                                        HStack {
                                            Text(item.playerName)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.yellow)
                                            Text("· \(item.correctGuessCount) correct")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if item.id != round.revealItems.last?.id {
                                        Divider()
                                            .overlay(.white.opacity(0.08))
                                    }
                                }
                            }
                        }
                    }
                }

                Button("Play Again") {
                    appModel.replaySession()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 16)
        }
    }

    private func waitingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let state {
                if state.phase == .answering {
                    Text("\(state.answers.count)/\(session.players.count) players submitted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if state.phase == .guessing {
                    Text("\(state.votes.count)/\(state.answers.count * session.players.count) total votes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func roundBadge(playersText: String) -> some View {
        HStack(spacing: 8) {
            MetricChipView(title: "Round \(roundNumber) / \(totalRounds)", systemImage: "flag.fill")
            MetricChipView(title: playersText, systemImage: "person.2.fill")
            Spacer(minLength: 0)
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }

    private func nextGuessingPlayer(state: PassGuessRoundState) -> PlayerProfile? {
        let nextVoteCount = state.votes.count + 1
        let nextAnswerIndex = nextVoteCount / session.players.count
        let nextVoterIndex = nextVoteCount % session.players.count
        guard nextAnswerIndex < state.answers.count else { return nil }
        guard nextVoterIndex < session.players.count else { return nil }
        return session.players[nextVoterIndex]
    }

    private func accuracyStats(for player: PlayerProfile, rounds: [PassGuessArchivedRound]) -> (correct: Int, total: Int) {
        let playerVotes = rounds.flatMap { round in
            round.votes.filter { $0.voterID == player.id }
        }
        let answerLookup = Dictionary(uniqueKeysWithValues: rounds.flatMap { round in
            round.answers.map { ($0.id, $0) }
        })
        let correct = playerVotes.reduce(into: 0) { result, vote in
            if answerLookup[vote.answerID]?.playerID == vote.guessedPlayerID {
                result += 1
            }
        }
        return (correct, playerVotes.count)
    }

    private func playerColorForName(_ name: String) -> Color {
        guard let idx = session.players.firstIndex(where: { $0.username == name }) else { return .yellow }
        return GamePlayerColor.color(for: idx)
    }

    private func playerColorForID(_ id: UUID) -> Color {
        GamePlayerColor.color(for: id, in: session.players)
    }

    private func hardestToGuess(rounds: [PassGuessArchivedRound]) -> PassGuessRevealItem? {
        rounds
            .flatMap(\.revealItems)
            .sorted {
                if $0.correctGuessCount == $1.correctGuessCount {
                    return $0.playerName < $1.playerName
                }
                return $0.correctGuessCount < $1.correctGuessCount
            }
            .first
    }
}
