import AVFoundation
import Foundation
import UIKit

final class FocusRouteManager {
  private var observers: [NSObjectProtocol] = []
  private let onFocusChanged: (_ focusState: String, _ canAutoResume: Bool) -> Void
  private let onRouteChanged: (_ oldRoute: String, _ newRoute: String, _ reason: String) -> Void
  private let onAppStateChanged: (_ appState: String) -> Void

  init(
    onFocusChanged: @escaping (_ focusState: String, _ canAutoResume: Bool) -> Void,
    onRouteChanged: @escaping (_ oldRoute: String, _ newRoute: String, _ reason: String) -> Void,
    onAppStateChanged: @escaping (_ appState: String) -> Void
  ) {
    self.onFocusChanged = onFocusChanged
    self.onRouteChanged = onRouteChanged
    self.onAppStateChanged = onAppStateChanged
  }

  func startObserving() {
    if !observers.isEmpty { return }
    let nc = NotificationCenter.default

    // Interruption ended may not always auto-resume; surface canAutoResume explicitly.
    let interruption = nc.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] note in
      guard let self = self else { return }
      guard let userInfo = note.userInfo,
            let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

      switch type {
      case .began:
        self.onFocusChanged("loss_transient", false)
      case .ended:
        let optionsRaw = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
        let canAutoResume = options.contains(.shouldResume)
        self.onFocusChanged("gain", canAutoResume)
      @unknown default:
        self.onFocusChanged("unknown", false)
      }
    }
    observers.append(interruption)

    let routeChanged = nc.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] note in
      guard let self = self else { return }
      let oldRoute = routeFromPrevious(note.userInfo)
      let newRoute = routeFromCurrent()
      let reason = routeReason(note.userInfo)
      self.onRouteChanged(oldRoute, newRoute, reason)
    }
    observers.append(routeChanged)

    let didEnterBg = nc.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.onAppStateChanged("background")
    }
    observers.append(didEnterBg)

    let willEnterFg = nc.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.onAppStateChanged("foreground")
    }
    observers.append(willEnterFg)
  }

  func stopObserving() {
    let nc = NotificationCenter.default
    observers.forEach { nc.removeObserver($0) }
    observers.removeAll()
  }
}

private func routeFromCurrent() -> String {
  let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
  guard let port = outputs.first?.portType else { return "unknown" }
  switch port {
  case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
    return "bluetooth"
  case .builtInSpeaker:
    return "speaker"
  default:
    return "earpiece"
  }
}

private func routeFromPrevious(_ userInfo: [AnyHashable: Any]?) -> String {
  guard let previous = userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
        let port = previous.outputs.first?.portType else {
    return "unknown"
  }
  switch port {
  case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
    return "bluetooth"
  case .builtInSpeaker:
    return "speaker"
  default:
    return "earpiece"
  }
}

private func routeReason(_ userInfo: [AnyHashable: Any]?) -> String {
  guard let reasonRaw = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
        let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
    return "unknown"
  }
  switch reason {
  case .newDeviceAvailable: return "new_device_available"
  case .oldDeviceUnavailable: return "old_device_unavailable"
  case .categoryChange: return "category_change"
  case .override: return "override"
  case .wakeFromSleep: return "wake_from_sleep"
  case .noSuitableRouteForCategory: return "no_suitable_route"
  case .routeConfigurationChange: return "route_config_change"
  case .unknown: return "unknown"
  @unknown default: return "unknown"
  }
}
