import Foundation

final class AsrNativeTransport {
  private var socketTask: URLSessionWebSocketTask?
  private let session = URLSession(configuration: .default)
  private var connected = false
  /// When true, we are intentionally disconnecting; do not report send/receive errors to UI.
  private var disconnecting = false

  private let onInterimText: (String) -> Void
  private let onFinalText: (String) -> Void
  private let onError: (String) -> Void

  init(
    onInterimText: @escaping (String) -> Void,
    onFinalText: @escaping (String) -> Void,
    onError: @escaping (String) -> Void
  ) {
    self.onInterimText = onInterimText
    self.onFinalText = onFinalText
    self.onError = onError
  }

  func connect(token: String, wsUrl: String, model: String, useServerVad: Bool = true) {
    disconnect()
    guard var components = URLComponents(string: wsUrl) else {
      onError("asr_invalid_ws_url")
      return
    }
    var query = components.queryItems ?? []
    query.append(URLQueryItem(name: "model", value: model))
    components.queryItems = query
    guard let url = components.url else {
      onError("asr_invalid_ws_url")
      return
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
    let task = session.webSocketTask(with: request)
    socketTask = task
    task.resume()
    connected = true
    disconnecting = false
    sendSessionUpdate(useServerVad: useServerVad)
    receiveLoop()
  }

  func sendAudioFrame(_ frame: Data) {
    guard connected else { return }
    let payload: [String: Any] = [
      "event_id": "evt_\(Int(Date().timeIntervalSince1970 * 1000))",
      "type": "input_audio_buffer.append",
      "audio": frame.base64EncodedString()
    ]
    sendJSON(payload)
  }

  func commit() {
    guard connected else { return }
    let payload: [String: Any] = [
      "event_id": "evt_commit_\(Int(Date().timeIntervalSince1970 * 1000))",
      "type": "input_audio_buffer.commit"
    ]
    sendJSON(payload)
  }

  func disconnect() {
    disconnecting = true
    connected = false
    socketTask?.cancel(with: .normalClosure, reason: nil)
    socketTask = nil
  }

  var isConnected: Bool { connected }

  /// Send session.update (e.g. after mode switch). No-op if not connected.
  func sendSessionUpdate(useServerVad: Bool) {
    guard connected else { return }
    let turnDetection: Any = useServerVad ? ["type": "server_vad"] : NSNull()
    let sessionDict: [String: Any] = [
      "modalities": ["text"],
      "input_audio_format": "pcm",
      "sample_rate": 16000,
      "input_audio_transcription": ["language": "zh"],
      "turn_detection": turnDetection
    ]
    let payload: [String: Any] = [
      "event_id": "evt_session_update_\(Int(Date().timeIntervalSince1970 * 1000))",
      "type": "session.update",
      "session": sessionDict
    ]
    sendJSON(payload)
  }

  private func sendJSON(_ payload: [String: Any]) {
    guard connected else { return }
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: data, encoding: .utf8) else { return }
    socketTask?.send(.string(text)) { [weak self] error in
      guard let self = self else { return }
      if let error = error, !self.disconnecting {
        self.onError("asr_send_error:\(error.localizedDescription)")
      }
    }
  }

  private func receiveLoop() {
    guard connected else { return }
    let currentTask = socketTask
    currentTask?.receive { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .failure(let error):
        self.connected = false
        // Only report if this failure is for the still-current connection (not a replaced one).
        if !self.disconnecting, self.socketTask === currentTask {
          self.onError("asr_ws_failure:\(error.localizedDescription)")
        }
      case .success(let message):
        switch message {
        case .string(let text):
          self.handleMessage(text)
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            self.handleMessage(text)
          }
        @unknown default:
          break
        }
        self.receiveLoop()
      }
    }
  }

  private func handleMessage(_ raw: String) {
    guard let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return
    }
    let type = json["type"] as? String ?? ""
    switch type {
    case "conversation.item.input_audio_transcription.text", "response.audio_transcript.delta":
      let text = (json["text"] as? String) ?? (json["delta"] as? String) ?? ""
      if !text.isEmpty { onInterimText(text) }
    case "conversation.item.input_audio_transcription.completed", "response.audio_transcript.done":
      let text = json["transcript"] as? String ?? ""
      if !text.isEmpty { onFinalText(text) }
    case "conversation.item.created":
      if let item = json["item"] as? [String: Any],
         let content = item["content"] as? [[String: Any]] {
        for part in content {
          let text = (part["transcript"] as? String) ?? (part["text"] as? String) ?? ""
          if !text.isEmpty {
            onFinalText(text)
            break
          }
        }
      }
    case "error":
      let errorMessage = (json["error"] as? [String: Any])?["message"] as? String ?? "unknown_asr_error"
      onError(errorMessage)
    default:
      break
    }
  }
}
