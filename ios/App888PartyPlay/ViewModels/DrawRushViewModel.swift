import Foundation
import Observation
import SwiftUI
import Supabase

@Observable
@MainActor
final class DrawRushViewModel {
    var players: [DRPlayer]
    var phase: DrawRushPhase = .turnIntro
    var currentDrawerIndex: Int = 0
    var currentRoundNumber: Int = 1
    var concept: String = ""
    var strokes: [DRStroke] = []
    var submittedAnswers: [DRAnswer] = []
    var secondsRemaining: Int = DrawRushScoring.drawDuration
    var drawingFinished: Bool = false
    var singleDeviceGuessIndex: Int = 0
    var canvasSize: CGSize = .zero
    var usedConcepts: Set<String> = []
    var isMultiDevice: Bool
    var roomCode: String?
    var localPlayerID: UUID?
    var errorMessage: String?
    var conceptMode: DRConceptMode

    private var timerTask: Task<Void, Never>?
    private var rng: UInt64

    // Multi-device realtime
    private var channel: RealtimeChannelV2?
    private var broadcastTask: Task<Void, Never>?
    private let supabase: SupabaseService

    init(players: [DRPlayer], isMultiDevice: Bool = false, roomCode: String? = nil, localPlayerID: UUID? = nil, conceptMode: DRConceptMode = .preset, supabase: SupabaseService = .shared) {
        self.players = players
        self.isMultiDevice = isMultiDevice
        self.roomCode = roomCode
        self.localPlayerID = localPlayerID
        self.conceptMode = conceptMode
        self.supabase = supabase
        self.rng = UInt64(Date().timeIntervalSince1970 * 1000)
        startTurn()
    }

    // MARK: - Turn lifecycle

    var currentDrawer: DRPlayer { players[currentDrawerIndex % max(players.count, 1)] }

    var isLocalPlayerDrawer: Bool {
        guard isMultiDevice, let localPlayerID else { return false }
        return currentDrawer.id == localPlayerID
    }

    var guessersForSingleDevice: [DRPlayer] {
        players.enumerated().filter { $0.offset != currentDrawerIndex }.map { $0.element }
    }

    var currentSingleDeviceGuesser: DRPlayer? {
        let guessers = guessersForSingleDevice
        guard singleDeviceGuessIndex < guessers.count else { return nil }
        return guessers[singleDeviceGuessIndex]
    }

    private func startTurn() {
        if conceptMode == .preset {
            concept = DrawRushConcepts.pick(seed: rng &+ UInt64(currentRoundNumber) &* 7919, avoid: usedConcepts)
            usedConcepts.insert(concept)
        } else {
            concept = ""
        }
        strokes = []
        submittedAnswers = []
        secondsRemaining = DrawRushScoring.drawDuration
        drawingFinished = false
        singleDeviceGuessIndex = 0
        phase = .turnIntro
        rng &+= 0x9e3779b97f4a7c15
    }

    func advanceFromIntro() {
        if isMultiDevice {
            // Drawer sees concept, others wait
            phase = .drawerReveal
            startDrawingPhase()
        } else {
            phase = .drawerReveal
        }
    }

    func startDrawingPhase() {
        phase = .drawing
        drawingFinished = false
        secondsRemaining = DrawRushScoring.drawDuration
        startTimer()
        if isMultiDevice {
            broadcastState()
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await MainActor.run {
                    guard self.phase == .drawing else { return }
                    if self.secondsRemaining > 0 {
                        self.secondsRemaining -= 1
                    }
                    if self.secondsRemaining <= 0 {
                        self.finishDrawing(fromTimer: true)
                    }
                    // Check all guessers submitted in multi
                    if self.isMultiDevice {
                        let guessers = self.players.filter { $0.id != self.currentDrawer.id }
                        if self.submittedAnswers.count >= guessers.count {
                            self.finishDrawing(fromTimer: false)
                        }
                    }
                }
            }
        }
    }

    func finishDrawing(fromTimer: Bool = false) {
        guard !drawingFinished else { return }
        drawingFinished = true
        timerTask?.cancel()
        if isMultiDevice {
            phase = .drawerJudging
        } else {
            phase = .passForGuesses
        }
        if isMultiDevice {
            broadcastState()
        }
    }

    // MARK: - Drawing
    func addStroke(_ stroke: DRStroke) {
        strokes.append(stroke)
        if isMultiDevice, isLocalPlayerDrawer {
            broadcastStrokeAppend(stroke)
        }
    }

    func appendPoint(_ point: DRPoint) {
        guard var last = strokes.last else { return }
        last.points.append(point)
        strokes[strokes.count - 1] = last
        if isMultiDevice, isLocalPlayerDrawer {
            broadcastPointAppend(point)
        }
    }

    func clearCanvas() {
        strokes = []
        if isMultiDevice, isLocalPlayerDrawer {
            broadcastClear()
        }
    }

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        if isMultiDevice, isLocalPlayerDrawer {
            broadcastState()
        }
    }

    // MARK: - Guessing
    func submitAnswerSingleDevice(_ text: String) {
        guard let guesser = currentSingleDeviceGuesser else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let answer = DRAnswer(
            playerID: guesser.id,
            playerName: guesser.name,
            text: trimmed,
            submittedAt: Date(),
            wasDuringDrawing: false,
            isCorrect: false,
            isJudged: false
        )
        submittedAnswers.append(answer)
        singleDeviceGuessIndex += 1
        if singleDeviceGuessIndex >= guessersForSingleDevice.count {
            phase = .drawerJudging
        }
    }

    func submitAnswerMultiDevice(_ text: String) {
        guard isMultiDevice, let localPlayerID else { return }
        guard !isLocalPlayerDrawer else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !submittedAnswers.contains(where: { $0.playerID == localPlayerID }) else { return }
        let playerName = players.first(where: { $0.id == localPlayerID })?.name ?? "Player"
        let answer = DRAnswer(
            playerID: localPlayerID,
            playerName: playerName,
            text: trimmed,
            submittedAt: Date(),
            wasDuringDrawing: phase == .drawing && !drawingFinished,
            isCorrect: false,
            isJudged: false
        )
        submittedAnswers.append(answer)
        broadcastAnswer(answer)
    }

    var hasLocalPlayerSubmitted: Bool {
        guard let localPlayerID else { return false }
        return submittedAnswers.contains(where: { $0.playerID == localPlayerID })
    }

    func setJudgement(for answerID: UUID, isCorrect: Bool) {
        guard let idx = submittedAnswers.firstIndex(where: { $0.id == answerID }) else { return }
        submittedAnswers[idx].isCorrect = isCorrect
        submittedAnswers[idx].isJudged = true
        if isMultiDevice {
            broadcastJudgement(answerID: answerID, isCorrect: isCorrect)
        }
    }

    var allAnswersJudged: Bool {
        !submittedAnswers.isEmpty && submittedAnswers.allSatisfy { $0.isJudged }
    }

    func finalizeJudging() {
        awardPointsAndShowResults()
        if isMultiDevice { broadcastState() }
    }

    private func awardPointsAndShowResults() {
        if isMultiDevice {
            let sortedCorrect = submittedAnswers.filter { $0.isCorrect }.sorted { $0.submittedAt < $1.submittedAt }
            var awarded: [UUID: Int] = [:]
            for (index, answer) in sortedCorrect.enumerated() {
                awarded[answer.playerID] = index == 0 ? DrawRushScoring.fastestCorrect : DrawRushScoring.otherCorrect
            }
            players = players.map { player in
                var p = player
                if let points = awarded[p.id] { p.score += points }
                return p
            }
        } else {
            var awarded: [UUID: Int] = [:]
            for answer in submittedAnswers where answer.isCorrect {
                awarded[answer.playerID] = DrawRushScoring.singleDeviceCorrect
            }
            players = players.map { player in
                var p = player
                if let points = awarded[p.id] { p.score += points }
                return p
            }
        }
        phase = .roundResults
    }

    func pointsAwarded(for answer: DRAnswer) -> Int {
        guard answer.isCorrect else { return 0 }
        if isMultiDevice {
            let sortedCorrect = submittedAnswers.filter { $0.isCorrect }.sorted { $0.submittedAt < $1.submittedAt }
            guard let index = sortedCorrect.firstIndex(where: { $0.id == answer.id }) else { return 0 }
            return index == 0 ? DrawRushScoring.fastestCorrect : DrawRushScoring.otherCorrect
        } else {
            return DrawRushScoring.singleDeviceCorrect
        }
    }

    func continueToNextTurn() {
        if currentDrawerIndex + 1 >= players.count {
            phase = .finalLeaderboard
            if isMultiDevice { broadcastState() }
            return
        }
        currentDrawerIndex += 1
        currentRoundNumber += 1
        startTurn()
        if isMultiDevice { broadcastState() }
    }

    func continueCycle() {
        currentDrawerIndex = 0
        currentRoundNumber = 1
        usedConcepts = []
        startTurn()
        if isMultiDevice { broadcastState() }
    }

    func restart() {
        players = players.map { DRPlayer(id: $0.id, name: $0.name, score: 0) }
        currentDrawerIndex = 0
        currentRoundNumber = 1
        usedConcepts = []
        startTurn()
        if isMultiDevice { broadcastState() }
    }

    var leaderboard: [DRPlayer] {
        players.sorted { $0.score > $1.score }
    }

    func cleanup() {
        timerTask?.cancel()
        timerTask = nil
        broadcastTask?.cancel()
        broadcastTask = nil
        Task { [channel, supabase] in
            if let channel {
                _ = await channel.unsubscribe()
                await supabase.client.removeChannel(channel)
            }
        }
        channel = nil
    }

    // MARK: - Realtime (multi-device)

    func joinRealtimeChannel() {
        guard isMultiDevice, let roomCode else { return }
        Task {
            let ch = supabase.client.channel("drawrush-\(roomCode)") {
                $0.broadcast.receiveOwnBroadcasts = false
            }
            self.channel = ch

            let strokeStart = ch.broadcastStream(event: "stroke_start")
            let strokePoint = ch.broadcastStream(event: "stroke_point")
            let clearStream = ch.broadcastStream(event: "clear")
            let answerStream = ch.broadcastStream(event: "answer")
            let stateStream = ch.broadcastStream(event: "state")
            let judgeStream = ch.broadcastStream(event: "judge")

            try? await ch.subscribeWithError()

            broadcastTask = Task { [weak self] in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await msg in strokeStart { await self?.handleStrokeStart(msg) }
                    }
                    group.addTask {
                        for await msg in strokePoint { await self?.handlePoint(msg) }
                    }
                    group.addTask {
                        for await _ in clearStream { await self?.handleClear() }
                    }
                    group.addTask {
                        for await msg in answerStream { await self?.handleAnswer(msg) }
                    }
                    group.addTask {
                        for await msg in stateStream { await self?.handleState(msg) }
                    }
                    group.addTask {
                        for await msg in judgeStream { await self?.handleJudge(msg) }
                    }
                }
            }
        }
    }

    private func broadcastStrokeAppend(_ stroke: DRStroke) {
        guard let channel else { return }
        let payload: [String: AnyJSON] = [
            "color": .string(stroke.color),
            "width": .double(stroke.width),
            "id": .string(stroke.id.uuidString)
        ]
        Task { try? await channel.broadcast(event: "stroke_start", message: payload) }
    }

    private func broadcastPointAppend(_ point: DRPoint) {
        guard let channel else { return }
        let payload: [String: AnyJSON] = [
            "x": .double(point.x),
            "y": .double(point.y)
        ]
        Task { try? await channel.broadcast(event: "stroke_point", message: payload) }
    }

    private func broadcastClear() {
        guard let channel else { return }
        Task { try? await channel.broadcast(event: "clear", message: [:]) }
    }

    private func broadcastJudgement(answerID: UUID, isCorrect: Bool) {
        guard let channel else { return }
        let payload: [String: AnyJSON] = [
            "id": .string(answerID.uuidString),
            "isCorrect": .bool(isCorrect)
        ]
        Task { try? await channel.broadcast(event: "judge", message: payload) }
    }

    private func broadcastAnswer(_ answer: DRAnswer) {
        guard let channel else { return }
        let payload: [String: AnyJSON] = [
            "id": .string(answer.id.uuidString),
            "playerID": .string(answer.playerID.uuidString),
            "playerName": .string(answer.playerName),
            "text": .string(answer.text),
            "submittedAt": .double(answer.submittedAt.timeIntervalSince1970),
            "wasDuringDrawing": .bool(answer.wasDuringDrawing),
            "isCorrect": .bool(answer.isCorrect)
        ]
        Task { try? await channel.broadcast(event: "answer", message: payload) }
    }

    private func broadcastState() {
        guard let channel else { return }
        let payload: [String: AnyJSON] = [
            "phase": .string(phaseString),
            "drawerIndex": .integer(currentDrawerIndex),
            "roundNumber": .integer(currentRoundNumber),
            "concept": .string(concept),
            "secondsRemaining": .integer(secondsRemaining),
            "drawingFinished": .bool(drawingFinished),
            "scores": .array(players.map { .array([.string($0.id.uuidString), .integer($0.score)]) }),
            "conceptMode": .string(conceptMode.rawValue)
        ]
        Task { try? await channel.broadcast(event: "state", message: payload) }
    }

    private var phaseString: String {
        switch phase {
        case .turnIntro: return "turnIntro"
        case .drawerReveal: return "drawerReveal"
        case .drawing: return "drawing"
        case .passForGuesses: return "passForGuesses"
        case .guessing: return "guessing"
        case .drawerJudging: return "drawerJudging"
        case .roundResults: return "roundResults"
        case .finalLeaderboard: return "finalLeaderboard"
        }
    }

    private func phase(from string: String) -> DrawRushPhase? {
        switch string {
        case "turnIntro": return .turnIntro
        case "drawerReveal": return .drawerReveal
        case "drawing": return .drawing
        case "passForGuesses": return .passForGuesses
        case "guessing": return .guessing
        case "drawerJudging": return .drawerJudging
        case "roundResults": return .roundResults
        case "finalLeaderboard": return .finalLeaderboard
        default: return nil
        }
    }

    private func handleStrokeStart(_ message: JSONObject) {
        guard isMultiDevice, !isLocalPlayerDrawer else { return }
        guard case .string(let colorStr) = message["color"] else { return }
        let width: Double = {
            if case .double(let w) = message["width"] { return w }
            return 4
        }()
        let id: UUID = {
            if case .string(let s) = message["id"], let uuid = UUID(uuidString: s) { return uuid }
            return UUID()
        }()
        strokes.append(DRStroke(id: id, color: colorStr, width: width, points: []))
    }

    private func handlePoint(_ message: JSONObject) {
        guard isMultiDevice, !isLocalPlayerDrawer else { return }
        guard case .double(let x) = message["x"], case .double(let y) = message["y"] else { return }
        guard var last = strokes.last else { return }
        last.points.append(DRPoint(x: x, y: y))
        strokes[strokes.count - 1] = last
    }

    private func handleClear() {
        guard isMultiDevice, !isLocalPlayerDrawer else { return }
        strokes = []
    }

    private func handleAnswer(_ message: JSONObject) {
        guard isMultiDevice else { return }
        guard case .string(let idStr) = message["id"], let id = UUID(uuidString: idStr) else { return }
        guard !submittedAnswers.contains(where: { $0.id == id }) else { return }
        guard case .string(let pidStr) = message["playerID"], let pid = UUID(uuidString: pidStr) else { return }
        guard case .string(let name) = message["playerName"] else { return }
        guard case .string(let text) = message["text"] else { return }
        let submittedAt: Date = {
            if case .double(let t) = message["submittedAt"] { return Date(timeIntervalSince1970: t) }
            return Date()
        }()
        let wasDuring: Bool = {
            if case .bool(let b) = message["wasDuringDrawing"] { return b }
            return false
        }()
        let isCorrect: Bool = {
            if case .bool(let b) = message["isCorrect"] { return b }
            return false
        }()
        submittedAnswers.append(DRAnswer(id: id, playerID: pid, playerName: name, text: text, submittedAt: submittedAt, wasDuringDrawing: wasDuring, isCorrect: isCorrect))
    }

    private func handleJudge(_ message: JSONObject) {
        guard isMultiDevice else { return }
        guard case .string(let idStr) = message["id"], let id = UUID(uuidString: idStr) else { return }
        guard case .bool(let correct) = message["isCorrect"] else { return }
        guard let idx = submittedAnswers.firstIndex(where: { $0.id == id }) else { return }
        submittedAnswers[idx].isCorrect = correct
        submittedAnswers[idx].isJudged = true
    }

    func setConceptModeAndBroadcast(_ mode: DRConceptMode) {
        conceptMode = mode
        if mode == .freeDraw {
            concept = ""
        } else if concept.isEmpty {
            concept = DrawRushConcepts.pick(seed: rng &+ UInt64(currentRoundNumber) &* 7919, avoid: usedConcepts)
            usedConcepts.insert(concept)
        }
        if isMultiDevice { broadcastState() }
    }

    private func handleState(_ message: JSONObject) {
        guard isMultiDevice else { return }
        if case .string(let phaseStr) = message["phase"], let newPhase = phase(from: phaseStr) {
            if newPhase == .roundResults && phase != .roundResults {
                phase = .roundResults
                awardPointsAndShowResults()
            } else {
                phase = newPhase
            }
        }
        if case .integer(let di) = message["drawerIndex"] {
            currentDrawerIndex = di
        }
        if case .integer(let rn) = message["roundNumber"] {
            currentRoundNumber = rn
        }
        if case .string(let c) = message["concept"] {
            concept = c
        }
        if case .integer(let s) = message["secondsRemaining"] {
            secondsRemaining = s
        }
        if case .string(let cm) = message["conceptMode"], let mode = DRConceptMode(rawValue: cm) {
            conceptMode = mode
        }
    }
}
