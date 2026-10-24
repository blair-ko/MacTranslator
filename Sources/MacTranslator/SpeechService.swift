import AVFoundation
import Foundation

@MainActor
final class SpeechService: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    enum SpeakingTarget {
        case none
        case source
        case translated
    }

    @Published var speakingTarget: SpeakingTarget = .none
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggleSpeak(text: String, localeIdentifier: String, target: SpeakingTarget) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            let previousTarget = speakingTarget
            synthesizer.stopSpeaking(at: .immediate)
            speakingTarget = .none
            if previousTarget == target {
                return
            }
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let voice = AVSpeechSynthesisVoice(language: localeIdentifier) {
            utterance.voice = voice
        } else if localeIdentifier.hasPrefix("zh") {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        speakingTarget = target
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        speakingTarget = .none
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speakingTarget = .none
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speakingTarget = .none
    }
}
