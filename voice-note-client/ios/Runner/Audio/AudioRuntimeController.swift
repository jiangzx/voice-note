import AVFoundation
import Foundation

final class AudioRuntimeController {
  private var sessionId: String?
  private var initialized = false
  private var asrMuted = false
  private var ttsPlaying = false
  private var focusState = "idle"
  private var route = "speaker"
  private var mode = "auto"
  private var bargeInConfig: [String: Any] = ["enabled": true]
  private var appState = "foreground"

  private let captureRuntime = AsrCaptureRuntime()
  private let ttsController = NativeTtsController()
  private lazy var asrTransport = AsrNativeTransport(
    onInterimText: { [weak self] text in
      self?.emit("asrInterimText", requestId: nil, data: ["text": text])
    },
    onFinalText: { [weak self] text in
      self?.emit("asrFinalText", requestId: nil, data: ["text": text])
    },
    onError: { [weak self] message in
      self?.emitRuntimeError(code: "asr_ws_error", message: message)
    }
  )
  private lazy var focusRouteManager: FocusRouteManager = {
    FocusRouteManager(
      onFocusChanged: { [weak self] newFocus, canAutoResume in
        guard let self = self else { return }
        self.focusState = newFocus
        self.emit("audioFocusChanged", requestId: nil, data: [
          "focusState": newFocus,
          "canAutoResume": canAutoResume,
          "route": self.currentRoute()
        ])
      },
      onRouteChanged: { [weak self] oldRoute, newRoute, reason in
        guard let self = self else { return }
        self.route = newRoute
        self.emit("audioRouteChanged", requestId: nil, data: [
          "oldRoute": oldRoute,
          "newRoute": newRoute,
          "reason": reason
        ])
      },
      onAppStateChanged: { [weak self] state in
        guard let self = self else { return }
        self.appState = state
      }
    )
  }()
  private lazy var bargeInDetector: BargeInDetector = {
    BargeInDetector { [weak self] in
      guard let self = self else { return }
      guard self.ttsPlaying else { return }
      self.emit("bargeInTriggered", requestId: nil, data: [
        "triggerSource": "energy_vad",
        "route": self.currentRoute(),
        "focusState": self.focusState,
        "canAutoResume": true
      ])
      _ = self.stopTts(args: ["reason": "barge_in"])
      self.emit("bargeInCompleted", requestId: nil, data: [
        "success": true,
        "canAutoResume": true
      ])
    }
  }()

  // Event emitter shared by plugin; keep payload schema aligned with Android.
  private let emitEvent: (String, [String: Any]) -> Void

  init(emitEvent: @escaping (String, [String: Any]) -> Void) {
    self.emitEvent = emitEvent
    wireCallbacks()
  }

  func initializeSession(args: [String: Any]) -> [String: Any] {
    guard let sid = args["sessionId"] as? String else {
      return ["ok": false, "error": "missing_session_id"]
    }
    sessionId = sid
    mode = args["mode"] as? String ?? mode

    // Configure once; activate when session enters runtime.
    do {
      try configureAudioSession()
      try AVAudioSession.sharedInstance().setActive(true)
      try captureRuntime.start()
      focusRouteManager.startObserving()
      initialized = true
      focusState = "gain"
      route = currentRoute()
      emit(
        "runtimeInitialized",
        requestId: nil,
        data: ["focusState": focusState, "route": route]
      )
      return [
        "ok": true,
        "runtimeState": "ready",
        "capabilities": ["asr_gate", "tts_lifecycle", "lifecycle_snapshot"]
      ]
    } catch {
      emitRuntimeError(code: "ios_init_failed", message: "\(error)")
      return ["ok": false, "error": "ios_init_failed"]
    }
  }

  func disposeSession(args: [String: Any]) -> [String: Any] {
    guard let sid = sessionId else { return ["ok": true] }
    if let target = args["sessionId"] as? String, target != sid {
      return ["ok": true]
    }

    captureRuntime.stop()
    asrTransport.disconnect()
    ttsController.stop(reason: "dispose")
    focusRouteManager.stopObserving()
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

    sessionId = nil
    initialized = false
    asrMuted = false
    ttsPlaying = false
    focusState = "idle"
    return ["ok": true]
  }

  func setAsrMuted(args: [String: Any]) -> [String: Any] {
    asrMuted = (args["muted"] as? Bool) ?? asrMuted
    captureRuntime.setAsrMuted(asrMuted)
    emit("asrMuteStateChanged", requestId: nil, data: ["asrMuted": asrMuted])
    return ["ok": true, "muted": asrMuted]
  }

  func playTts(args: [String: Any]) -> [String: Any] {
    guard initialized else { return ["ok": false, "error": "not_initialized"] }
    let requestId = args["requestId"] as? String
    let text = args["text"] as? String ?? ""
    let locale = args["locale"] as? String ?? "zh-CN"
    let speechRate = args["speechRate"] as? Double ?? 1.0

    // Critical order: mute recognizer path first, then start playback.
    _ = setAsrMuted(args: ["muted": true, "reason": "tts_playback"])
    let ok = ttsController.play(requestId: requestId, text: text, speechRate: speechRate, locale: locale)
    if !ok {
      _ = setAsrMuted(args: ["muted": false, "reason": "tts_failed"])
      emitRuntimeError(code: "tts_not_ready", message: "Native iOS TTS engine not ready")
      return ["ok": false, "requestId": requestId as Any]
    }
    ttsPlaying = true
    return ["ok": true, "requestId": requestId as Any]
  }

  func stopTts(args: [String: Any]) -> [String: Any] {
    ttsController.stop(reason: (args["reason"] as? String) ?? "manual_stop")
    ttsPlaying = false
    _ = setAsrMuted(args: ["muted": false, "reason": "tts_stopped"])
    emit(
      "ttsStopped",
      requestId: args["requestId"] as? String,
      data: ["ttsPlaying": false, "canAutoResume": true]
    )
    return ["ok": true]
  }

  func setBargeInConfig(args: [String: Any]) -> [String: Any] {
    bargeInConfig = [
      "enabled": (args["enabled"] as? Bool) ?? (bargeInConfig["enabled"] as? Bool ?? true),
      "energyThreshold": (args["energyThreshold"] as? Double) ?? (bargeInConfig["energyThreshold"] as? Double ?? 0.5),
      "minSpeechMs": (args["minSpeechMs"] as? Int) ?? (bargeInConfig["minSpeechMs"] as? Int ?? 120),
      "cooldownMs": (args["cooldownMs"] as? Int) ?? (bargeInConfig["cooldownMs"] as? Int ?? 300),
    ]
    bargeInDetector.updateConfig(
      BargeInConfig(
        enabled: bargeInConfig["enabled"] as? Bool ?? true,
        energyThreshold: bargeInConfig["energyThreshold"] as? Double ?? 0.5,
        minSpeechMs: bargeInConfig["minSpeechMs"] as? Int ?? 120,
        cooldownMs: bargeInConfig["cooldownMs"] as? Int ?? 300
      )
    )
    return ["ok": true, "enabled": bargeInConfig["enabled"] as? Bool ?? true]
  }

  func startAsrStream(args: [String: Any]) -> [String: Any] {
    guard let token = args["token"] as? String else {
      return ["ok": false, "error": "missing_token"]
    }
    guard let wsUrl = args["wsUrl"] as? String else {
      return ["ok": false, "error": "missing_ws_url"]
    }
    guard let model = args["model"] as? String else {
      return ["ok": false, "error": "missing_model"]
    }
    asrTransport.connect(token: token, wsUrl: wsUrl, model: model)
    do {
      try captureRuntime.start()
    } catch {
      return ["ok": false, "error": "capture_start_failed"]
    }
    return ["ok": true]
  }

  func commitAsr() -> [String: Any] {
    asrTransport.commit()
    return ["ok": true]
  }

  func stopAsrStream() -> [String: Any] {
    asrTransport.disconnect()
    return ["ok": true]
  }

  func getDuplexStatus() -> [String: Any] {
    return [
      "captureActive": captureRuntime.isRunning(),
      "asrMuted": asrMuted,
      "ttsPlaying": ttsPlaying,
      "focusState": focusState,
      "route": currentRoute(),
      "lastError": NSNull()
    ]
  }

  func switchInputMode(args: [String: Any]) -> [String: Any] {
    let newMode = args["mode"] as? String ?? mode
    let oldMode = mode
    mode = newMode

    switch newMode {
    case "keyboard":
      // 停止 ASR stream，停止音频捕获
      asrTransport.disconnect()
      captureRuntime.stop()
      _ = setAsrMuted(args: ["muted": true])
    case "pushToTalk":
      // 如果之前是 auto 模式，captureRuntime 可能在运行，需要停止它
      // pushToTalk 模式下，captureRuntime 只在 pushStart 时启动
      if captureRuntime.isRunning() {
        captureRuntime.stop()
      }
      // 保持 ASR stream 运行，但默认 mute ASR
      // 只有在 Flutter 层调用 pushStart 时才 unmute
      _ = setAsrMuted(args: ["muted": true])
      // 禁用 barge-in（pushToTalk 模式下不需要自动 VAD）
      bargeInConfig = [
        "enabled": false,
        "energyThreshold": bargeInConfig["energyThreshold"] as? Double ?? 0.5,
        "minSpeechMs": bargeInConfig["minSpeechMs"] as? Int ?? 120,
        "cooldownMs": bargeInConfig["cooldownMs"] as? Int ?? 300
      ]
      bargeInDetector.updateConfig(
        BargeInConfig(
          enabled: false,
          energyThreshold: bargeInConfig["energyThreshold"] as? Double ?? 0.5,
          minSpeechMs: bargeInConfig["minSpeechMs"] as? Int ?? 120,
          cooldownMs: bargeInConfig["cooldownMs"] as? Int ?? 300
        )
      )
    case "auto":
      // 如果之前是 keyboard 或 pushToTalk 模式，captureRuntime 可能已停止
      // 需要确保 captureRuntime 运行（auto 模式需要持续监听）
      if !captureRuntime.isRunning() {
        do {
          try captureRuntime.start()
        } catch {
          // 如果启动失败，记录错误但不阻止模式切换
        }
      }
      // 启用自动 VAD
      _ = setAsrMuted(args: ["muted": false])
      bargeInConfig = [
        "enabled": true,
        "energyThreshold": bargeInConfig["energyThreshold"] as? Double ?? 0.5,
        "minSpeechMs": bargeInConfig["minSpeechMs"] as? Int ?? 120,
        "cooldownMs": bargeInConfig["cooldownMs"] as? Int ?? 300
      ]
      bargeInDetector.updateConfig(
        BargeInConfig(
          enabled: true,
          energyThreshold: bargeInConfig["energyThreshold"] as? Double ?? 0.5,
          minSpeechMs: bargeInConfig["minSpeechMs"] as? Int ?? 120,
          cooldownMs: bargeInConfig["cooldownMs"] as? Int ?? 300
        )
      )
    default:
      break
    }

    return ["ok": true, "mode": mode]
  }

  func startCapture(args: [String: Any]) -> [String: Any] {
    if !captureRuntime.isRunning() {
      do {
        try captureRuntime.start()
      } catch {
        return ["ok": false, "error": "capture_start_failed"]
      }
    }
    return ["ok": true]
  }

  func stopCapture(args: [String: Any]) -> [String: Any] {
    captureRuntime.stop()
    return ["ok": true]
  }

  func getLifecycleSnapshot() -> [String: Any] {
    return [
      "appState": appState,
      "captureActive": captureRuntime.isRunning(),
      "asrMuted": asrMuted,
      "ttsPlaying": ttsPlaying,
      "focusState": focusState,
      "route": currentRoute(),
      "bargeInConfig": bargeInConfig
    ]
  }

  func restoreLifecycleSnapshot(args: [String: Any]) -> [String: Any] {
    guard let snapshot = args["snapshot"] as? [String: Any] else {
      return ["ok": false, "error": "missing_snapshot"]
    }
    asrMuted = snapshot["asrMuted"] as? Bool ?? asrMuted
    captureRuntime.setAsrMuted(asrMuted)
    ttsPlaying = snapshot["ttsPlaying"] as? Bool ?? ttsPlaying
    focusState = snapshot["focusState"] as? String ?? focusState
    route = snapshot["route"] as? String ?? route
    appState = snapshot["appState"] as? String ?? appState
    bargeInConfig = snapshot["bargeInConfig"] as? [String: Any] ?? bargeInConfig
    bargeInDetector.updateConfig(
      BargeInConfig(
        enabled: bargeInConfig["enabled"] as? Bool ?? true,
        energyThreshold: bargeInConfig["energyThreshold"] as? Double ?? 0.5,
        minSpeechMs: bargeInConfig["minSpeechMs"] as? Int ?? 120,
        cooldownMs: bargeInConfig["cooldownMs"] as? Int ?? 300
      )
    )
    return [
      "ok": true,
      "restoredFields": ["asrMuted", "ttsPlaying", "focusState", "route", "appState", "bargeInConfig"]
    ]
  }

  private func wireCallbacks() {
    ttsController.onStarted = { [weak self] requestId in
      guard let self = self else { return }
      self.ttsPlaying = true
      self.emit("ttsStarted", requestId: requestId, data: [
        "ttsPlaying": true,
        "route": self.currentRoute(),
        "focusState": self.focusState
      ])
    }

    ttsController.onCompleted = { [weak self] requestId, success, error in
      guard let self = self else { return }
      self.ttsPlaying = false
      _ = self.setAsrMuted(args: ["muted": false, "reason": "tts_completed"])
      if success {
        self.emit("ttsCompleted", requestId: requestId, data: [
          "ttsPlaying": false,
          "canAutoResume": true
        ])
      } else {
        let normalized = ErrorMapper.normalize(
          rawCode: error,
          fallbackMessage: error ?? "unknown"
        )
        self.emit(
          "ttsError",
          requestId: requestId,
          data: ["ttsPlaying": false, "canAutoResume": true],
          error: normalized.toMap
        )
      }
    }

    captureRuntime.onAudioFrame = { [weak self] frame, _ in
      // Runtime tap feeds detector continuously; detector only fires during TTS.
      guard let self = self else { return }
      self.bargeInDetector.onFrame(frame, ttsPlaying: self.ttsPlaying)
      self.asrTransport.sendAudioFrame(frame)
    }
  }

  private func emit(
    _ event: String,
    requestId: String?,
    data: [String: Any],
    error: [String: Any]? = nil
  ) {
    guard let sid = sessionId else { return }
    emitEvent(event, [
      "sessionId": sid,
      "requestId": requestId as Any,
      "timestamp": Int(Date().timeIntervalSince1970 * 1000),
      "data": data,
      "error": error as Any
    ])
  }

  private func emitRuntimeError(code: String, message: String) {
    let normalized = ErrorMapper.normalize(rawCode: code, fallbackMessage: message)
    emit("runtimeError", requestId: nil, data: [
      "focusState": focusState,
      "route": currentRoute()
    ], error: normalized.toMap)
  }

  private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    // Prefer voiceChat mode for AEC/NS and duplex stability.
    try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
  }

  private func currentRoute() -> String {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    guard let port = outputs.first?.portType else { return route }
    switch port {
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
      return "bluetooth"
    case .builtInSpeaker:
      return "speaker"
    default:
      return "earpiece"
    }
  }
}
