import Foundation
import Observation

@Observable
@MainActor
final class TapInOrderViewModel {
    enum Phase: Hashable { case preview, playing, complete }

    var variant: TapInOrderVariant = .numberMemory
    var gridSize: Int = 4
    var tileCount: Int = 6
    var selectedCells: [Int] = []
    var numberForCell: [Int: Int] = [:]
    var tappedCells: Set<Int> = []
    var nextExpected: Int = 1
    var correctCount: Int = 0
    var missTaps: Int = 0
    var elapsedSeconds: Double = 0
    var previewRemaining: Double = 0
    var previewTotal: Double = 5.0
    var phase: Phase = .preview
    var wrongTileFlash: Int? = nil
    var didWin: Bool = false

    private var timerTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?

    var totalTargets: Int { selectedCells.count }

    var isActive: Bool { phase == .playing }
    var isComplete: Bool { phase == .complete }

    var progress: Double {
        guard totalTargets > 0 else { return 0 }
        return Double(correctCount) / Double(totalTargets)
    }

    var formattedTime: String {
        let seconds = Int(elapsedSeconds)
        let tenths = Int((elapsedSeconds * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d.%d", seconds, tenths)
    }

    func start(variant: TapInOrderVariant, gridSize: Int, tileCount: Int, seed: UInt64, providedCells: [Int]? = nil) {
        self.variant = variant
        self.gridSize = gridSize
        self.tileCount = tileCount
        let cells = providedCells ?? TapInOrderGenerator.generateSelectedCells(variant: variant, gridSize: gridSize, tileCount: tileCount, seed: seed)
        self.selectedCells = cells

        var mapping: [Int: Int] = [:]
        if variant == .numberMemory {
            for (i, cell) in cells.enumerated() {
                mapping[cell] = i + 1
            }
        }
        self.numberForCell = mapping

        self.tappedCells = []
        self.nextExpected = 1
        self.correctCount = 0
        self.missTaps = 0
        self.elapsedSeconds = 0
        self.wrongTileFlash = nil
        self.didWin = false
        self.previewTotal = TapInOrderBoard.previewDuration(tileCount: cells.count)
        self.previewRemaining = self.previewTotal
        self.phase = .preview
        startPreview()
    }

    func tap(cellIndex: Int) {
        guard phase == .playing else { return }
        guard !tappedCells.contains(cellIndex) else { return }

        switch variant {
        case .numberMemory:
            if let number = numberForCell[cellIndex], number == nextExpected {
                tappedCells.insert(cellIndex)
                nextExpected += 1
                correctCount += 1
                FeedbackService.shared.playClick()
                if correctCount >= totalTargets {
                    didWin = true
                    complete()
                }
            } else {
                missTaps += 1
                flashWrong(cellIndex)
            }
        case .patternMemory:
            if selectedCells.contains(cellIndex) {
                tappedCells.insert(cellIndex)
                correctCount += 1
                FeedbackService.shared.playClick()
                if correctCount >= totalTargets {
                    didWin = true
                    complete()
                }
            } else {
                tappedCells.insert(cellIndex)
                missTaps += 1
                flashWrong(cellIndex)
            }
        }
    }

    private func flashWrong(_ cellIndex: Int) {
        wrongTileFlash = cellIndex
        FeedbackService.shared.playError()
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if wrongTileFlash == cellIndex { wrongTileFlash = nil }
        }
    }

    func giveUp() {
        guard phase == .playing || phase == .preview else { return }
        didWin = false
        complete()
    }

    func cleanup() {
        stopTimer()
        previewTask?.cancel()
        previewTask = nil
    }

    func reset() {
        cleanup()
        selectedCells = []
        numberForCell = [:]
        tappedCells = []
        nextExpected = 1
        correctCount = 0
        missTaps = 0
        elapsedSeconds = 0
        previewRemaining = 0
        phase = .preview
        wrongTileFlash = nil
        didWin = false
    }

    private func complete() {
        phase = .complete
        stopTimer()
    }

    private func startPreview() {
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            let step: Double = 0.1
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.phase == .preview else { return }
                    self.previewRemaining = max(0, self.previewRemaining - step)
                    if self.previewRemaining <= 0 {
                        self.beginPlayPhase()
                    }
                }
            }
        }
    }

    private func beginPlayPhase() {
        phase = .playing
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.phase == .playing else { return }
                    self.elapsedSeconds += 0.1
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
