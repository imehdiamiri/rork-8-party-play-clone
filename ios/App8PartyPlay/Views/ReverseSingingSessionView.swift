import AudioToolbox
import AVFoundation
import Observation
import SwiftUI
import UIKit

struct ReverseSingingSessionView: View {
    let appModel: AppViewModel
    let session: GameSession
    let onExit: () -> Void

    @State private var viewModel: ReverseSingingSessionViewModel
    @State private var isShowingHistory: Bool = false
    @State private var isShowingShareOptions: Bool = false

    init(appModel: AppViewModel, session: GameSession, onExit: @escaping () -> Void) {
        self.appModel = appModel
        self.session = session
        self.onExit = onExit
        _viewModel = State(initialValue: ReverseSingingSessionViewModel(session: session))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    playerOneCard
                    playerTwoCard
                    historyCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Reverse Singing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.prepareAudioSession()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.handleBackgrounded()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
            viewModel.handleAudioInterruption(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { note in
            viewModel.handleRouteChange(note)
        }
        .sheet(isPresented: $isShowingHistory) {
            ReverseSingingHistorySheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .confirmationDialog("Share", isPresented: $isShowingShareOptions, titleVisibility: .visible) {
            Button("Share Player 2 Raw") {
                viewModel.prepareShare(kind: .playerTwoRaw)
            }
            .disabled(!viewModel.canSharePlayerTwoRaw)

            Button("Share Result") {
                viewModel.prepareShare(kind: .result)
            }
            .disabled(!viewModel.canShareResult)

            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(get: { viewModel.sharePayload }, set: { viewModel.sharePayload = $0 })) { payload in
            ReverseSingingShareSheet(payload: payload)
        }
        .alert("Microphone Access Needed", isPresented: Binding(get: { viewModel.permissionAlertMessage != nil }, set: { newValue in
            if !newValue { viewModel.permissionAlertMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.permissionAlertMessage ?? "")
        }
        .alert("Audio Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { newValue in
            if !newValue { viewModel.errorMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var playerOneCard: some View {
        ReverseSingingPassCard(
            title: "Player 1",
            subtitle: "record anything you want",
            helperText: "",
            statusText: viewModel.activeStep == .playerOne ? "Active" : nil,
            statusTint: .green,
            isActive: viewModel.activeStep == .playerOne,
            waveform: viewModel.playerOneWaveform,
            durationText: viewModel.playerOneDurationText,
            layout: .playerOne(
                record: .init(title: viewModel.isRecordingPlayerOne ? "\(viewModel.recordingTimeText)" : "Record", systemImage: viewModel.isRecordingPlayerOne ? "stop.fill" : "record.circle.fill", style: .record, isEnabled: viewModel.canRecordPlayerOne, isRecording: viewModel.isRecordingPlayerOne, action: viewModel.togglePlayerOneRecording),
                play: .init(title: "Play", systemImage: "play.fill", style: .circle, isEnabled: viewModel.canPlayPlayerOne, action: viewModel.playPlayerOne),
                reverse: .init(title: "Play Reverse", systemImage: "backward.fill", style: .reverse, isEnabled: viewModel.canPlayPlayerOneReverse, action: viewModel.playPlayerOneReverse),
                slow: .init(title: "Slow", systemImage: "tortoise.fill", style: .circle, isEnabled: viewModel.canPlayPlayerOneReverse, action: viewModel.playPlayerOneReverseSlow)
            )
        )
    }

    private var playerTwoCard: some View {
        ReverseSingingPassCard(
            title: "Player 2",
            subtitle: "try to copy reversed",
            helperText: viewModel.playerTwoHelperTextShort,
            statusText: viewModel.playerTwoStatusText,
            statusTint: viewModel.playerTwoStatusTint,
            isActive: viewModel.activeStep == .playerTwo,
            waveform: viewModel.playerTwoWaveform,
            durationText: viewModel.playerTwoDurationText,
            layout: .playerTwo(
                record: .init(title: viewModel.isRecordingPlayerTwo ? "\(viewModel.recordingTimeText)" : "Record Mimic", systemImage: viewModel.isRecordingPlayerTwo ? "stop.fill" : "record.circle.fill", style: .record, isEnabled: viewModel.canRecordPlayerTwo, isRecording: viewModel.isRecordingPlayerTwo, action: viewModel.togglePlayerTwoRecording),
                play: .init(title: "Play", systemImage: "play.fill", style: .circle, isEnabled: viewModel.canPlayPlayerTwo, action: viewModel.playPlayerTwo),
                result: .init(title: "Result", systemImage: "sparkles", style: .result, isEnabled: viewModel.canPlayResult, action: viewModel.playResult),
                share: .init(title: "Share", systemImage: "square.and.arrow.up", style: .circle, isEnabled: viewModel.canShareAnything, action: { isShowingShareOptions = true })
            )
        )
    }

    private var historyCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("History")
                            .font(.headline.weight(.bold))
                        Text("Last 20 only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Open") {
                        isShowingHistory = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                if let latest = viewModel.history.first {
                    ReverseSingingHistoryRow(item: latest, onAction: viewModel.handleHistoryAction)
                }
            }
        }
    }
}

@MainActor
@Observable
final class ReverseSingingSessionViewModel {
    nonisolated enum ActiveStep: String, Sendable {
        case playerOne
        case playerTwo
    }

    nonisolated enum ShareKind: Hashable, Sendable {
        case playerTwoRaw
        case result
    }

    nonisolated enum HistoryAction: Hashable, Sendable {
        case mimic
        case result
        case shareMimic
        case shareResult
    }

    nonisolated struct SharePayload: Identifiable, Hashable, Sendable {
        let id: UUID
        let title: String
        let url: URL
    }

    nonisolated struct HistoryItem: Identifiable, Hashable, Sendable, Codable {
        let id: UUID
        let date: Date
        let playerOneFileName: String
        let playerOneReverseFileName: String?
        let playerTwoFileName: String?
        let resultFileName: String?
        let playerOneDuration: TimeInterval
        let playerTwoDuration: TimeInterval

        var playerOneURL: URL { URL.cachesDirectory.appending(path: playerOneFileName) }
        var playerOneReverseURL: URL? { playerOneReverseFileName.map { URL.cachesDirectory.appending(path: $0) } }
        var playerTwoURL: URL? { playerTwoFileName.map { URL.cachesDirectory.appending(path: $0) } }
        var resultURL: URL? { resultFileName.map { URL.cachesDirectory.appending(path: $0) } }
    }

    let session: GameSession
    var activeStep: ActiveStep = .playerOne
    var isRecordingPlayerOne: Bool = false
    var isRecordingPlayerTwo: Bool = false
    var recordingElapsed: Int = 0
    private var recordingTimer: Timer?
    private let maxRecordingSeconds: Int = 60
    var playerOneURL: URL?
    var playerOneReverseURL: URL?
    var playerTwoURL: URL?
    var playerTwoReverseURL: URL?
    var playerOneDuration: TimeInterval = 0
    var playerTwoDuration: TimeInterval = 0
    var history: [HistoryItem] = []
    var sharePayload: SharePayload?
    var permissionAlertMessage: String?
    var errorMessage: String?

    private let recorder = ReverseSingingAudioService()
    private var currentPlaybackToken: UUID?

    init(session: GameSession) {
        self.session = session
        loadHistory()
    }

    var phaseTitle: String {
        switch activeStep {
        case .playerOne:
            return "Player 1 records first"
        case .playerTwo:
            return canPlayResult ? "Result is ready" : "Pass the phone to Player 2"
        }
    }

    var activePlayerTitle: String {
        activeStep == .playerOne ? "Player 1" : "Player 2"
    }

    var playerTwoHelperText: String {
        if activeStep == .playerTwo {
            if isRecordingPlayerTwo {
                return "Recording mimic now… keep it short and clear."
            }
            return canPlayResult ? "Play, hear the result, or share." : "Listen and record the mimic."
        }
        return ""
    }

    var playerTwoHelperTextShort: String {
        if activeStep == .playerTwo {
            if isRecordingPlayerTwo {
                return "Recording mimic now…"
            }
            return canPlayResult ? "" : "Listen and record the mimic."
        }
        return ""
    }

    var playerTwoStatusText: String {
        activeStep == .playerTwo ? "Active" : "Waiting"
    }

    var playerTwoStatusTint: Color {
        activeStep == .playerTwo ? .green : .orange
    }

    var playerOneWaveform: [CGFloat] {
        waveformValues(for: playerOneURL, fallback: [0.24, 0.44, 0.34, 0.55, 0.42, 0.61, 0.36, 0.48, 0.28, 0.53])
    }

    var playerTwoWaveform: [CGFloat] {
        waveformValues(for: playerTwoURL, fallback: [0.22, 0.31, 0.26, 0.41, 0.32, 0.46, 0.29, 0.38, 0.27, 0.35])
    }

    var playerOneDurationText: String {
        formattedDuration(playerOneDuration)
    }

    var playerTwoDurationText: String {
        formattedDuration(playerTwoDuration)
    }

    var canRecordPlayerOne: Bool {
        !isRecordingPlayerTwo
    }

    var canPlayPlayerOne: Bool {
        playerOneURL != nil && !isRecordingPlayerOne && !isRecordingPlayerTwo
    }

    var canPlayPlayerOneReverse: Bool {
        playerOneReverseURL != nil && !isRecordingPlayerOne && !isRecordingPlayerTwo
    }

    var canRecordPlayerTwo: Bool {
        activeStep == .playerTwo && playerOneURL != nil && !isRecordingPlayerOne
    }

    var canPlayPlayerTwo: Bool {
        playerTwoURL != nil && !isRecordingPlayerOne && !isRecordingPlayerTwo
    }

    var canPlayResult: Bool {
        (playerTwoReverseURL != nil || (playerTwoURL != nil && playerOneReverseURL != nil)) && !isRecordingPlayerOne && !isRecordingPlayerTwo
    }

    var canSharePlayerTwoRaw: Bool {
        playerTwoURL != nil
    }

    var canShareResult: Bool {
        resultShareURL != nil
    }

    var canShareAnything: Bool {
        canSharePlayerTwoRaw || canShareResult
    }



    private var resultShareURL: URL? {
        playerTwoReverseURL ?? playerTwoURL ?? playerOneReverseURL
    }

    func prepareAudioSession() async {
        do {
            try await recorder.requestPermissionIfNeeded()
            try recorder.configureSession()
        } catch {
            permissionAlertMessage = error.localizedDescription
        }
    }

    func togglePlayerOneRecording() {
        if isRecordingPlayerOne {
            stopPlayerOneRecording()
        } else {
            startPlayerOneRecording()
        }
    }

    func togglePlayerTwoRecording() {
        if isRecordingPlayerTwo {
            stopPlayerTwoRecording()
        } else {
            startPlayerTwoRecording()
        }
    }

    func playPlayerOne() {
        guard let playerOneURL else { return }
        play(url: playerOneURL)
    }

    func playPlayerOneReverse() {
        guard let playerOneReverseURL else { return }
        play(url: playerOneReverseURL)
    }

    func playPlayerOneReverseSlow() {
        guard let playerOneReverseURL else { return }
        playSlow(url: playerOneReverseURL)
    }

    func playPlayerTwo() {
        guard let playerTwoURL else { return }
        play(url: playerTwoURL)
    }

    func playResult() {
        if let playerTwoReverseURL {
            play(url: playerTwoReverseURL)
        } else if let playerOneReverseURL {
            play(url: playerOneReverseURL)
        }
    }

    func prepareShare(kind: ShareKind) {
        switch kind {
        case .playerTwoRaw:
            guard let playerTwoURL else { return }
            sharePayload = SharePayload(id: UUID(), title: "Player 2 Raw", url: playerTwoURL)
        case .result:
            guard let resultShareURL else { return }
            sharePayload = SharePayload(id: UUID(), title: "Reverse Singing Result", url: resultShareURL)
        }
    }

    func handleHistoryAction(item: HistoryItem, action: HistoryAction) {
        switch action {
        case .mimic:
            if let url = item.playerTwoURL {
                play(url: url)
            }
        case .result:
            if let url = item.resultURL ?? item.playerTwoURL {
                play(url: url)
            }
        case .shareMimic:
            if let url = item.playerTwoURL {
                sharePayload = SharePayload(id: UUID(), title: "Mimic Recording", url: url)
            }
        case .shareResult:
            if let url = item.resultURL ?? item.playerTwoURL {
                sharePayload = SharePayload(id: UUID(), title: "Reverse Singing Result", url: url)
            }
        }
    }



    func cleanup() {
        stopRecordingTimer()
        recorder.stopPlayback()
        recorder.cancelRecording()
    }

    func handleBackgrounded() {
        if isRecordingPlayerOne {
            stopPlayerOneRecording()
        }
        if isRecordingPlayerTwo {
            stopPlayerTwoRecording()
        }
    }

    func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }
        switch type {
        case .began:
            let wasRecording = isRecordingPlayerOne || isRecordingPlayerTwo
            if isRecordingPlayerOne { stopPlayerOneRecording() }
            if isRecordingPlayerTwo { stopPlayerTwoRecording() }
            recorder.stopPlayback()
            if wasRecording {
                errorMessage = "Recording interrupted — tap Record to resume when ready."
            }
        case .ended:
            try? recorder.configureSession()
        @unknown default:
            break
        }
    }

    func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawReason = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }
        guard reason == .oldDeviceUnavailable else { return }
        if isRecordingPlayerOne { stopPlayerOneRecording() }
        if isRecordingPlayerTwo { stopPlayerTwoRecording() }
    }

    var isRecording: Bool {
        isRecordingPlayerOne || isRecordingPlayerTwo
    }

    var recordingTimeText: String {
        "\(recordingElapsed)s / \(maxRecordingSeconds)s"
    }

    private func startRecordingTimer(onLimit: @escaping () -> Void) {
        stopRecordingTimer()
        recordingElapsed = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordingElapsed += 1
                if self.recordingElapsed >= self.maxRecordingSeconds {
                    onLimit()
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingElapsed = 0
    }

    private func playRecordStartSound() {
        AudioServicesPlaySystemSound(1113)
    }

    private func playRecordStopSound() {
        AudioServicesPlaySystemSound(1114)
    }

    private func startPlayerOneRecording() {
        recorder.stopPlayback()
        if let playerTwoURL { try? FileManager.default.removeItem(at: playerTwoURL) }
        if let playerTwoReverseURL { try? FileManager.default.removeItem(at: playerTwoReverseURL) }
        playerTwoURL = nil
        playerTwoReverseURL = nil
        playerTwoDuration = 0
        activeStep = .playerOne
        let url = ReverseSingingFileStore.playerOneRecordingURL(sessionID: session.id)
        recordingElapsed = 0
        errorMessage = nil
        do {
            try recorder.startRecording(to: url)
            isRecordingPlayerOne = true
            startRecordingTimer { [weak self] in
                self?.stopPlayerOneRecording()
            }
        } catch {
            isRecordingPlayerOne = false
            errorMessage = error.localizedDescription
        }
    }

    private func stopPlayerOneRecording() {
        stopRecordingTimer()
        do {
            let url = try recorder.stopRecording()
            isRecordingPlayerOne = false
            playerOneURL = url
            playerOneDuration = recorder.duration(for: url)
            playerOneReverseURL = try recorder.createReversedCopy(from: url, sessionID: session.id)
            activeStep = .playerTwo
        } catch {
            isRecordingPlayerOne = false
            errorMessage = error.localizedDescription
        }
    }

    private func startPlayerTwoRecording() {
        recorder.stopPlayback()
        let url = ReverseSingingFileStore.playerTwoRecordingURL(sessionID: session.id)
        recordingElapsed = 0
        errorMessage = nil
        do {
            try recorder.startRecording(to: url)
            isRecordingPlayerTwo = true
            startRecordingTimer { [weak self] in
                self?.stopPlayerTwoRecording()
            }
        } catch {
            isRecordingPlayerTwo = false
            errorMessage = error.localizedDescription
        }
    }

    private func stopPlayerTwoRecording() {
        stopRecordingTimer()
        do {
            let url = try recorder.stopRecording()
            isRecordingPlayerTwo = false
            playerTwoURL = url
            playerTwoDuration = recorder.duration(for: url)
            playerTwoReverseURL = try recorder.createReversedPlayerTwoCopy(from: url, sessionID: session.id)
            appendToHistory()
        } catch {
            isRecordingPlayerTwo = false
            errorMessage = error.localizedDescription
        }
    }

    private func appendToHistory() {
        guard let playerOneURL, let playerTwoURL else { return }
        let p1Name = playerOneURL.lastPathComponent
        let p2Name = playerTwoURL.lastPathComponent
        if history.contains(where: { $0.playerOneFileName == p1Name && $0.playerTwoFileName == p2Name }) {
            return
        }
        let historyP1URL = ReverseSingingFileStore.historyURL(original: playerOneURL)
        let historyP1RevURL = playerOneReverseURL.map { ReverseSingingFileStore.historyURL(original: $0) }
        let historyP2URL = ReverseSingingFileStore.historyURL(original: playerTwoURL)
        let historyResultURL = playerTwoReverseURL.map { ReverseSingingFileStore.historyURL(original: $0) }
        try? FileManager.default.copyItem(at: playerOneURL, to: historyP1URL)
        if let src = playerOneReverseURL, let dst = historyP1RevURL { try? FileManager.default.copyItem(at: src, to: dst) }
        try? FileManager.default.copyItem(at: playerTwoURL, to: historyP2URL)
        if let src = playerTwoReverseURL, let dst = historyResultURL { try? FileManager.default.copyItem(at: src, to: dst) }
        let item = HistoryItem(
            id: UUID(),
            date: Date(),
            playerOneFileName: historyP1URL.lastPathComponent,
            playerOneReverseFileName: historyP1RevURL?.lastPathComponent,
            playerTwoFileName: historyP2URL.lastPathComponent,
            resultFileName: historyResultURL?.lastPathComponent,
            playerOneDuration: playerOneDuration,
            playerTwoDuration: playerTwoDuration
        )
        history.insert(item, at: 0)
        if history.count > 20 {
            let removed = history.suffix(from: 20)
            for item in removed {
                try? FileManager.default.removeItem(at: item.playerOneURL)
                if let url = item.playerOneReverseURL { try? FileManager.default.removeItem(at: url) }
                if let url = item.playerTwoURL { try? FileManager.default.removeItem(at: url) }
                if let url = item.resultURL { try? FileManager.default.removeItem(at: url) }
            }
            history = Array(history.prefix(20))
        }
        saveHistory()
    }

    private static let historyKey = "reverse_singing_history"

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
              let items = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        let valid = items.filter { FileManager.default.fileExists(atPath: $0.playerOneURL.path()) }
        history = Array(valid.prefix(20))
    }

    private func play(url: URL) {
        do {
            recorder.stopPlayback()
            try recorder.play(url: url)
            currentPlaybackToken = UUID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func playSlow(url: URL) {
        do {
            recorder.stopPlayback()
            try recorder.play(url: url, rate: 0.5)
            currentPlaybackToken = UUID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func waveformValues(for url: URL?, fallback: [CGFloat]) -> [CGFloat] {
        guard let url else { return fallback }
        let duration = max(1, recorder.duration(for: url))
        let base = stride(from: 0, to: 10, by: 1).map { index in
            let seed = sin((Double(index) + duration) * 1.7)
            return CGFloat(max(0.18, min(0.95, abs(seed) * 0.72 + 0.18)))
        }
        return base
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0.0s" }
        return String(format: "%.1fs", duration)
    }
}

@MainActor
final class ReverseSingingAudioService: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private let session = AVAudioSession.sharedInstance()

    func requestPermissionIfNeeded() async throws {
        switch session.recordPermission {
        case .granted:
            return
        case .denied:
            throw ReverseSingingAudioError.microphoneDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            guard granted else { throw ReverseSingingAudioError.microphoneDenied }
        @unknown default:
            throw ReverseSingingAudioError.microphoneDenied
        }
    }

    func configureSession() throws {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    func startRecording(to url: URL) throws {
        try configureSession()
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        guard audioRecorder?.record() == true else {
            throw ReverseSingingAudioError.recordingFailed
        }
    }

    func stopRecording() throws -> URL {
        guard let audioRecorder else {
            throw ReverseSingingAudioError.missingRecording
        }
        let url = audioRecorder.url
        audioRecorder.stop()
        self.audioRecorder = nil
        return url
    }

    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
    }

    func play(url: URL, rate: Float = 1.0) throws {
        try configureSession()
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.volume = 1.0
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
        audioPlayer?.prepareToPlay()
        try session.overrideOutputAudioPort(.speaker)
        guard audioPlayer?.play() == true else {
            throw ReverseSingingAudioError.playbackFailed
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func duration(for url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration).isFinite ? CMTimeGetSeconds(asset.duration) : 0
    }

    func createReversedCopy(from sourceURL: URL, sessionID: UUID) throws -> URL {
        let outputURL = ReverseSingingFileStore.playerOneReverseURL(sessionID: sessionID)
        return try reverseAudio(from: sourceURL, to: outputURL)
    }

    func createReversedPlayerTwoCopy(from sourceURL: URL, sessionID: UUID) throws -> URL {
        let outputURL = ReverseSingingFileStore.playerTwoReverseURL(sessionID: sessionID)
        return try reverseAudio(from: sourceURL, to: outputURL)
    }

    private func reverseAudio(from sourceURL: URL, to outputURL: URL) throws -> URL {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        try? FileManager.default.removeItem(at: outputURL)

        let format = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(sourceFile.length)
        guard frameCount > 0 else {
            throw ReverseSingingAudioError.processingFailed
        }
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ReverseSingingAudioError.processingFailed
        }
        try sourceFile.read(into: sourceBuffer)

        guard let reversedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ReverseSingingAudioError.processingFailed
        }
        reversedBuffer.frameLength = sourceBuffer.frameLength

        let channelCount = Int(format.channelCount)
        let sampleCount = Int(sourceBuffer.frameLength)

        if let sourceChannels = sourceBuffer.floatChannelData, let targetChannels = reversedBuffer.floatChannelData {
            for channel in 0..<channelCount {
                for sample in 0..<sampleCount {
                    targetChannels[channel][sample] = sourceChannels[channel][sampleCount - sample - 1]
                }
            }
        } else if let sourceChannels = sourceBuffer.int16ChannelData, let targetChannels = reversedBuffer.int16ChannelData {
            for channel in 0..<channelCount {
                for sample in 0..<sampleCount {
                    targetChannels[channel][sample] = sourceChannels[channel][sampleCount - sample - 1]
                }
            }
        } else if let sourceChannels = sourceBuffer.int32ChannelData, let targetChannels = reversedBuffer.int32ChannelData {
            for channel in 0..<channelCount {
                for sample in 0..<sampleCount {
                    targetChannels[channel][sample] = sourceChannels[channel][sampleCount - sample - 1]
                }
            }
        } else {
            throw ReverseSingingAudioError.processingFailed
        }

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try outputFile.write(from: reversedBuffer)
        return outputURL
    }


    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {}
}

nonisolated enum ReverseSingingAudioError: LocalizedError, Sendable {
    case microphoneDenied
    case recordingFailed
    case missingRecording
    case playbackFailed
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Please allow microphone access to play Reverse Singing."
        case .recordingFailed:
            return "Could not start recording."
        case .missingRecording:
            return "No recording is available yet."
        case .playbackFailed:
            return "Could not play this audio clip."
        case .processingFailed:
            return "Could not create the reversed audio."
        }
    }
}

nonisolated enum ReverseSingingFileStore {
    static func playerOneRecordingURL(sessionID: UUID) -> URL {
        URL.cachesDirectory.appending(path: "reverse-singing-\(sessionID.uuidString)-player1.m4a")
    }

    static func playerOneReverseURL(sessionID: UUID) -> URL {
        URL.cachesDirectory.appending(path: "reverse-singing-\(sessionID.uuidString)-player1-reverse.caf")
    }

    static func playerTwoRecordingURL(sessionID: UUID) -> URL {
        URL.cachesDirectory.appending(path: "reverse-singing-\(sessionID.uuidString)-player2.m4a")
    }

    static func playerTwoReverseURL(sessionID: UUID) -> URL {
        URL.cachesDirectory.appending(path: "reverse-singing-\(sessionID.uuidString)-player2-reverse.caf")
    }

    static func historyURL(original: URL) -> URL {
        let name = "history-\(UUID().uuidString)-\(original.lastPathComponent)"
        return URL.cachesDirectory.appending(path: name)
    }
}

private struct ReverseSingingPassCard: View {
    nonisolated enum Layout: Hashable, Sendable {
        case playerOne(record: ReverseSingingPassButton, play: ReverseSingingPassButton, reverse: ReverseSingingPassButton, slow: ReverseSingingPassButton)
        case playerTwo(record: ReverseSingingPassButton, play: ReverseSingingPassButton, result: ReverseSingingPassButton, share: ReverseSingingPassButton)
    }

    let title: String
    let subtitle: String
    let helperText: String
    let statusText: String?
    let statusTint: Color
    let isActive: Bool
    let waveform: [CGFloat]
    let durationText: String
    let layout: Layout


    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            waveformSection
            controls
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(isActive ? .green.opacity(0.5) : .white.opacity(0.05), lineWidth: isActive ? 1.3 : 1)
        }
        .opacity(isActive ? 1 : 0.76)
        .shadow(color: .black.opacity(isActive ? 0.18 : 0.08), radius: isActive ? 20 : 12, y: 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)

                        if let statusText {
                            Text(statusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(statusTint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusTint.opacity(0.14), in: .capsule)
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if !helperText.isEmpty {
                Text(helperText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isActive ? .green : .secondary)
            }
        }
    }

    private var waveformSection: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(waveform.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(.white.opacity(0.88))
                        .frame(width: 2.5, height: max(5, value * 16))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(durationText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.045), in: .rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var controls: some View {
        switch layout {
        case let .playerOne(record, play, reverse, slow):
            HStack(spacing: 10) {
                ReverseSingingSquareButton(config: record)
                ReverseSingingSmallCircleButton(config: play)
            }
            HStack(spacing: 10) {
                ReverseSingingSquareButton(config: reverse)
                ReverseSingingSmallCircleButton(config: slow)
            }

        case let .playerTwo(record, play, result, share):
            HStack(spacing: 10) {
                ReverseSingingSquareButton(config: record)
                ReverseSingingSmallCircleButton(config: play)
            }
            HStack(spacing: 10) {
                ReverseSingingSquareButton(config: result)
                ReverseSingingSmallCircleButton(config: share)
            }
        }
    }
}

private struct ReverseSingingPassButton: Hashable {
    enum Style: Hashable {
        case record
        case reverse
        case result
        case neutral
        case circle
    }

    let title: String
    let systemImage: String
    let style: Style
    let isEnabled: Bool
    var isRecording: Bool = false
    let action: () -> Void

    static func == (lhs: ReverseSingingPassButton, rhs: ReverseSingingPassButton) -> Bool {
        lhs.title == rhs.title && lhs.systemImage == rhs.systemImage && lhs.style == rhs.style && lhs.isEnabled == rhs.isEnabled && lhs.isRecording == rhs.isRecording
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(systemImage)
        hasher.combine(style)
        hasher.combine(isEnabled)
        hasher.combine(isRecording)
    }
}

private struct ReverseSingingSquareButton: View {
    let config: ReverseSingingPassButton

    var body: some View {
        Button(action: config.action) {
            VStack(spacing: 6) {
                Image(systemName: config.systemImage)
                    .font(.title2.weight(.bold))
                    .symbolEffect(.pulse, isActive: config.isRecording)
                Text(config.title)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(config.isRecording ? AnyShapeStyle(.red) : buttonColor, in: .rect(cornerRadius: 18))
            .animation(.easeInOut(duration: 0.3), value: config.isRecording)
        }
        .buttonStyle(.plain)
        .disabled(!config.isEnabled)
        .opacity(config.isEnabled ? 1 : 0.32)
    }

    private var buttonColor: AnyShapeStyle {
        switch config.style {
        case .record:
            AnyShapeStyle(Color(red: 1.0, green: 0.39, blue: 0.52))
        case .reverse:
            AnyShapeStyle(Color(red: 0.1, green: 0.48, blue: 0.96))
        case .result:
            AnyShapeStyle(Color(red: 0.15, green: 0.79, blue: 0.38))
        case .neutral, .circle:
            AnyShapeStyle(.white.opacity(0.12))
        }
    }
}

private struct ReverseSingingSmallCircleButton: View {
    let config: ReverseSingingPassButton

    var body: some View {
        Button(action: config.action) {
            Image(systemName: config.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.12), in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .disabled(!config.isEnabled)
        .opacity(config.isEnabled ? 1 : 0.32)
    }
}

private struct ReverseSingingTallGameButton: View {
    let config: ReverseSingingPassButton

    var body: some View {
        Button(action: config.action) {
            Label(config.title, systemImage: config.systemImage)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .foregroundStyle(.white)
                .background(backgroundStyle, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!config.isEnabled)
        .opacity(config.isEnabled ? 1 : 0.32)
    }

    private var backgroundStyle: some ShapeStyle {
        switch config.style {
        case .reverse:
            return AnyShapeStyle(Color(red: 0.1, green: 0.48, blue: 0.96))
        case .result:
            return AnyShapeStyle(Color(red: 0.15, green: 0.79, blue: 0.38))
        default:
            return AnyShapeStyle(.white.opacity(0.09))
        }
    }
}

private struct ReverseSingingGameButton: View {
    let config: ReverseSingingPassButton

    var body: some View {
        Button(action: config.action) {
            Label(config.title, systemImage: config.systemImage)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(backgroundStyle, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!config.isEnabled)
        .opacity(config.isEnabled ? 1 : 0.32)
    }

    private var backgroundStyle: some ShapeStyle {
        switch config.style {
        case .record:
            return AnyShapeStyle(Color(red: 1.0, green: 0.39, blue: 0.52))
        case .reverse:
            return AnyShapeStyle(Color(red: 0.1, green: 0.48, blue: 0.96))
        case .result:
            return AnyShapeStyle(Color(red: 0.15, green: 0.79, blue: 0.38))
        case .neutral:
            return AnyShapeStyle(.white.opacity(0.08))
        case .circle:
            return AnyShapeStyle(.white.opacity(0.09))
        }
    }
}

private struct ReverseSingingCircleButton: View {
    let config: ReverseSingingPassButton

    var body: some View {
        Button(action: config.action) {
            Image(systemName: config.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(config.style == .neutral ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1), in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.06))
                }
        }
        .buttonStyle(.plain)
        .disabled(!config.isEnabled)
        .opacity(config.isEnabled ? 1 : 0.32)
    }
}

private struct ReverseSingingHistoryRow: View {
    let item: ReverseSingingSessionViewModel.HistoryItem
    let onAction: (ReverseSingingSessionViewModel.HistoryItem, ReverseSingingSessionViewModel.HistoryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reverse Singing")
                        .font(.subheadline.weight(.semibold))
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                StatusPillView(title: formattedTime(item.date), systemImage: "clock.fill", tint: .purple)
            }

            HStack(spacing: 10) {
                historyButton(title: "Mimic", systemImage: "mic.fill", tint: .pink, enabled: item.playerTwoURL != nil) {
                    onAction(item, .mimic)
                }
                historyButton(title: "Result", systemImage: "sparkles", tint: .blue, enabled: item.resultURL != nil) {
                    onAction(item, .result)
                }
                shareMenu
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [.purple.opacity(0.22), .blue.opacity(0.12), .pink.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06))
        }
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var shareMenu: some View {
        Menu {
            if item.playerTwoURL != nil {
                Button {
                    onAction(item, .shareMimic)
                } label: {
                    Label("Share Mimic", systemImage: "mic.fill")
                }
            }
            if item.resultURL != nil {
                Button {
                    onAction(item, .shareResult)
                } label: {
                    Label("Share Result", systemImage: "sparkles")
                }
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.18), in: .rect(cornerRadius: 12))
        }
        .foregroundStyle(.white)
    }

    private func historyButton(title: String, systemImage: String, tint: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint.opacity(0.18), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

private struct ReverseSingingHistorySheet: View {
    let viewModel: ReverseSingingSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.history.isEmpty {
                        ContentUnavailableView("No History Yet", systemImage: "clock.arrow.circlepath", description: Text("Only the latest 20 sessions are stored."))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else {
                        ForEach(viewModel.history) { item in
                            ReverseSingingHistoryRow(item: item, onAction: viewModel.handleHistoryAction)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ReverseSingingShareSheet: UIViewControllerRepresentable {
    let payload: ReverseSingingSessionViewModel.SharePayload

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [payload.url], applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
