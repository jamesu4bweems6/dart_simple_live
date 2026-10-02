import Flutter
import UIKit

final class NativeIOSControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeIOSControl(frame: frame, id: id, arguments: args, messenger: messenger)
  }
}

private final class NativeControlContainer: UIView {
  var layout: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); layout?() }
}

private final class NativeIOSControl: NSObject, FlutterPlatformView, UITextFieldDelegate, UITextViewDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate {
  private let container: NativeControlContainer
  private let channel: FlutterMethodChannel
  private var kind = ""
  private var configuration: [String: Any] = [:]
  private var control: UIView?
  private var navigationBar: UINavigationBar?
  private var searchBar: UISearchBar?
  private var segments: UISegmentedControl?
  private var cell: UITableViewCell?
  private var label: UILabel?
  private var textField: UITextField?
  private var textView: UITextView?
  private var didAutofocus = false

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    container = NativeControlContainer(frame: frame)
    channel = FlutterMethodChannel(name: "simple_live/native_control/\(id)", binaryMessenger: messenger)
    super.init()
    container.backgroundColor = .clear
    container.isOpaque = false
    // No Flutter blur, painted rim, material overlay or custom touch animation.
    container.layout = { [weak self] in self?.layout() }
    configure(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "configure": self.configure(call.arguments); result(nil)
      case "getState": result(["kind": self.kind, "controlClass": self.control.map { NSStringFromClass(type(of: $0)) } ?? "",
        "systemVersion": UIDevice.current.systemVersion])
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }
  private func emit(_ name: String, _ value: Any? = nil) {
    channel.invokeMethod("event", arguments: ["name": name, "value": value ?? NSNull()])
  }

  private func configure(_ args: Any?) {
    guard let config = args as? [String: Any] else { return }
    let newKind = config["kind"] as? String ?? "button"
    if newKind != kind {
      kind = newKind
      container.subviews.forEach { $0.removeFromSuperview() }
      control = nil; navigationBar = nil; searchBar = nil; segments = nil; cell = nil; textField = nil
    }
    configuration = config
    container.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    if let argb = (config["tint"] as? NSNumber)?.uint32Value { container.tintColor = UIColor(argb: argb) }
    switch kind {
    case "navigation": configureNavigation()
    case "segments": configureSegments()
    case "row", "switch", "stepper": configureRow()
    case "slider": configureSlider()
    case "textfield": configureTextField()
    default: configureButton()
    }
    container.setNeedsLayout()
  }

  private func mount(_ view: UIView) { if view.superview == nil { container.addSubview(view) }; control = view }

  private func buttonConfiguration(_ config: [String: Any]) -> UIButton.Configuration {
    var result: UIButton.Configuration
    if #available(iOS 26.0, *) {
      result = config["prominent"] as? Bool == true ? .prominentGlass() : .glass()
    } else { result = .tinted() }
    result.title = config["title"] as? String
    if let symbol = config["symbol"] as? String {
      result.image = UIImage(systemName: symbol)
      result.imagePadding = 6
    }
    result.cornerStyle = .capsule
    if let value = (config["foreground"] as? NSNumber)?.uint32Value { result.baseForegroundColor = UIColor(argb: value) }
    return result
  }

  private func configureButton() {
    let button = control as? UIButton ?? UIButton(type: .system)
    if control == nil {
      button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
      button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(buttonHeld(_:))))
    }
    button.configuration = buttonConfiguration(configuration)
    button.isEnabled = configuration["enabled"] as? Bool ?? true
    button.isSelected = configuration["selected"] as? Bool ?? false
    button.accessibilityLabel = configuration["accessibilityLabel"] as? String
    if let rawMenu = configuration["menu"] as? [[String: Any]] {
      button.menu = menu(rawMenu); button.showsMenuAsPrimaryAction = true
    }
    mount(button)
  }

  @objc private func buttonTapped() { emit("tap") }
  @objc private func buttonHeld(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began { emit("longPress") }
  }

  private func menu(_ items: [[String: Any]]) -> UIMenu {
    UIMenu(children: items.map { item in
      let image = (item["symbol"] as? String).flatMap { UIImage(systemName: $0) }
      let action = UIAction(title: item["title"] as? String ?? "", image: image,
        state: item["selected"] as? Bool == true ? .on : .off) { [weak self] _ in
          self?.emit("action", item["id"])
        }
      if item["enabled"] as? Bool == false { action.attributes = .disabled }
      return action
    })
  }

  private func barItem(_ item: [String: Any]) -> UIBarButtonItem {
    let image = (item["symbol"] as? String).flatMap { UIImage(systemName: $0) }
    if let rawMenu = item["menu"] as? [[String: Any]] {
      return UIBarButtonItem(title: item["title"] as? String, image: image, primaryAction: nil, menu: menu(rawMenu))
    }
    if item["loading"] as? Bool == true {
      let activity = UIActivityIndicatorView(style: .medium); activity.startAnimating()
      return UIBarButtonItem(customView: activity)
    }
    let action = UIAction { [weak self] _ in self?.emit("action", item["id"]) }
    let button = UIBarButtonItem(title: item["title"] as? String, image: image, primaryAction: action)
    button.isEnabled = item["enabled"] as? Bool ?? true
    button.accessibilityLabel = item["accessibilityLabel"] as? String ?? item["title"] as? String
    return button
  }

  private func configureNavigation() {
    let bar = navigationBar ?? UINavigationBar()
    navigationBar = bar
    mount(bar)
    // Preserve the SDK's default appearance. iOS 26 supplies individual system
    // glass bar-button groups instead of a rectangular blurred AppBar background.
    let item = UINavigationItem(title: configuration["title"] as? String ?? "")
    if let back = configuration["back"] as? Bool, back {
      item.leftBarButtonItem = barItem(["id": "back", "symbol": "chevron.left", "accessibilityLabel": "返回"])
    } else if let leading = configuration["leading"] as? [String: Any] {
      item.leftBarButtonItem = barItem(leading)
    }
    if let items = configuration["actions"] as? [[String: Any]] { item.rightBarButtonItems = items.reversed().map(barItem) }
    if let search = configuration["search"] as? [String: Any] {
      let searchView = searchBar ?? UISearchBar()
      searchBar = searchView
      searchView.delegate = self
      searchView.placeholder = search["placeholder"] as? String
      searchView.searchBarStyle = .minimal
      let text = search["text"] as? String ?? ""
      if searchView.text != text { searchView.text = text }
      item.titleView = searchView
      if let scopes = search["scopes"] as? [String] {
        let index = search["scope"] as? Int ?? 0
        let scopeItems = scopes.enumerated().map { ["id": "scope:\($0.offset)", "title": $0.element, "selected": $0.offset == index] as [String: Any] }
        item.rightBarButtonItem = UIBarButtonItem(title: scopes.indices.contains(index) ? scopes[index] : "房间",
          image: nil, primaryAction: nil, menu: menu(scopeItems))
      }
    } else if let tabs = configuration["titleTabs"] as? [String: Any] {
      let segmented = makeSegments(tabs)
      item.titleView = segmented
    }
    bar.setItems([item], animated: false)
    if let tabs = configuration["bottomTabs"] as? [String: Any] {
      let segmented = segments ?? UISegmentedControl()
      segments = segmented
      updateSegments(segmented, tabs)
      if segmented.superview != container { container.addSubview(segmented) }
    }
    focusSearchIfNeeded()
  }

  private func focusSearchIfNeeded() {
    guard !didAutofocus, searchBar?.window != nil,
      let search = configuration["search"] as? [String: Any], search["autofocus"] as? Bool == true else { return }
    didAutofocus = true
    DispatchQueue.main.async { [weak self] in self?.searchBar?.searchTextField.becomeFirstResponder() }
  }

  private func makeSegments(_ config: [String: Any]) -> UISegmentedControl {
    let segmented = UISegmentedControl(); updateSegments(segmented, config); return segmented
  }

  private func updateSegments(_ segmented: UISegmentedControl, _ config: [String: Any]) {
    let titles = config["titles"] as? [String] ?? []
    if segmented.numberOfSegments != titles.count || titles.enumerated().contains(where: { segmented.titleForSegment(at: $0.offset) != $0.element }) {
      segmented.removeAllSegments()
      for (index, title) in titles.enumerated() { segmented.insertSegment(withTitle: title, at: index, animated: false) }
    }
    segmented.selectedSegmentIndex = config["selected"] as? Int ?? 0
    segmented.removeTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
    segmented.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
  }

  private func configureSegments() {
    let segmented = control as? UISegmentedControl ?? UISegmentedControl()
    updateSegments(segmented, configuration); mount(segmented)
  }
  @objc private func segmentChanged(_ sender: UISegmentedControl) { emit("selected", sender.selectedSegmentIndex) }

  private func configureRow() {
    let row = cell ?? UITableViewCell(style: .value1, reuseIdentifier: nil)
    cell = row
    if control == nil {
      let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
      tap.delegate = self
      row.addGestureRecognizer(tap)
    }
    var content = UIListContentConfiguration.valueCell()
    content.text = configuration["title"] as? String
    content.secondaryText = configuration["subtitle"] as? String
    content.textProperties.numberOfLines = 0
    content.secondaryTextProperties.numberOfLines = 0
    if let symbol = configuration["symbol"] as? String { content.image = UIImage(systemName: symbol) }
    row.contentConfiguration = content
    row.backgroundColor = .clear
    row.selectionStyle = .default
    if kind == "switch" {
      let toggle = row.accessoryView as? UISwitch ?? UISwitch()
      toggle.setOn(configuration["value"] as? Bool ?? false, animated: false)
      toggle.isEnabled = configuration["enabled"] as? Bool ?? true
      toggle.removeTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
      toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
      row.accessoryView = toggle
    } else if kind == "stepper" {
      let stepper = row.accessoryView as? UIStepper ?? UIStepper()
      stepper.minimumValue = number("min"); stepper.maximumValue = number("max", 100)
      stepper.stepValue = max(1, number("step", 1)); stepper.value = number("value")
      stepper.isEnabled = configuration["enabled"] as? Bool ?? true
      stepper.removeTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)
      stepper.addTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)
      row.accessoryView = stepper
      var valueContent = content
      valueContent.secondaryText = [configuration["subtitle"] as? String, configuration["displayValue"] as? String].compactMap { $0 }.joined(separator: "\n")
      row.contentConfiguration = valueContent
    } else {
      let detail = configuration["detail"] as? String ?? ""
      if !detail.isEmpty {
        let valueLabel = row.accessoryView as? UILabel ?? UILabel()
        valueLabel.text = detail; valueLabel.textColor = .secondaryLabel; valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.sizeToFit(); row.accessoryView = valueLabel
      } else { row.accessoryView = nil; row.accessoryType = configuration["disclosure"] as? Bool == false ? .none : .disclosureIndicator }
    }
    mount(row)
  }
  @objc private func rowTapped() {
    if kind == "switch", let toggle = cell?.accessoryView as? UISwitch, toggle.isEnabled {
      toggle.setOn(!toggle.isOn, animated: true); emit("changed", toggle.isOn)
    } else { emit("tap") }
  }
  @objc private func switchChanged(_ sender: UISwitch) { emit("changed", sender.isOn) }
  @objc private func stepperChanged(_ sender: UIStepper) { emit("changed", sender.value) }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    var target = touch.view
    while let view = target {
      if view is UIControl { return false }
      target = view.superview
    }
    return true
  }

  private func number(_ key: String, _ fallback: Double = 0) -> Double { (configuration[key] as? NSNumber)?.doubleValue ?? fallback }
  private func configureSlider() {
    let slider = control as? UISlider ?? UISlider()
    slider.minimumValue = Float(number("min")); slider.maximumValue = Float(number("max", 1)); slider.value = Float(number("value"))
    slider.isEnabled = configuration["enabled"] as? Bool ?? true
    if control == nil {
      slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
      slider.addTarget(self, action: #selector(sliderStarted(_:)), for: .touchDown)
      slider.addTarget(self, action: #selector(sliderEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    mount(slider)
  }
  @objc private func sliderChanged(_ sender: UISlider) {
    let divisions = number("divisions")
    if divisions > 0 {
      let step = (sender.maximumValue - sender.minimumValue) / Float(divisions)
      if step > 0 { sender.value = sender.minimumValue + round((sender.value - sender.minimumValue) / step) * step }
    }
    emit("changed", Double(sender.value))
  }
  @objc private func sliderStarted(_ sender: UISlider) { emit("started", Double(sender.value)) }
  @objc private func sliderEnded(_ sender: UISlider) { emit("ended", Double(sender.value)) }

  private func configureTextField() {
    if configuration["multiline"] as? Bool == true {
      let field = textView ?? UITextView(); textView = field; field.delegate = self
      field.font = .preferredFont(forTextStyle: .body); field.backgroundColor = .secondarySystemGroupedBackground
      field.layer.cornerRadius = 12; field.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
      field.isEditable = configuration["readOnly"] as? Bool != true && configuration["enabled"] as? Bool != false
      if field.text != configuration["text"] as? String { field.text = configuration["text"] as? String ?? "" }
      let placeholder = label ?? UILabel(); label = placeholder
      placeholder.text = configuration["placeholder"] as? String; placeholder.textColor = .placeholderText
      placeholder.font = field.font; placeholder.numberOfLines = 0; placeholder.isUserInteractionEnabled = false
      placeholder.isHidden = !field.text.isEmpty
      if placeholder.superview == nil { field.addSubview(placeholder) }
      mount(field); focusTextIfNeeded(); return
    }
    let field = textField ?? UITextField()
    textField = field; field.delegate = self
    field.borderStyle = .roundedRect
    field.placeholder = configuration["placeholder"] as? String
    field.isSecureTextEntry = configuration["secure"] as? Bool ?? false
    field.isEnabled = configuration["enabled"] as? Bool ?? true
    field.font = .preferredFont(forTextStyle: .body)
    field.returnKeyType = .done
    if field.text != configuration["text"] as? String { field.text = configuration["text"] as? String ?? "" }
    if configuration["number"] as? Bool == true { field.keyboardType = .decimalPad }
    else if configuration["email"] as? Bool == true { field.keyboardType = .emailAddress }
    else if configuration["url"] as? Bool == true { field.keyboardType = .URL }
    else { field.keyboardType = .default }
    field.autocorrectionType = configuration["autocorrect"] as? Bool == false ? .no : .default
    if let symbol = configuration["prefixSymbol"] as? String {
      let image = UIImageView(image: UIImage(systemName: symbol)); image.contentMode = .scaleAspectFit
      image.tintColor = .secondaryLabel; image.frame = CGRect(x: 12, y: 8, width: 22, height: 24)
      let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 40)); accessory.addSubview(image)
      field.leftView = accessory; field.leftViewMode = .always
    }
    let accessories = configuration["accessories"] as? [[String: Any]] ?? []
    if !accessories.isEmpty {
      let stack = UIStackView(); stack.axis = .horizontal
      for item in accessories {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: item["symbol"] as? String ?? "xmark.circle"), for: .normal)
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.emit("accessory", item["index"]) }, for: .touchUpInside)
        stack.addArrangedSubview(button)
      }
      stack.frame = CGRect(x: 0, y: 0, width: CGFloat(accessories.count * 40), height: 40)
      field.rightView = stack; field.rightViewMode = .always
    } else { field.rightView = nil }
    if control == nil { field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged) }
    mount(field)
    focusTextIfNeeded()
  }
  private func focusTextIfNeeded() {
    guard let input = textView as UIView? ?? textField, input.window != nil else { return }
    if !didAutofocus && configuration["autofocus"] as? Bool == true {
      didAutofocus = true
      DispatchQueue.main.async { [weak input] in input?.becomeFirstResponder() }
    } else if configuration["focus"] as? Bool == true && !input.isFirstResponder { input.becomeFirstResponder() }
  }
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    if configuration["readOnly"] as? Bool == true { emit("tap"); return false }
    return true
  }
  func textViewDidChange(_ textView: UITextView) { label?.isHidden = !textView.text.isEmpty; emit("changed", textView.text ?? "") }
  func textViewDidBeginEditing(_ textView: UITextView) { emit("focus", true) }
  func textViewDidEndEditing(_ textView: UITextView) { emit("focus", false) }
  @objc private func textChanged(_ sender: UITextField) { emit("changed", sender.text ?? "") }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool { emit("submitted", textField.text ?? ""); textField.resignFirstResponder(); return true }
  func textFieldDidBeginEditing(_ textField: UITextField) { emit("focus", true) }
  func textFieldDidEndEditing(_ textField: UITextField) { emit("focus", false) }
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { emit("searchChanged", searchText) }
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { emit("searchSubmitted", searchBar.text ?? ""); searchBar.resignFirstResponder() }

  private func layout() {
    let bounds = container.bounds
    if kind == "navigation" {
      navigationBar?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 56)
      segments?.frame = CGRect(x: 16, y: 60, width: max(0, bounds.width - 32), height: 32)
      focusSearchIfNeeded()
    } else if kind == "button" { control?.frame = bounds.insetBy(dx: 4, dy: 4) }
    else if kind == "slider" { control?.frame = bounds.insetBy(dx: 16, dy: 0) }
    else { control?.frame = bounds }
    if kind == "textfield" { focusTextIfNeeded() }
    if let textView {
      label?.frame = CGRect(x: 12, y: 12, width: max(0, textView.bounds.width - 24), height: 48)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }
}

extension UIColor {
  convenience init(argb: UInt32) {
    self.init(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255,
      blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

/// Native modal presentation is independent of Flutter's painted dialog layer.
final class NativeIOSPresentations: NSObject {
  private let channel: FlutterMethodChannel
  private var controllers: [Int: UIViewController] = [:]
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "simple_live/native_presentations", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, let config = call.arguments as? [String: Any], let id = config["id"] as? Int else { result(nil); return }
      switch call.method {
      case "pickTime": self.pickTime(config, result: result)
      case "present": self.present(id, config); result(nil)
      case "dismiss":
        let controller = self.controllers.removeValue(forKey: id)
        controller?.dismiss(animated: true); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  private func event(_ id: Int, key: String, value: Any? = nil, fields: [String]? = nil) {
    channel.invokeMethod("event", arguments: ["id": id, "key": key, "value": value ?? NSNull(), "fields": fields ?? []])
  }
  private func presenter() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }.first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
  private func pickTime(_ config: [String: Any], result: @escaping FlutterResult) {
    guard let parent = presenter() else { result(nil); return }
    let picker = NativeTimePickerController()
    picker.hour = config["hour"] as? Int ?? 0; picker.minute = config["minute"] as? Int ?? 0
    picker.onFinish = result
    let navigation = UINavigationController(rootViewController: picker)
    navigation.modalPresentationStyle = .pageSheet
    navigation.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    navigation.sheetPresentationController?.detents = [.medium()]
    navigation.sheetPresentationController?.prefersGrabberVisible = true
    navigation.presentationController?.delegate = picker
    parent.present(navigation, animated: true)
  }
  private func present(_ id: Int, _ config: [String: Any]) {
    if let existing = controllers[id] {
      if let sheet = (existing as? UINavigationController)?.viewControllers.first as? NativeFormSheet {
        sheet.configure(config)
      }
      return
    }
    guard let parent = presenter() else { return }
    let controller: UIViewController
    if config["style"] as? String == "alert" {
      let alert = UIAlertController(title: config["title"] as? String, message: config["message"] as? String, preferredStyle: .alert)
      for field in config["fields"] as? [[String: Any]] ?? [] {
        alert.addTextField { input in
          input.text = field["text"] as? String; input.placeholder = field["placeholder"] as? String
          input.isSecureTextEntry = field["secure"] as? Bool ?? false
          input.isUserInteractionEnabled = field["readOnly"] as? Bool != true
          if field["number"] as? Bool == true { input.keyboardType = .decimalPad }
        }
      }
      for action in config["actions"] as? [[String: Any]] ?? [] {
        let button = UIAlertAction(title: action["title"] as? String,
          style: action["cancel"] as? Bool == true ? .cancel : .default) { [weak self, weak alert] _ in
            let fields = alert?.textFields?.map { $0.text ?? "" } ?? []
            // Complete after dismissal, so validation can present a fresh alert.
            alert?.dismiss(animated: true) {
              self?.controllers.removeValue(forKey: id)
              self?.event(id, key: action["key"] as? String ?? "dismiss", fields: fields)
            }
          }
        button.isEnabled = action["enabled"] as? Bool ?? true
        alert.addAction(button)
      }
      if alert.actions.isEmpty { alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in self?.event(id, key: "dismiss") }) }
      controller = alert
    } else {
      let sheet = NativeFormSheet()
      sheet.configure(config)
      sheet.onEvent = { [weak self] key, value in self?.event(id, key: key, value: value) }
      sheet.onDismiss = { [weak self] in self?.controllers.removeValue(forKey: id); self?.event(id, key: "dismiss") }
      let navigation = UINavigationController(rootViewController: sheet)
      navigation.modalPresentationStyle = .pageSheet
      if let presentation = navigation.sheetPresentationController {
        presentation.detents = [.medium(), .large()]
        presentation.prefersGrabberVisible = true
        presentation.prefersScrollingExpandsWhenScrolledToEdge = true
        presentation.delegate = sheet
      }
      controller = navigation
    }
    controller.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    if let tint = (config["tint"] as? NSNumber)?.uint32Value { controller.view.tintColor = UIColor(argb: tint) }
    controllers[id] = controller
    parent.present(controller, animated: true)
  }
}

private final class NativeFormSheet: UITableViewController, UISheetPresentationControllerDelegate, UITextViewDelegate {
  var onEvent: ((String, Any?) -> Void)?
  var onDismiss: (() -> Void)?
  private var rows: [[String: Any]] = []
  private var settings: [String: Any] = [:]
  init() { super.init(style: .insetGrouped) }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  func configure(_ config: [String: Any]) {
    let oldRows = rows
    settings = config; rows = config["rows"] as? [[String: Any]] ?? []
    title = config["title"] as? String
    if isViewLoaded && !(oldRows as NSArray).isEqual(to: rows) &&
      view.findFirstResponder() == nil && !view.hasTrackingControl() { tableView.reloadData() }
  }
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 56
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
      guard let self else { return }
      self.dismiss(animated: true) { [weak self] in self?.onDismiss?() }
    })
  }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = rows[indexPath.row]
    let kind = row["kind"] as? String ?? "text"
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
    content.text = row["title"] as? String; content.secondaryText = row["subtitle"] as? String
    content.textProperties.numberOfLines = 0; content.secondaryTextProperties.numberOfLines = 0
    if let symbol = row["symbol"] as? String { content.image = UIImage(systemName: symbol) }
    cell.contentConfiguration = content
    cell.selectionStyle = kind == "text" ? .none : .default
    let key = row["key"] as? String ?? ""
    switch kind {
    case "switch":
      let toggle = UISwitch(); toggle.isOn = row["value"] as? Bool ?? false
      toggle.isEnabled = row["enabled"] as? Bool ?? true
      toggle.addAction(UIAction { [weak self, weak toggle] _ in self?.onEvent?(key, toggle?.isOn) }, for: .valueChanged)
      cell.accessoryView = toggle
    case "stepper":
      let stepper = UIStepper(); stepper.minimumValue = (row["min"] as? NSNumber)?.doubleValue ?? 0
      stepper.maximumValue = (row["max"] as? NSNumber)?.doubleValue ?? 100
      stepper.stepValue = (row["step"] as? NSNumber)?.doubleValue ?? 1
      stepper.value = (row["value"] as? NSNumber)?.doubleValue ?? 0
      stepper.addAction(UIAction { [weak self, weak stepper] _ in self?.onEvent?(key, stepper?.value) }, for: .valueChanged)
      cell.accessoryView = stepper
      content.secondaryText = [row["subtitle"] as? String, row["detail"] as? String].compactMap { $0 }.joined(separator: "\n")
      cell.contentConfiguration = content
    case "check", "radio":
      cell.accessoryType = (row[kind == "check" ? "value" : "selected"] as? Bool ?? false) ? .checkmark : .none
    case "slider", "textfield":
      let input: UIView
      if kind == "slider" {
        let slider = UISlider()
        slider.minimumValue = (row["min"] as? NSNumber)?.floatValue ?? 0; slider.maximumValue = (row["max"] as? NSNumber)?.floatValue ?? 1
        slider.value = (row["value"] as? NSNumber)?.floatValue ?? 0
        slider.addAction(UIAction { [weak self, weak slider] _ in
          guard let slider else { return }
          if let divisions = (row["divisions"] as? NSNumber)?.floatValue, divisions > 0 {
            let step = (slider.maximumValue - slider.minimumValue) / divisions
            if step > 0 { slider.value = slider.minimumValue + round((slider.value - slider.minimumValue) / step) * step }
          }
          self?.onEvent?(key, Double(slider.value))
        }, for: .valueChanged)
        input = slider
      } else if row["multiline"] as? Bool == true {
        let field = UITextView(); field.text = row["text"] as? String ?? ""
        field.font = .preferredFont(forTextStyle: .body); field.delegate = self; field.accessibilityIdentifier = key
        field.isEditable = row["readOnly"] as? Bool != true && row["enabled"] as? Bool != false
        input = field
      } else {
        let field = UITextField(); field.borderStyle = .roundedRect
        field.text = row["text"] as? String; field.placeholder = row["title"] as? String
        field.isSecureTextEntry = row["secure"] as? Bool ?? false
        field.isEnabled = row["enabled"] as? Bool ?? true
        field.addAction(UIAction { [weak self, weak field] _ in self?.onEvent?(key, field?.text ?? "") }, for: .editingChanged)
        input = field
      }
      cell.contentConfiguration = nil; input.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(input)
      NSLayoutConstraint.activate([input.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
        input.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
        input.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
        input.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
        input.heightAnchor.constraint(greaterThanOrEqualToConstant: row["multiline"] as? Bool == true ? 140 : 36)])
    default:
      if let detail = row["detail"] as? String, !detail.isEmpty {
        let label = UILabel(); label.text = detail; label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel; label.sizeToFit(); cell.accessoryView = label
      } else if row["disclosure"] as? Bool == true { cell.accessoryType = .disclosureIndicator }
    }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let row = rows[indexPath.row]; let kind = row["kind"] as? String ?? "text"
    if ["text", "slider", "textfield", "stepper"].contains(kind) { return }
    let value: Any? = ["check", "switch"].contains(kind) ? !(row["value"] as? Bool ?? false) : nil
    onEvent?(row["key"] as? String ?? "", value)
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { onDismiss?() }
  func textViewDidChange(_ textView: UITextView) { onEvent?(textView.accessibilityIdentifier ?? "", textView.text ?? "") }
}

private extension UIView {
  func hasTrackingControl() -> Bool {
    if let control = self as? UIControl, control.isTracking { return true }
    return subviews.contains { $0.hasTrackingControl() }
  }
  func findFirstResponder() -> UIView? {
    if isFirstResponder { return self }
    for child in subviews { if let responder = child.findFirstResponder() { return responder } }
    return nil
  }
}

private final class NativeTimePickerController: UIViewController, UIAdaptivePresentationControllerDelegate {
  var hour = 0; var minute = 0
  var onFinish: FlutterResult?
  private let picker = UIDatePicker()
  override func viewDidLoad() {
    super.viewDidLoad(); title = "选择时间"; view.backgroundColor = .systemBackground
    picker.datePickerMode = .time; picker.preferredDatePickerStyle = .wheels
    picker.date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute)) ?? Date()
    picker.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(picker)
    NSLayoutConstraint.activate([picker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      picker.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
      picker.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
      picker.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor)])
    navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.finish(nil) })
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
      guard let self else { return }
      let time = Calendar.current.dateComponents([.hour, .minute], from: self.picker.date)
      self.finish(["hour": time.hour ?? 0, "minute": time.minute ?? 0])
    })
  }
  private func finish(_ value: Any?) {
    let callback = onFinish; onFinish = nil
    dismiss(animated: true) { callback?(value) }
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onFinish?(nil); onFinish = nil
  }
}
