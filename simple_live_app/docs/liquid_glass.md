# Liquid Glass appearance

The main Flutter client (`simple_live_app`) uses one appearance system across
home, categories, follows, search, profile, account/login, history, settings,
sync, diagnostics and the live player. The separate Android TV client is not
part of this iOS redesign.

- `GlassAppBar` provides a system material background with existing route,
  search and tab actions.
- `LiquidGlassSurface` embeds `UIVisualEffectView` with `UIGlassEffect(.regular)`
  on iOS 26. The existing native `UITabBarController` remains the bottom dock.
- Earlier iOS versions use `UIBlurEffect(.systemMaterial)`; other platforms use
  a clipped Flutter backdrop blur. These are compatibility renderings, not the
  iOS 26 material.
- Native material respects Reduce Transparency and Increase Contrast. Flutter
  fallback disables blur in high contrast. Platform backgrounds ignore input;
  Flutter continues to own form, button, scroll and player gestures.
- Settings and content cards use opaque grouped surfaces for readability and
  to avoid creating a native view for every scrolling item. Controls, sheets,
  dialogs and player toolbars use glass. Theme colors and custom fonts remain
  configurable.

## Verification

Run from `simple_live_app` with the Flutter version in `pubspec.yaml`:

```sh
flutter pub get
flutter test test/liquid_glass_ui_test.dart test/native_dock_gesture_test.dart test/follow_user_controller_test.dart
dart analyze lib test/liquid_glass_ui_test.dart
```

The iOS build workflow includes these regression tests and requires an iOS 26
SDK. Build with Xcode 26 or newer to enable `UIGlassEffect`. A compiler guard
allows earlier development SDKs to use the older material.

Widget tests mock the iOS platform-view channel; they verify Flutter layout,
appearance updates and input routing, not UIKit rendering. Before release,
validate on an iOS 26 device: light/dark appearance, Reduce Transparency,
Increase Contrast, sheet keyboard avoidance, back gestures, platform-view
clipping, and live video under the glass toolbars. Windows preview images show
the compatibility material only. Swift compilation and device rendering cannot
be verified with the Windows toolchain.
