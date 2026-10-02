# Native iOS controls and Liquid Glass

The main Flutter client (`simple_live_app`) uses one appearance system across
home, categories, follows, search, profile, account/login, history, settings,
sync, diagnostics and the live player. The separate Android TV client is not
part of this iOS redesign.

- `GlassAppBar` embeds UINavigationBar with real UIBarButtonItems and UIMenu.
- Buttons use UIButton.Configuration.glass() / prominentGlass() on iOS 26.
  Search and tabs use UISearchBar / UISegmentedControl; settings use native
  UITableViewCell, UISwitch, UIStepper and UISlider. Form fields use UITextField
  or UITextView. UIKit owns control input, animations and accessibility.
- Standard confirmations and text prompts use UIAlertController. Supported
  option/form sheets use UITableViewController in a native navigation controller
  and UISheetPresentationController. Time selection uses UIDatePicker.
- `LiquidGlassSurface` embeds `UIVisualEffectView` with `UIGlassEffect(.regular)`
  on iOS 26. The existing native `UITabBarController` remains the bottom dock.
- Earlier iOS versions use `UIBlurEffect(.systemMaterial)`; other platforms use
  a clipped Flutter backdrop blur. These are compatibility renderings, not the
  iOS 26 material.
- Native material respects Reduce Transparency and Increase Contrast. Flutter
  fallback disables blur in high contrast. Custom glass backgrounds ignore input;
  native controls own their input while Flutter retains business callbacks.
- Settings and content cards use opaque grouped surfaces for readability and
  to avoid creating a native view for every scrolling item. Controls, sheets,
  dialogs and player buttons use system presentation/material. Player buttons
  do not have a second glass pane stacked behind them. Theme colors remain
  configurable; UIKit controls use the system font.

Complex content such as QR codes, account web views, image/avatar list tiles and
custom player panels retains Flutter composition with native controls/material.
This is a Flutter content app with native iOS controls, not a complete UIKit rewrite.

## Verification

Run from `simple_live_app` with the Flutter version in `pubspec.yaml`:

```sh
flutter pub get
flutter test test/liquid_glass_ui_test.dart test/native_ios_controls_test.dart test/native_dock_gesture_test.dart test/follow_user_controller_test.dart
dart analyze lib test/liquid_glass_ui_test.dart
```

The iOS build workflow includes these regression tests and requires an iOS 26
SDK. Build with Xcode 26 or newer for the native button configurations and
UIGlassEffect. Earlier iOS releases use the corresponding older system controls.

Widget tests mock the iOS platform-view channel; they verify Flutter layout,
appearance updates, typed menus/search selection, native input and route results,
not UIKit rendering. Before release,
validate on an iOS 26 device: light/dark appearance, Reduce Transparency,
Increase Contrast, sheet keyboard avoidance, back gestures, platform-view
clipping, and live video under the glass toolbars. Windows preview images show
the compatibility material only. Actions compiles the Swift implementation;
device rendering cannot be verified with the Windows toolchain.
