import Flutter
import UIKit

/// Shared system material for navigation bars, sheets and player controls.
/// Kept in this compiled source alongside the native tab bar factory.
final class NativeLiquidGlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeLiquidGlassSurface(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }
}

private final class NativeLiquidGlassSurface: NSObject, FlutterPlatformView {
  private let effectView = UIVisualEffectView()
  private let channel: FlutterMethodChannel
  private var highContrast = false

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "simple_live/native_glass/\(viewId)", binaryMessenger: messenger)
    super.init()
    effectView.frame = frame
    effectView.isUserInteractionEnabled = false
    effectView.isAccessibilityElement = false
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    configure(arguments)
    NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial),
      name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      if call.method == "configure" {
        self.configure(call.arguments)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { effectView }

  private func configure(_ arguments: Any?) {
    guard let config = arguments as? [String: Any] else { return }
    effectView.overrideUserInterfaceStyle = (config["dark"] as? Bool ?? false) ? .dark : .light
    effectView.layer.cornerRadius = CGFloat((config["radius"] as? NSNumber)?.doubleValue ?? 28)
    highContrast = config["highContrast"] as? Bool ?? false
    updateMaterial()
  }

  @objc private func updateMaterial() {
    if highContrast || UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
      effectView.effect = nil
      effectView.backgroundColor = .secondarySystemBackground
      return
    }
    effectView.backgroundColor = .clear
    // Availability protects older devices; the compiler guard also permits
    // development using an older Xcode SDK without UIGlassEffect symbols.
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      effectView.effect = UIGlassEffect(style: .regular)
      return
    }
    #endif
    effectView.effect = UIBlurEffect(style: .systemMaterial)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    channel.setMethodCallHandler(nil)
  }
}

final class NativeLiquidGlassDockFactory: NSObject, FlutterPlatformViewFactory {
  private let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeLiquidGlassDockView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      registrar: registrar
    )
  }
}

private struct DockItem: Equatable {
  let id: Int
  let title: String

  var symbol: String {
    switch id {
    case 0: return "house"
    case 1: return "heart"
    case 2: return "square.grid.2x2"
    default: return "person.crop.circle"
    }
  }
}

private final class DockContainerView: UIView {
  var onWindowChanged: (() -> Void)?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindowChanged?()
  }
}

private final class NativeLiquidGlassDockView: NSObject, FlutterPlatformView, UITabBarControllerDelegate {
  private let container: DockContainerView
  private let controller = UITabBarController()
  private let channel: FlutterMethodChannel
  private let registrar: FlutterPluginRegistrar
  private var items: [DockItem] = []

  init(frame: CGRect, viewId: Int64, arguments: Any?, registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    container = DockContainerView(frame: frame)
    channel = FlutterMethodChannel(
      name: "simple_live/native_dock/\(viewId)",
      binaryMessenger: registrar.messenger()
    )
    super.init()

    container.backgroundColor = .clear
    container.isOpaque = false
    controller.loadViewIfNeeded()
    controller.view.backgroundColor = .clear
    controller.view.isOpaque = false
    controller.delegate = self

    // Keep this bottom navigation on iPad too, rather than UIKit's top tab bar.
    if #available(iOS 17.0, *) {
      controller.traitOverrides.horizontalSizeClass = .compact
    }
    if #available(iOS 18.0, *) {
      controller.mode = .tabBar
    }

    // Leave UITabBar's appearance and background entirely under UIKit's control.
    // With the iOS 26 SDK this supplies the system's Liquid Glass material.
    controller.view.frame = container.bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(controller.view)
    configure(arguments)

    container.onWindowChanged = { [weak self] in self?.updateContainment() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "configure":
        self.configure(call.arguments)
        result(nil)
      case "getState":
        result([
          "selectedIndex": self.controller.selectedIndex,
          "itemIds": self.items.map(\.id),
          "nativeController": "UITabBarController",
          "systemVersion": UIDevice.current.systemVersion,
          "attached": self.controller.parent != nil && self.controller.tabBar.window != nil,
          "darkMode": self.controller.overrideUserInterfaceStyle == .dark,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func updateContainment() {
    if container.window != nil, controller.parent == nil,
       let parent = registrar.viewController {
      // Follow UIKit containment even though Flutter owns the view's placement.
      controller.view.removeFromSuperview()
      parent.addChild(controller)
      controller.view.frame = container.bounds
      container.addSubview(controller.view)
      controller.didMove(toParent: parent)
    } else if container.window == nil, controller.parent != nil {
      detachController()
    }
  }

  private func detachController() {
    controller.willMove(toParent: nil)
    controller.view.removeFromSuperview()
    controller.removeFromParent()
  }

  private func configure(_ arguments: Any?) {
    guard let config = arguments as? [String: Any],
          let rawItems = config["items"] as? [[String: Any]] else { return }
    let newItems = rawItems.compactMap { item -> DockItem? in
      guard let id = item["id"] as? Int, let title = item["title"] as? String else { return nil }
      return DockItem(id: id, title: title)
    }
    guard !newItems.isEmpty else { return }

    if newItems != items {
      items = newItems
      controller.setViewControllers(items.map { item in
        let page = UIViewController()
        page.view.backgroundColor = .clear
        page.view.isOpaque = false
        page.tabBarItem = UITabBarItem(
          title: item.title,
          image: UIImage(systemName: item.symbol),
          selectedImage: UIImage(systemName: "\(item.symbol).fill")
        )
        page.tabBarItem.accessibilityIdentifier = "native-dock-\(item.id)"
        return page
      }, animated: false)
      controller.customizableViewControllers = []
    }

    if let index = config["selectedIndex"] as? Int, items.indices.contains(index) {
      controller.selectedIndex = index
    }
    controller.overrideUserInterfaceStyle = (config["darkMode"] as? Bool == true) ? .dark : .light
    if let value = config["tintColor"] as? NSNumber {
      let argb = value.uint32Value
      controller.tabBar.tintColor = UIColor(
        red: CGFloat((argb >> 16) & 255) / 255,
        green: CGFloat((argb >> 8) & 255) / 255,
        blue: CGFloat(argb & 255) / 255,
        alpha: CGFloat((argb >> 24) & 255) / 255
      )
    }
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
    if let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
      // Also forward repeat taps so Flutter retains scroll-to-top/refresh behavior.
      channel.invokeMethod("onSelected", arguments: index)
    }
    return true
  }

  deinit {
    channel.setMethodCallHandler(nil)
    controller.delegate = nil
    if controller.parent != nil { detachController() }
  }
}
