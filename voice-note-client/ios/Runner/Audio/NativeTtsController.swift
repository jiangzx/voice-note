import AVFoundation
import Foundation

final class NativeTtsController: NSObject, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private var activeRequestId: String?

  // Keep lifecycle callbacks explicit so Flutter futures can resolve deterministically.
  var onStarted: ((String?) -> Void)?
  var onCompleted: ((String?, Bool, String?) -> Void)?

  override init() {
    super.init()
    synthesizer.delegate = self
  }

  func play(requestId: String?, text: String, speechRate: Double, locale: String) -> Bool {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    activeRequestId = requestId ?? "tts_\(Int(Date().timeIntervalSince1970 * 1000))"

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: locale)
    utterance.rate = Float(max(0.1, min(0.6, speechRate * 0.3)))
    synthesizer.speak(utterance)
    return true
  }

  func stop(reason: String = "manual_stop") {
    let requestId = activeRequestId
    activeRequestId = nil
    synthesizer.stopSpeaking(at: .immediate)
    onCompleted?(requestId, true, reason)
  }

  func isPlaying() -> Bool { synthesizer.isSpeaking }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didStart utterance: AVSpeechUtterance
  ) {
    onStarted?(activeRequestId)
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    let requestId = activeRequestId
    activeRequestId = nil
    onCompleted?(requestId, true, nil)
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    let requestId = activeRequestId
    activeRequestId = nil
    onCompleted?(requestId, true, "cancelled")
  }
}
