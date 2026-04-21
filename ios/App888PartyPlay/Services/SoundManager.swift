import AVFoundation
import SwiftUI

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var isSoundEnabled: Bool = true
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var mixer: AVAudioMixerNode { engine.mainMixerNode }
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44100
    private var isEngineStarted: Bool = false
    private var nextPlayerIndex: Int = 0
    private let playerPoolSize: Int = 8

    private init() {
        prepareAll()
        configureAudioSession()
        setupEngine()
        precacheBuffers()
    }

    func updateSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func prepareAll() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactRigid.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    private func setupEngine() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        for _ in 0..<playerPoolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            players.append(player)
        }
        do {
            try engine.start()
            isEngineStarted = true
            for p in players { p.play() }
        } catch {
            isEngineStarted = false
        }
    }

    private func precacheBuffers() {
        buffers["tileFlip"] = makeTone(freq: 960, duration: 0.05, volume: 0.22, waveform: .sine, attack: 0.002, release: 0.045)
        buffers["match"] = makeChord(freqs: [523.25, 659.25, 783.99, 1046.5], duration: 0.4, volume: 0.28, waveform: .sine)
        buffers["mismatch"] = makeTone(freq: 200, duration: 0.2, volume: 0.2, waveform: .sine, attack: 0.005, release: 0.18)
        buffers["buttonTap"] = makeTone(freq: 1400, duration: 0.035, volume: 0.14, waveform: .sine, attack: 0.001, release: 0.03)
        buffers["navigation"] = makeSweep(fromFreq: 700, toFreq: 1100, duration: 0.1, volume: 0.18, waveform: .sine)
        buffers["gameStart"] = makeArpeggio(freqs: [523.25, 659.25, 783.99, 1046.5, 1318.5], noteDuration: 0.07, volume: 0.3, waveform: .sine)
        buffers["roundStart"] = makeArpeggio(freqs: [659.25, 880, 1174.66], noteDuration: 0.08, volume: 0.28, waveform: .sine)
        buffers["roundEnd"] = makeArpeggio(freqs: [1174.66, 880, 659.25], noteDuration: 0.09, volume: 0.26, waveform: .sine)
        buffers["correct"] = makeArpeggio(freqs: [659.25, 987.77, 1318.5], noteDuration: 0.075, volume: 0.28, waveform: .sine)
        buffers["wrong"] = makeSweep(fromFreq: 520, toFreq: 160, duration: 0.3, volume: 0.24, waveform: .triangle)
        buffers["victory"] = makeArpeggio(freqs: [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98], noteDuration: 0.085, volume: 0.34, waveform: .sine)
        buffers["defeat"] = makeArpeggio(freqs: [523.25, 440, 349.23, 261.63], noteDuration: 0.13, volume: 0.28, waveform: .triangle)
        buffers["vote"] = makeTone(freq: 1100, duration: 0.05, volume: 0.17, waveform: .sine, attack: 0.001, release: 0.045)
        buffers["reveal"] = makeSweep(fromFreq: 330, toFreq: 1320, duration: 0.5, volume: 0.3, waveform: .sine)
        buffers["timerTick"] = makeTone(freq: 1600, duration: 0.022, volume: 0.08, waveform: .sine, attack: 0.001, release: 0.02)
        buffers["timerUrgent"] = makeTone(freq: 2000, duration: 0.07, volume: 0.22, waveform: .triangle, attack: 0.001, release: 0.065)
        buffers["countdown"] = makeTone(freq: 988, duration: 0.11, volume: 0.26, waveform: .sine, attack: 0.002, release: 0.095)
        buffers["passDevice"] = makeSweep(fromFreq: 440, toFreq: 880, duration: 0.22, volume: 0.22, waveform: .sine)
        buffers["starEarned"] = makeArpeggio(freqs: [1318.5, 1760, 2093], noteDuration: 0.06, volume: 0.28, waveform: .sine)
        buffers["bottleSpin"] = makeSweep(fromFreq: 1600, toFreq: 160, duration: 8.0, volume: 0.2, waveform: .triangle)
        buffers["bottleLand"] = makeArpeggio(freqs: [2093, 1567.98, 1046.5], noteDuration: 0.07, volume: 0.32, waveform: .sine)
        buffers["playerPicked"] = makeChord(freqs: [523.25, 659.25, 783.99, 1046.5], duration: 0.5, volume: 0.3, waveform: .sine)
        buffers["tabSwitch"] = makeTone(freq: 1320, duration: 0.04, volume: 0.14, waveform: .sine, attack: 0.001, release: 0.035)
        buffers["diceRoll"] = makeDiceRoll(duration: 1.0, volume: 0.22)
    }

    private enum Waveform { case sine, triangle, square, sawtooth }

    private func sample(waveform: Waveform, phase: Double) -> Float {
        let t = phase - floor(phase)
        switch waveform {
        case .sine:
            return Float(sin(2.0 * .pi * t))
        case .triangle:
            let shifted: Double = t - floor(t + 0.5)
            let tri: Double = 2.0 * abs(2.0 * shifted) - 1.0
            return Float(tri)
        case .square:
            return t < 0.5 ? 1.0 : -1.0
        case .sawtooth:
            return Float(2.0 * t - 1.0)
        }
    }

    private func envelope(i: Int, total: Int, attackFrac: Double, releaseFrac: Double) -> Float {
        let p = Double(i) / Double(max(total, 1))
        if p < attackFrac {
            return Float(p / attackFrac)
        } else if p > 1.0 - releaseFrac {
            return Float((1.0 - p) / releaseFrac)
        }
        return 1.0
    }

    private func makeBuffer(frameCount: Int) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        return buffer
    }

    private func makeTone(freq: Double, duration: Double, volume: Float, waveform: Waveform, attack: Double = 0.01, release: Double = 0.1) -> AVAudioPCMBuffer? {
        let frames = Int(sampleRate * duration)
        guard let buf = makeBuffer(frameCount: frames), let ch = buf.floatChannelData?[0] else { return nil }
        let attackFrac = min(0.5, attack / duration)
        let releaseFrac = min(0.95 - attackFrac, release / duration)
        var phase: Double = 0
        let phaseInc = freq / sampleRate
        for i in 0..<frames {
            let env = envelope(i: i, total: frames, attackFrac: attackFrac, releaseFrac: releaseFrac)
            ch[i] = sample(waveform: waveform, phase: phase) * volume * env
            phase += phaseInc
        }
        return buf
    }

    private func makeChord(freqs: [Double], duration: Double, volume: Float, waveform: Waveform) -> AVAudioPCMBuffer? {
        let frames = Int(sampleRate * duration)
        guard let buf = makeBuffer(frameCount: frames), let ch = buf.floatChannelData?[0] else { return nil }
        var phases = [Double](repeating: 0, count: freqs.count)
        let incs = freqs.map { $0 / sampleRate }
        let perVoice = volume / Float(freqs.count)
        for i in 0..<frames {
            let env = envelope(i: i, total: frames, attackFrac: 0.02, releaseFrac: 0.5)
            var s: Float = 0
            for v in 0..<freqs.count {
                s += sample(waveform: waveform, phase: phases[v]) * perVoice
                phases[v] += incs[v]
            }
            ch[i] = s * env
        }
        return buf
    }

    private func makeSweep(fromFreq: Double, toFreq: Double, duration: Double, volume: Float, waveform: Waveform) -> AVAudioPCMBuffer? {
        let frames = Int(sampleRate * duration)
        guard let buf = makeBuffer(frameCount: frames), let ch = buf.floatChannelData?[0] else { return nil }
        var phase: Double = 0
        for i in 0..<frames {
            let t = Double(i) / Double(frames)
            let freq = fromFreq + (toFreq - fromFreq) * t
            phase += freq / sampleRate
            let env = envelope(i: i, total: frames, attackFrac: 0.02, releaseFrac: 0.3)
            ch[i] = sample(waveform: waveform, phase: phase) * volume * env
        }
        return buf
    }

    private func makeDiceRoll(duration: Double, volume: Float) -> AVAudioPCMBuffer? {
        let frames = Int(sampleRate * duration)
        guard let buf = makeBuffer(frameCount: frames), let ch = buf.floatChannelData?[0] else { return nil }
        var clickTimes: [Int] = []
        var t: Double = 0
        while t < duration {
            clickTimes.append(Int(t * sampleRate))
            let gap = Double.random(in: 0.04...0.11) * (1.0 + t / duration * 1.5)
            t += gap
        }
        for i in 0..<frames {
            let p = Double(i) / Double(frames)
            let env: Float = p < 0.85 ? 1.0 : Float((1.0 - p) / 0.15)
            var s: Float = (Float.random(in: -1...1)) * 0.12 * env
            for clickStart in clickTimes {
                let rel = i - clickStart
                if rel >= 0 && rel < 400 {
                    let clickEnv = Float(exp(-Double(rel) / 60.0))
                    let phase = Double(rel) / sampleRate * Double.random(in: 900...1400)
                    s += Float(sin(2.0 * .pi * phase)) * clickEnv * 0.5 * env
                }
            }
            ch[i] = s * volume
        }
        return buf
    }

    private func makeArpeggio(freqs: [Double], noteDuration: Double, volume: Float, waveform: Waveform) -> AVAudioPCMBuffer? {
        let framesPerNote = Int(sampleRate * noteDuration)
        let frames = framesPerNote * freqs.count
        guard let buf = makeBuffer(frameCount: frames), let ch = buf.floatChannelData?[0] else { return nil }
        for (noteIdx, freq) in freqs.enumerated() {
            var phase: Double = 0
            let inc = freq / sampleRate
            let offset = noteIdx * framesPerNote
            for i in 0..<framesPerNote {
                let env = envelope(i: i, total: framesPerNote, attackFrac: 0.05, releaseFrac: 0.5)
                ch[offset + i] = sample(waveform: waveform, phase: phase) * volume * env
                phase += inc
            }
        }
        return buf
    }

    private func play(_ key: String) {
        guard isSoundEnabled, isEngineStarted, let buffer = buffers[key], !players.isEmpty else { return }
        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        player.stop()
        player.play()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    func playGameStart() {
        play("gameStart")
        impactHeavy.impactOccurred(intensity: 1.0)
        impactHeavy.prepare()
    }

    func playRoundStart() {
        play("roundStart")
        impactMedium.impactOccurred(intensity: 0.8)
        impactMedium.prepare()
    }

    func playRoundEnd() {
        play("roundEnd")
        impactMedium.impactOccurred(intensity: 0.6)
        impactMedium.prepare()
    }

    func playCorrect() {
        play("correct")
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    func playWrong() {
        play("wrong")
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    func playTileFlip() {
        play("tileFlip")
        impactLight.impactOccurred(intensity: 0.5)
        impactLight.prepare()
    }

    func playMatch() {
        play("match")
        impactMedium.impactOccurred(intensity: 0.7)
        impactMedium.prepare()
    }

    func playMismatch() {
        play("mismatch")
        impactLight.impactOccurred(intensity: 0.3)
        impactLight.prepare()
    }

    func playVote() {
        play("vote")
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func playReveal() {
        play("reveal")
        impactRigid.impactOccurred(intensity: 0.9)
        impactRigid.prepare()
    }

    func playVictory() {
        play("victory")
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    func playDefeat() {
        play("defeat")
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    func playTimerTick() {
        play("timerTick")
        impactLight.impactOccurred(intensity: 0.3)
        impactLight.prepare()
    }

    func playTimerUrgent() {
        play("timerUrgent")
        impactRigid.impactOccurred(intensity: 0.8)
        impactRigid.prepare()
    }

    func playButtonTap() {
        play("buttonTap")
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func playNavigation() {
        play("navigation")
        impactLight.impactOccurred(intensity: 0.4)
        impactLight.prepare()
    }

    func playStarEarned() {
        play("starEarned")
        impactMedium.impactOccurred(intensity: 0.7)
        impactMedium.prepare()
    }

    func playCountdown() {
        play("countdown")
        impactRigid.impactOccurred(intensity: 0.6)
        impactRigid.prepare()
    }

    func playPassDevice() {
        play("passDevice")
        impactMedium.impactOccurred(intensity: 0.5)
        impactMedium.prepare()
    }

    func playBottleSpin() {
        play("bottleSpin")
    }

    func playBottleLand() {
        play("bottleLand")
        impactHeavy.impactOccurred(intensity: 1.0)
        impactHeavy.prepare()
    }

    func playPlayerPicked() {
        play("playerPicked")
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    func playTabSwitch() {
        play("tabSwitch")
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func playDiceRoll() {
        play("diceRoll")
    }
}
