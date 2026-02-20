import Flutter
import Foundation

final class NativeAudioPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let methodChannelName = "voice_note/native_audio"
  private static let eventChannelName = "voice_note/native_audio/events"

  private var eventSink: FlutterEventSink?
  private lazy var runtimeController = AudioRuntimeController { [weak self] event, payload in
    guard let self = self else { return }
    guard let sink = self.eventSink else { return }
    var envelope: [String: Any] = [
      "event": event,
      "sessionId": payload["sessionId"] as? String ?? "",
      "requestId": payload["requestId"] as Any,
      "timestamp": payload["timestamp"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000),
      "data": payload["data"] as? [String: Any] ?? [:],
      "error": payload["error"] as Any
    ]
    // Keep envelope shape identical to Android.
    if envelope["requestId"] == nil { envelope["requestId"] = NSNull() }
    if envelope["error"] == nil { envelope["error"] = NSNull() }
    // Flutter requires platform channel messages on the platform (main) thread.
    if Thread.isMainThread {
      sink(envelope)
    } else {
      DispatchQueue.main.async { sink(envelope) }
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = NativeAudioPlugin()
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(plugin, channel: methodChannel)
    eventChannel.setStreamHandler(plugin)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let output: [String: Any]?
    switch call.method {
    case "initializeSession":
      output = runtimeController.initializeSession(args: args)
    case "disposeSession":
      output = runtimeController.disposeSession(args: args)
    case "setAsrMuted":
      output = runtimeController.setAsrMuted(args: args)
    case "playTts":
      output = runtimeController.playTts(args: args)
    case "stopTts":
      output = runtimeController.stopTts(args: args)
    case "setBargeInConfig":
      output = runtimeController.setBargeInConfig(args: args)
    case "getDuplexStatus":
      output = runtimeController.getDuplexStatus()
    case "switchInputMode":
      output = runtimeController.switchInputMode(args: args)
    case "getLifecycleSnapshot":
      output = runtimeController.getLifecycleSnapshot()
    case "restoreLifecycleSnapshot":
      output = runtimeController.restoreLifecycleSnapshot(args: args)
    case "startAsrStream":
      output = runtimeController.startAsrStream(args: args)
    case "commitAsr":
      output = runtimeController.commitAsr()
    case "stopAsrStream":
      output = runtimeController.stopAsrStream()
    case "startCapture":
      output = runtimeController.startCapture(args: args)
    case "stopCapture":
      output = runtimeController.stopCapture(args: args)
    default:
      output = nil
    }

    if let output = output {
      result(output)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
