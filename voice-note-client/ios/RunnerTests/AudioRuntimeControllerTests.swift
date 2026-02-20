import AVFoundation
import XCTest
@testable import Runner

final class AudioRuntimeControllerTests: XCTestCase {
  func testBargeInDetectorTriggersAfterMinSpeechWindow() {
    let trigger = expectation(description: "barge-in triggered")
    var triggerCount = 0

    let detector = BargeInDetector(sampleRate: 16_000) {
      triggerCount += 1
      trigger.fulfill()
    }
    detector.updateConfig(
      BargeInConfig(
        enabled: true,
        energyThreshold: 0.2,
        minSpeechMs: 20,
        cooldownMs: 100
      )
    )

    // Build a high-energy frame so RMS passes threshold deterministically.
    let frame = makeFrame(value: 1.0, sampleCount: 512)
    detector.onFrame(frame, ttsPlaying: true)
    detector.onFrame(frame, ttsPlaying: true)

    wait(for: [trigger], timeout: 1.0)
    XCTAssertEqual(triggerCount, 1)
  }

  func testInterruptionEndedWithoutShouldResumeReportsCanAutoResumeFalse() {
    let callback = expectation(description: "focus callback")
    var capturedCanAutoResume = true

    let manager = FocusRouteManager(
      onFocusChanged: { _, canAutoResume in
        capturedCanAutoResume = canAutoResume
        callback.fulfill()
      },
      onRouteChanged: { _, _, _ in },
      onAppStateChanged: { _ in }
    )
    manager.startObserving()
    defer { manager.stopObserving() }

    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
        AVAudioSessionInterruptionOptionKey: 0
      ]
    )

    wait(for: [callback], timeout: 1.0)
    XCTAssertFalse(capturedCanAutoResume)
  }

  func testLifecycleSnapshotRestoreConsistency() {
    let controller = AudioRuntimeController { _, _ in }

    let restoreResult = controller.restoreLifecycleSnapshot(args: [
      "snapshot": [
        "appState": "background",
        "asrMuted": true,
        "ttsPlaying": false,
        "focusState": "loss_transient",
        "route": "bluetooth",
        "bargeInConfig": [
          "enabled": true,
          "energyThreshold": 0.6,
          "minSpeechMs": 150,
          "cooldownMs": 350
        ]
      ]
    ])
    XCTAssertEqual(restoreResult["ok"] as? Bool, true)

    let snapshot = controller.getLifecycleSnapshot()
    XCTAssertEqual(snapshot["appState"] as? String, "background")
    XCTAssertEqual(snapshot["asrMuted"] as? Bool, true)
    XCTAssertEqual(snapshot["ttsPlaying"] as? Bool, false)
    XCTAssertEqual(snapshot["focusState"] as? String, "loss_transient")
    let cfg = snapshot["bargeInConfig"] as? [String: Any]
    XCTAssertEqual(cfg?["enabled"] as? Bool, true)
    XCTAssertEqual(cfg?["minSpeechMs"] as? Int, 150)
    XCTAssertEqual(cfg?["cooldownMs"] as? Int, 350)
  }

  func testRouteChangeNotificationEmitsNormalizedReason() {
    let callback = expectation(description: "route callback")
    var capturedReason = ""
    var capturedOldRoute = ""

    let manager = FocusRouteManager(
      onFocusChanged: { _, _ in },
      onRouteChanged: { oldRoute, _, reason in
        capturedOldRoute = oldRoute
        capturedReason = reason
        callback.fulfill()
      },
      onAppStateChanged: { _ in }
    )
    manager.startObserving()
    defer { manager.stopObserving() }

    NotificationCenter.default.post(
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      userInfo: [
        AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
      ]
    )

    wait(for: [callback], timeout: 1.0)
    XCTAssertEqual(capturedReason, "old_device_unavailable")
    XCTAssertEqual(capturedOldRoute, "unknown")
  }

  private func makeFrame(value: Float, sampleCount: Int) -> Data {
    var samples = Array(repeating: value, count: sampleCount)
    return Data(bytes: &samples, count: sampleCount * MemoryLayout<Float>.size)
  }
}
