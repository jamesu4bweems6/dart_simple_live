import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioChannel: FlutterMethodChannel?
  private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var nextBackgroundTaskId = 1
  private var nativePresentations: NativeIOSPresentations?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerAudioObservers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeLiquidGlassDock") else { return }
    let audio = FlutterMethodChannel(name: "simple_live/ios_audio", binaryMessenger: registrar.messenger())
    audio.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "activate":
        self.configureAudioSession()
        result(nil)
      case "deactivate":
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        result(nil)
      case "beginBackgroundTask":
        result(self.beginBackgroundTask(label: args?["label"] as? String ?? "live_reconnect"))
      case "endBackgroundTask":
        self.endBackgroundTask(id: args?["id"] as? Int ?? -1)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    audioChannel = audio
    nativePresentations = NativeIOSPresentations(messenger: registrar.messenger())
    registrar.register(
      NativeLiquidGlassDockFactory(registrar: registrar),
      withId: "simple_live/native_liquid_glass_dock"
    )
    registrar.register(
      NativeLiquidGlassSurfaceFactory(messenger: registrar.messenger()),
      withId: "simple_live/native_liquid_glass_surface"
    )
    registrar.register(
      NativeIOSControlFactory(messenger: registrar.messenger()),
      withId: "simple_live/native_control"
    )
  }

  // MARK: - Audio session

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      // .playback is required for background audio; do not mix with other apps.
      try session.setCategory(.playback, mode: .moviePlayback, options: [])
      try session.setActive(true)
    } catch {
      NSLog("Simple Live: failed to configure audio session: \(error)")
    }
  }

  private func registerAudioObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
  }

  @objc private func handleInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      audioChannel?.invokeMethod("interruptionBegan", arguments: nil)
    case .ended:
      let optionValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
      let shouldResume = options.contains(.shouldResume)
      // AudioUnit-based playback must reactivate the session itself.
      do {
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        NSLog("Simple Live: reactivate audio session failed: \(error)")
      }
      audioChannel?.invokeMethod(
        "interruptionEnded",
        arguments: ["shouldResume": shouldResume]
      )
    @unknown default:
      break
    }
  }

  @objc private func handleRouteChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }
    // Old device unavailable, e.g. headphones unplugged.
    if reason == .oldDeviceUnavailable {
      audioChannel?.invokeMethod(
        "routeChange",
        arguments: ["shouldPause": true]
      )
    }
  }

  // MARK: - Background tasks

  private func beginBackgroundTask(label: String) -> Int {
    let id = nextBackgroundTaskId
    nextBackgroundTaskId += 1
    let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: label) {
      // Expiration handler.
      self.endBackgroundTask(id: id)
    }
    if taskIdentifier == .invalid {
      return -1
    }
    backgroundTasks[id] = taskIdentifier
    return id
  }

  private func endBackgroundTask(id: Int) {
    guard let taskIdentifier = backgroundTasks.removeValue(forKey: id) else {
      return
    }
    UIApplication.shared.endBackgroundTask(taskIdentifier)
  }


}
