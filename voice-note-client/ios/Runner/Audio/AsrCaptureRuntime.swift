import AVFoundation
import Foundation

final class AsrCaptureRuntime {
  private let engine = AVAudioEngine()
  private let queue = DispatchQueue(label: "native.asr.capture")
  private var started = false
  private var asrMuted = false

  // Keep tap alive for whole session; upper layer decides gating.
  var onAudioFrame: ((Data, Bool) -> Void)?

  func start() throws {
    if started { return }

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      guard let self = self else { return }
      guard let channelData = buffer.floatChannelData?.pointee else { return }
      let frameCount = Int(buffer.frameLength)
      var pcm = Data(capacity: frameCount * MemoryLayout<Int16>.size)
      for i in 0..<frameCount {
        let floatSample = max(-1.0, min(1.0, channelData[i]))
        var intSample = Int16(floatSample * Float(Int16.max))
        pcm.append(UnsafeBufferPointer(start: &intSample, count: 1))
      }
      self.queue.async {
        self.onAudioFrame?(pcm, self.asrMuted)
      }
    }

    try engine.start()
    started = true
  }

  func setAsrMuted(_ muted: Bool) {
    asrMuted = muted
  }

  func isAsrMuted() -> Bool { asrMuted }
  func isRunning() -> Bool { started }

  func stop() {
    if !started { return }
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    started = false
  }
}
