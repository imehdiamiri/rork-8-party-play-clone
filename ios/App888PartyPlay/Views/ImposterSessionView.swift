import SwiftUI

struct ImposterSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @State private var imposterState: ImposterRoundState?
    @State private var currentRevealIndex: Int = 0
    @State private var isRoleRevealed: Bool = false
    @State private var clueInput: String = ""
    @State private var selectedSuspect: UUID?
    @State private var showVoteConfirm: Bool = false
    @State private var discussionTimer: Task<Void, Never>?
    @State private var showResults: Bool = false
    @State private var currentRoundIndex: Int = 0
    @State private var scores: [UUID: Int] = [:]
    @State private var roundComplete: Bool = false
    @State private var gameFinished: Bool = false

    private var settings: ImposterSettings {
        appModel.currentImposterSettings ?? .default
    }

    private var players: [PlayerProfile] {
        session.players
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            if gameFinished {
                finalResultsView
            } else if roundComplete {
                roundResultView
            } else if let state = imposterState {
                ScrollView {
                    VStack(spacing: 16) {
                        roundHeader(state: state)
                        phaseContent(state: state)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .navigationTitle("Imposter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if imposterState == nil {
                startNewRound()
            }
        }
        .onDisappear {
            discussionTimer?.cancel()
        }
    }

    private func roundHeader(state: ImposterRoundState) -> some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Round \(currentRoundIndex + 1) of \(settings.rounds)")
                        .font(.headline.weight(.bold))
                    Text(settings.gameStyle.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPillView(
                    title: phaseTitle(state.phase),
                    systemImage: phaseIcon(state.phase),
                    tint: settings.gameStyle.accentColor
                )
            }
        }
    }

    @ViewBuilder
    private func phaseContent(state: ImposterRoundState) -> some View {
        switch state.phase {
        case .roleReveal:
            roleRevealView(state: state)
        case .ready:
            readyCheckView(state: state)
        case .discussion:
            discussionView(state: state)
        case .clueGiving:
            clueGivingView(state: state)
        case .voting:
            votingView(state: state)
        case .result:
            EmptyView()
        }
    }

    private func roleRevealView(state: ImposterRoundState) -> some View {
        VStack(spacing: 16) {
            if currentRevealIndex < players.count {
                let player = players[currentRevealIndex]
                let isImposter = player.id == state.imposterPlayerID

                SurfaceCard {
                    VStack(spacing: 20) {
                        if !isRoleRevealed {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)

                            Text("Pass the phone to")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(player.username)
                                .font(.title.weight(.bold))

                            Button("Reveal My Role") {
                                withAnimation(.spring(duration: 0.4)) {
                                    isRoleRevealed = true
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .sensoryFeedback(.impact(flexibility: .soft), trigger: isRoleRevealed)
                        } else {
                            Image(systemName: isImposter ? "theatermasks.fill" : "checkmark.shield.fill")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(isImposter ? .red : .green)
                                .padding(.top, 8)

                            if isImposter {
                                Text("You are the Imposter!")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.red)
                                Text("Blend in. Don't get caught.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 6) {
                                    Text("The secret word is:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(state.secretWord)
                                        .font(.title.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(settings.gameStyle.accentColor.opacity(0.2), in: .rect(cornerRadius: 14))
                                }
                            }

                            Button("Got it") {
                                withAnimation {
                                    isRoleRevealed = false
                                    var updated = state
                                    let newRevealed = state.revealedPlayerIDs.union([player.id])
                                    updated = ImposterRoundState(
                                        settings: state.settings,
                                        phase: state.phase,
                                        secretWord: state.secretWord,
                                        imposterPlayerID: state.imposterPlayerID,
                                        revealedPlayerIDs: newRevealed,
                                        readyPlayerIDs: state.readyPlayerIDs,
                                        currentCluePlayerIndex: state.currentCluePlayerIndex,
                                        clues: state.clues,
                                        votes: state.votes,
                                        discussionTimeRemaining: state.discussionTimeRemaining
                                    )
                                    currentRevealIndex += 1
                                    if currentRevealIndex >= players.count {
                                        updated = ImposterRoundState(
                                            settings: state.settings,
                                            phase: .ready,
                                            secretWord: state.secretWord,
                                            imposterPlayerID: state.imposterPlayerID,
                                            revealedPlayerIDs: newRevealed,
                                            readyPlayerIDs: [],
                                            currentCluePlayerIndex: 0,
                                            clues: [],
                                            votes: [],
                                            discussionTimeRemaining: settings.discussionDuration
                                        )
                                    }
                                    imposterState = updated
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func readyCheckView(state: ImposterRoundState) -> some View {
        SurfaceCard {
            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(settings.gameStyle.accentColor)

                Text("Everyone has seen their role")
                    .font(.title3.weight(.bold))

                Text(settings.gameStyle == .discussion
                     ? "Get ready for \(settings.discussionDuration) seconds of discussion!"
                     : "Get ready to give clues one by one!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Start") {
                    withAnimation {
                        if settings.gameStyle == .discussion {
                            imposterState = ImposterRoundState(
                                settings: state.settings,
                                phase: .discussion,
                                secretWord: state.secretWord,
                                imposterPlayerID: state.imposterPlayerID,
                                revealedPlayerIDs: state.revealedPlayerIDs,
                                readyPlayerIDs: state.readyPlayerIDs,
                                currentCluePlayerIndex: 0,
                                clues: [],
                                votes: [],
                                discussionTimeRemaining: settings.discussionDuration
                            )
                            startDiscussionTimer()
                        } else {
                            imposterState = ImposterRoundState(
                                settings: state.settings,
                                phase: .clueGiving,
                                secretWord: state.secretWord,
                                imposterPlayerID: state.imposterPlayerID,
                                revealedPlayerIDs: state.revealedPlayerIDs,
                                readyPlayerIDs: state.readyPlayerIDs,
                                currentCluePlayerIndex: 0,
                                clues: [],
                                votes: [],
                                discussionTimeRemaining: 0
                            )
                        }
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .sensoryFeedback(.impact(flexibility: .rigid), trigger: imposterState?.phase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func discussionView(state: ImposterRoundState) -> some View {
        VStack(spacing: 16) {
            SurfaceCard {
                VStack(spacing: 16) {
                    Text("\(state.discussionTimeRemaining)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.discussionTimeRemaining <= 10 ? .red : .white)

                    Text("seconds remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: Double(state.discussionTimeRemaining), total: Double(settings.discussionDuration))
                        .tint(state.discussionTimeRemaining <= 10 ? .red : settings.gameStyle.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderView(title: "Discuss!", subtitle: "Talk freely and figure out who the Imposter is.")

                    ForEach(players) { player in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(.white.opacity(0.08))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Text(String(player.username.prefix(1)).uppercased())
                                        .font(.caption.weight(.bold))
                                }
                            Text(player.username)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                    }
                }
            }

            Button("Skip to Voting") {
                discussionTimer?.cancel()
                moveToVoting(state: state)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private func clueGivingView(state: ImposterRoundState) -> some View {
        VStack(spacing: 16) {
            if state.currentCluePlayerIndex < players.count {
                let currentPlayer = players[state.currentCluePlayerIndex]

                SurfaceCard {
                    VStack(spacing: 16) {
                        Text("Turn \(state.currentCluePlayerIndex + 1) of \(players.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(settings.gameStyle.accentColor)

                        CurrentTurnPill(playerName: currentPlayer.username, prefix: "Now", accent: .green)

                        Text("Give a ONE-WORD clue about the secret word")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("Your clue...", text: $clueInput)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.08))
                            }

                        Button("Submit Clue") {
                            submitClue(state: state, playerID: currentPlayer.id)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(clueInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                if !state.clues.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "Clues Given", subtitle: "")
                            ForEach(state.clues) { clue in
                                let playerName = players.first(where: { $0.id == clue.playerID })?.username ?? "Player"
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(.white.opacity(0.08))
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            Text(String(playerName.prefix(1)).uppercased())
                                                .font(.caption2.weight(.bold))
                                        }
                                    Text(playerName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(clue.clueText)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func votingView(state: ImposterRoundState) -> some View {
        VStack(spacing: 16) {
            let currentVoterIndex = state.votes.count
            if currentVoterIndex < players.count {
                let currentVoter = players[currentVoterIndex]

                SurfaceCard {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.red)

                        Text("\(currentVoter.username)'s Vote")
                            .font(.title3.weight(.bold))

                        Text("Who do you think is the Imposter?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            ForEach(players.filter({ $0.id != currentVoter.id })) { suspect in
                                Button {
                                    withAnimation(.spring(duration: 0.2)) {
                                        selectedSuspect = suspect.id
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(selectedSuspect == suspect.id ? settings.gameStyle.accentColor.opacity(0.3) : .white.opacity(0.08))
                                            .frame(width: 36, height: 36)
                                            .overlay {
                                                Text(String(suspect.username.prefix(1)).uppercased())
                                                    .font(.caption.weight(.bold))
                                            }
                                        Text(suspect.username)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        if selectedSuspect == suspect.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(settings.gameStyle.accentColor)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        selectedSuspect == suspect.id ? settings.gameStyle.accentColor.opacity(0.12) : .white.opacity(0.04),
                                        in: .rect(cornerRadius: 14)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(selectedSuspect == suspect.id ? settings.gameStyle.accentColor.opacity(0.5) : .white.opacity(0.05))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button("Confirm Vote") {
                            submitVote(state: state, voterID: currentVoter.id)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(selectedSuspect == nil)
                        .sensoryFeedback(.impact(flexibility: .rigid), trigger: state.votes.count)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            if !state.clues.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "Clues Recap", subtitle: "")
                        ForEach(state.clues) { clue in
                            let playerName = players.first(where: { $0.id == clue.playerID })?.username ?? "Player"
                            HStack(spacing: 8) {
                                Text(playerName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(clue.clueText)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    private var roundResultView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let state = imposterState {
                    let voteCounts = countVotes(state: state)
                    let topSuspect = voteCounts.max(by: { $0.value < $1.value })
                    let imposterCaught = topSuspect?.key == state.imposterPlayerID
                    let imposterName = players.first(where: { $0.id == state.imposterPlayerID })?.username ?? "???"

                    SurfaceCard {
                        VStack(spacing: 20) {
                            Image(systemName: imposterCaught ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 56, weight: .semibold))
                                .foregroundStyle(imposterCaught ? .green : .red)

                            Text(imposterCaught ? "Imposter Caught!" : "Imposter Wins!")
                                .font(.title.weight(.bold))
                                .foregroundStyle(imposterCaught ? .green : .red)

                            VStack(spacing: 6) {
                                Text("The Imposter was")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(imposterName)
                                    .font(.title2.weight(.bold))
                            }

                            VStack(spacing: 6) {
                                Text("The secret word was")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(state.secretWord)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(settings.gameStyle.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeaderView(title: "Vote Results", subtitle: "")
                            ForEach(players) { player in
                                let voteCount = voteCounts[player.id] ?? 0
                                let isImposter = player.id == state.imposterPlayerID
                                let playerColor = isImposter ? Color.red : GamePlayerColor.color(for: player.id, in: players)
                                HStack(spacing: 10) {
                                    GamePlayerAvatar(name: player.username, color: playerColor, size: 32)
                                    Text(player.username)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(playerColor)
                                    if isImposter {
                                        StatusPillView(title: "Imposter", systemImage: "theatermasks.fill", tint: .red)
                                    }
                                    Spacer()
                                    Text("\(voteCount) votes")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "Scoring", subtitle: "How points are awarded")
                            VStack(alignment: .leading, spacing: 6) {
                                scoringRow(icon: "checkmark.circle.fill", color: .green, text: "Voted for the Imposter correctly: +100 pts")
                                scoringRow(icon: "xmark.circle.fill", color: .red, text: "Imposter survives the vote: +150 pts to Imposter")
                                scoringRow(icon: "minus.circle.fill", color: .secondary, text: "Wrong vote: 0 pts")
                            }
                        }
                    }

                    Button(currentRoundIndex + 1 < settings.rounds ? "Next Round" : "See Final Results") {
                        if currentRoundIndex + 1 < settings.rounds {
                            currentRoundIndex += 1
                            roundComplete = false
                            startNewRound()
                        } else {
                            gameFinished = true
                            roundComplete = false
                            FeedbackService.shared.playGameEnd()
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private var finalResultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                SurfaceCard {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.yellow)

                        Text("Game Over!")
                            .font(.title.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeaderView(title: "Final Scores", subtitle: "")
                        let sorted = players.sorted { (scores[$0.id] ?? 0) > (scores[$1.id] ?? 0) }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, player in
                            let playerColor = GamePlayerColor.color(for: player.id, in: players)
                            HStack(spacing: 12) {
                                Text("#\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(index == 0 ? .yellow : .secondary)
                                    .frame(width: 30)
                                GamePlayerAvatar(name: player.username, color: playerColor, size: 32)
                                Text(player.username)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(playerColor)
                                Spacer()
                                Text("\(scores[player.id] ?? 0) pts")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(index == 0 ? .yellow : settings.gameStyle.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                VStack(spacing: 10) {
                    Button("Play Again") {
                        currentRoundIndex = 0
                        scores = [:]
                        gameFinished = false
                        roundComplete = false
                        startNewRound()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private func startNewRound() {
        currentRevealIndex = 0
        isRoleRevealed = false
        clueInput = ""
        selectedSuspect = nil
        FeedbackService.shared.playRoundStart()

        let words = settings.categoryPack.words
        let secretWord = words.randomElement() ?? "Mystery"
        let imposterID = players.randomElement()?.id ?? players[0].id

        imposterState = ImposterRoundState(
            settings: settings,
            phase: .roleReveal,
            secretWord: secretWord,
            imposterPlayerID: imposterID,
            discussionTimeRemaining: settings.discussionDuration
        )
    }

    private func startDiscussionTimer() {
        discussionTimer?.cancel()
        discussionTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let state = imposterState, state.phase == .discussion else { return }
                let remaining = state.discussionTimeRemaining - 1
                if remaining <= 0 {
                    moveToVoting(state: state)
                    return
                }
                imposterState = ImposterRoundState(
                    settings: state.settings,
                    phase: .discussion,
                    secretWord: state.secretWord,
                    imposterPlayerID: state.imposterPlayerID,
                    revealedPlayerIDs: state.revealedPlayerIDs,
                    readyPlayerIDs: state.readyPlayerIDs,
                    currentCluePlayerIndex: state.currentCluePlayerIndex,
                    clues: state.clues,
                    votes: state.votes,
                    discussionTimeRemaining: remaining
                )
            }
        }
    }

    private func moveToVoting(state: ImposterRoundState) {
        selectedSuspect = nil
        FeedbackService.shared.playPhaseTransition()
        imposterState = ImposterRoundState(
            settings: state.settings,
            phase: .voting,
            secretWord: state.secretWord,
            imposterPlayerID: state.imposterPlayerID,
            revealedPlayerIDs: state.revealedPlayerIDs,
            readyPlayerIDs: state.readyPlayerIDs,
            currentCluePlayerIndex: state.currentCluePlayerIndex,
            clues: state.clues,
            votes: [],
            discussionTimeRemaining: 0
        )
    }

    private func submitClue(state: ImposterRoundState, playerID: UUID) {
        let trimmed = clueInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        FeedbackService.shared.playClick()
        let clue = ImposterClue(playerID: playerID, clueText: String(trimmed.prefix(30)))
        let updatedClues = state.clues + [clue]
        let nextIndex = state.currentCluePlayerIndex + 1
        clueInput = ""

        if nextIndex >= players.count {
            selectedSuspect = nil
            imposterState = ImposterRoundState(
                settings: state.settings,
                phase: .voting,
                secretWord: state.secretWord,
                imposterPlayerID: state.imposterPlayerID,
                revealedPlayerIDs: state.revealedPlayerIDs,
                readyPlayerIDs: state.readyPlayerIDs,
                currentCluePlayerIndex: nextIndex,
                clues: updatedClues,
                votes: [],
                discussionTimeRemaining: 0
            )
        } else {
            imposterState = ImposterRoundState(
                settings: state.settings,
                phase: .clueGiving,
                secretWord: state.secretWord,
                imposterPlayerID: state.imposterPlayerID,
                revealedPlayerIDs: state.revealedPlayerIDs,
                readyPlayerIDs: state.readyPlayerIDs,
                currentCluePlayerIndex: nextIndex,
                clues: updatedClues,
                votes: state.votes,
                discussionTimeRemaining: 0
            )
        }
    }

    private func submitVote(state: ImposterRoundState, voterID: UUID) {
        guard let suspect = selectedSuspect else { return }
        FeedbackService.shared.playVote()
        let vote = ImposterVote(voterID: voterID, suspectID: suspect)
        let updatedVotes = state.votes + [vote]
        selectedSuspect = nil

        if updatedVotes.count >= players.count {
            let finalState = ImposterRoundState(
                settings: state.settings,
                phase: .result,
                secretWord: state.secretWord,
                imposterPlayerID: state.imposterPlayerID,
                revealedPlayerIDs: state.revealedPlayerIDs,
                readyPlayerIDs: state.readyPlayerIDs,
                currentCluePlayerIndex: state.currentCluePlayerIndex,
                clues: state.clues,
                votes: updatedVotes,
                discussionTimeRemaining: 0
            )
            imposterState = finalState
            calculateRoundScores(state: finalState)
            roundComplete = true
            FeedbackService.shared.playResultReveal()
        } else {
            imposterState = ImposterRoundState(
                settings: state.settings,
                phase: .voting,
                secretWord: state.secretWord,
                imposterPlayerID: state.imposterPlayerID,
                revealedPlayerIDs: state.revealedPlayerIDs,
                readyPlayerIDs: state.readyPlayerIDs,
                currentCluePlayerIndex: state.currentCluePlayerIndex,
                clues: state.clues,
                votes: updatedVotes,
                discussionTimeRemaining: 0
            )
        }
    }

    private func countVotes(state: ImposterRoundState) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for vote in state.votes {
            counts[vote.suspectID, default: 0] += 1
        }
        return counts
    }

    private func calculateRoundScores(state: ImposterRoundState) {
        let voteCounts = countVotes(state: state)
        let topSuspect = voteCounts.max(by: { $0.value < $1.value })
        let imposterCaught = topSuspect?.key == state.imposterPlayerID

        if imposterCaught {
            for player in players where player.id != state.imposterPlayerID {
                if voteCounts.max(by: { $0.value < $1.value })?.key == state.imposterPlayerID {
                    let voted = state.votes.first(where: { $0.voterID == player.id })
                    if voted?.suspectID == state.imposterPlayerID {
                        scores[player.id, default: 0] += 100
                    }
                }
            }
        } else {
            scores[state.imposterPlayerID, default: 0] += 150
        }
    }

    private func scoringRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func phaseTitle(_ phase: ImposterPhase) -> String {
        switch phase {
        case .roleReveal: return "Roles"
        case .ready: return "Ready"
        case .discussion: return "Discuss"
        case .clueGiving: return "Clues"
        case .voting: return "Vote"
        case .result: return "Result"
        }
    }

    private func phaseIcon(_ phase: ImposterPhase) -> String {
        switch phase {
        case .roleReveal: return "eye.fill"
        case .ready: return "checkmark.circle.fill"
        case .discussion: return "bubble.left.and.bubble.right.fill"
        case .clueGiving: return "magnifyingglass"
        case .voting: return "hand.raised.fill"
        case .result: return "trophy.fill"
        }
    }
}
