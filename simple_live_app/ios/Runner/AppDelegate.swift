import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativePresentations: NativeIOSPresentations?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeLiquidGlassDock") else { return }
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

}
