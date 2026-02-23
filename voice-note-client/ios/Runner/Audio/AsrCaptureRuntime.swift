import AVFoundation
import Foundation

/// ASR server expects 16 kHz mono PCM; hardware is typically 48 kHz. Resample before sending.
private let kAsrSampleRate: Double = 16_000

private let kCaptureLogTag = "[iOS Capture]"

final class AsrCaptureRuntime {
  private let engine = AVAudioEngine()
  private let queue = DispatchQueue(label: "native.asr.capture")
  private var started = false
  private var asrMuted = false
  private var converter: AVAudioConverter?
  private var outputFormat: AVAudioFormat?
  private var tapCallbackCount: Int = 0

  var onAudioFrame: ((Data, Bool) -> Void)?

  func start() throws {
    if started {
      print("\(kCaptureLogTag) start() called but already started, skipping")
      return
    }
    print("\(kCaptureLogTag) start() BEGIN")

    let input = engine.inputNode
    let inputFormat = input.outputFormat(forBus: 0)
    print("\(kCaptureLogTag) inputFormat sampleRate=\(inputFormat.sampleRate) channels=\(inputFormat.channelCount)")
    guard let targetFormat = AVAudioFormat(
      standardFormatWithSampleRate: kAsrSampleRate,
      channels: 1
    ) else {
      throw NSError(domain: "AsrCaptureRuntime", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create 16kHz format"])
    }

    let useConverter = inputFormat.sampleRate != kAsrSampleRate
    print("\(kCaptureLogTag) useConverter=\(useConverter) (input \(inputFormat.sampleRate) Hz -> \(kAsrSampleRate) Hz)")
    if useConverter {
      guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
        print("\(kCaptureLogTag) AVAudioConverter init FAILED")
        throw NSError(domain: "AsrCaptureRuntime", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAudioConverter init failed"])
      }
      converter = conv
      outputFormat = targetFormat
    } else {
      converter = nil
      outputFormat = nil
    }

    input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
      guard let self = self else { return }
      self.tapCallbackCount += 1
      let n = self.tapCallbackCount
      if n <= 3 || (n % 500 == 0) {
        print("\(kCaptureLogTag) tap callback #\(n) frameLength=\(buffer.frameLength)")
      }
      let pcm: Data
      if useConverter, let conv = self.converter, let outFmt = self.outputFormat,
         let outBuffer = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * kAsrSampleRate / Double(inputFormat.sampleRate))) {
        var error: NSError?
        var inputProvided = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
          if inputProvided {
            outStatus.pointee = .noDataNow
            return nil
          }
          inputProvided = true
          outStatus.pointee = .haveData
          return buffer
        }
        conv.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
        if error != nil { return }
        guard let outChannel = outBuffer.floatChannelData?.pointee else { return }
        let outFrames = Int(outBuffer.frameLength)
        var data = Data(capacity: outFrames * MemoryLayout<Int16>.size)
        for i in 0..<outFrames {
          let floatSample = max(-1.0, min(1.0, outChannel[i]))
          var intSample = Int16(floatSample * Float(Int16.max))
          data.append(UnsafeBufferPointer(start: &intSample, count: 1))
        }
        pcm = data
      } else {
        guard let channelData = buffer.floatChannelData?.pointee else { return }
        let frameCount = Int(buffer.frameLength)
        var data = Data(capacity: frameCount * MemoryLayout<Int16>.size)
        for i in 0..<frameCount {
          let floatSample = max(-1.0, min(1.0, channelData[i]))
          var intSample = Int16(floatSample * Float(Int16.max))
          data.append(UnsafeBufferPointer(start: &intSample, count: 1))
        }
        pcm = data
      }
      let muted = self.asrMuted
      self.queue.async {
        self.onAudioFrame?(pcm, muted)
      }
    }

    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      throw error
    }
    started = true
    print("\(kCaptureLogTag) start() DONE engine.start() succeeded, tap installed")
  }

  func setAsrMuted(_ muted: Bool) {
    asrMuted = muted
  }

  func isAsrMuted() -> Bool { asrMuted }
  func isRunning() -> Bool { started }

  func stop() {
    if !started { return }
    print("\(kCaptureLogTag) stop() tapCallbackCount was \(tapCallbackCount)")
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    converter = nil
    outputFormat = nil
    tapCallbackCount = 0
    started = false
  }
}
