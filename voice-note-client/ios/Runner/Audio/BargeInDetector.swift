import Foundation

struct BargeInConfig {
  let enabled: Bool
  let energyThreshold: Double
  let minSpeechMs: Int
  let cooldownMs: Int

  static let `default` = BargeInConfig(
    enabled: true,
    energyThreshold: 0.5,
    minSpeechMs: 120,
    cooldownMs: 300
  )
}

final class BargeInDetector {
  private let sampleRate: Double
  private let onTriggered: () -> Void

  // Energy VAD with hold-time and cooldown to reduce false positives.
  private var config: BargeInConfig = .default
  private var speechMs = 0
  private var lastTriggerAtMs = 0

  init(sampleRate: Double = 16_000, onTriggered: @escaping () -> Void) {
    self.sampleRate = sampleRate
    self.onTriggered = onTriggered
  }

  func updateConfig(_ config: BargeInConfig) {
    self.config = config
    speechMs = 0
  }

  func onFrame(_ frame: Data, ttsPlaying: Bool) {
    guard config.enabled, ttsPlaying else {
      speechMs = 0
      return
    }

    let now = Int(Date().timeIntervalSince1970 * 1000)
    guard now - lastTriggerAtMs >= config.cooldownMs else { return }

    let rms = normalizedRms(frame)
    if rms >= config.energyThreshold {
      let frameSampleCount = max(1, frame.count / MemoryLayout<Float>.size)
      let frameDurationMs = max(1, Int((Double(frameSampleCount) / sampleRate) * 1000))
      speechMs += frameDurationMs
      if speechMs >= config.minSpeechMs {
        speechMs = 0
        lastTriggerAtMs = now
        onTriggered()
      }
    } else {
      speechMs = 0
    }
  }

  private func normalizedRms(_ frame: Data) -> Double {
    if frame.count < MemoryLayout<Float>.size { return 0 }
    let sampleCount = frame.count / MemoryLayout<Float>.size
    return frame.withUnsafeBytes { rawBuffer in
      guard let floatPtr = rawBuffer.bindMemory(to: Float.self).baseAddress else {
        return 0
      }
      var sum: Double = 0
      for i in 0..<sampleCount {
        let v = Double(floatPtr[i])
        sum += v * v
      }
      if sampleCount == 0 { return 0 }
      return sqrt(sum / Double(sampleCount))
    }
  }
}
