import SwiftUI
import AVFoundation

@MainActor
final class FeedbackService {
    static let shared = FeedbackService()

    private var isSoundEnabled: Bool = true
    private var isVibrationEnabled: Bool = true
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func updateSettings(sound: Bool, vibration: Bool) {
        isSoundEnabled = sound
        isVibrationEnabled = vibration
        SoundManager.shared.updateSoundEnabled(sound)
    }

    func playSuccess() {
        triggerHaptic(.success)
        if isSoundEnabled { SoundManager.shared.playCorrect() }
    }

    func playError() {
        triggerHaptic(.error)
        if isSoundEnabled { SoundManager.shared.playWrong() }
    }

    func playWarning() {
        triggerHaptic(.warning)
        if isSoundEnabled { SoundManager.shared.playMismatch() }
    }

    func playTap() {
        triggerHaptic(.selection)
    }

    func playRoundStart() {
        triggerHaptic(.heavy)
        if isSoundEnabled { SoundManager.shared.playRoundStart() }
    }

    func playRoundEnd() {
        triggerHaptic(.medium)
        if isSoundEnabled { SoundManager.shared.playRoundEnd() }
    }

    func playTimerTick() {
        triggerHaptic(.light)
    }

    func playExplosion() {
        triggerHaptic(.rigid)
        if isSoundEnabled { SoundManager.shared.playDefeat() }
    }

    func playClick() {
        triggerHaptic(.selection)
        if isSoundEnabled { SoundManager.shared.playButtonTap() }
    }

    func playGameEnd() {
        triggerHaptic(.heavy)
        if isSoundEnabled { SoundManager.shared.playVictory() }
    }

    func playResultReveal() {
        triggerHaptic(.rigid)
        if isSoundEnabled { SoundManager.shared.playReveal() }
    }

    func playCountdownTick() {
        triggerHaptic(.light)
        if isSoundEnabled { SoundManager.shared.playCountdown() }
    }

    func playTimerStart() {
        triggerHaptic(.medium)
        if isSoundEnabled { SoundManager.shared.playRoundStart() }
    }

    func playTimerStop() {
        triggerHaptic(.medium)
        if isSoundEnabled { SoundManager.shared.playRoundEnd() }
    }

    func playPhaseTransition() {
        triggerHaptic(.medium)
        if isSoundEnabled { SoundManager.shared.playPassDevice() }
    }

    func playVote() {
        triggerHaptic(.selection)
        if isSoundEnabled { SoundManager.shared.playVote() }
    }

    func playReveal() {
        triggerHaptic(.rigid)
        if isSoundEnabled { SoundManager.shared.playReveal() }
    }

    private func triggerHaptic(_ style: HapticStyle) {
        guard isVibrationEnabled else { return }
        switch style {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    private func playSystemSound(_ soundID: UInt32) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(SystemSoundID(soundID))
    }

    private enum HapticStyle {
        case success, error, warning, selection, light, medium, heavy, rigid
    }
}
