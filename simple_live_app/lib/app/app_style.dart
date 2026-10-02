import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AppColors {
  static ColorScheme lightColorScheme = ColorScheme.fromSeed(
    // primarySwatch: Colors.blue,
    seedColor: const Color(0xff3498db),
    brightness: Brightness.light,
  );
  static ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff3498db),
    brightness: Brightness.dark,
  );

  static const Color black333 = Color(0xFF333333);
}

class AppStyle {
  static ThemeData light({String? fontFamily, ColorScheme? colorScheme}) =>
      _theme(Brightness.light, fontFamily, colorScheme ?? AppColors.lightColorScheme);

  static ThemeData darkTheme({String? fontFamily, ColorScheme? colorScheme}) =>
      _theme(Brightness.dark, fontFamily, colorScheme ?? AppColors.darkColorScheme);

  static ThemeData _theme(Brightness brightness, String? fontFamily, ColorScheme scheme) {
    final dark = brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
    final background = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final line = foreground.withAlpha(25);
    final colors = scheme.copyWith(
      surface: surface,
      onSurface: foreground,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EF),
      surfaceContainerHigh: dark ? const Color(0xFF323236) : const Color(0xFFE3E3EB),
      surfaceContainerHighest: dark ? const Color(0xFF3A3A3C) : const Color(0xFFDCDCE4),
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
    final theme = ThemeData(
      brightness: brightness,
      colorScheme: colors,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: line,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        foregroundColor: foreground,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w600, color: foreground),
        systemOverlayStyle: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(elevation: 0, color: surface, surfaceTintColor: Colors.transparent, shape: rounded),
      dialogTheme: DialogThemeData(
        backgroundColor: surface.withAlpha(245),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        clipBehavior: Clip.antiAlias,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface.withAlpha(245),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: rounded,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colors.primary,
        unselectedLabelColor: foreground.withAlpha(160),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colors.primary.withAlpha(dark ? 45 : 22),
          borderRadius: BorderRadius.circular(22),
        ),
        indicatorColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: foreground.withAlpha(dark ? 16 : 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: colors.primary, width: 1.5)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        iconColor: colors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 0.5, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: const StadiumBorder(),
        minimumSize: const Size(44, 44),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      )),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(44, 44),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(44, 44),
        side: BorderSide(color: line),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(44, 44),
      )),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      )),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: colors.primary.withAlpha(28),
        selectedIconTheme: IconThemeData(color: colors.primary),
        unselectedIconTheme: IconThemeData(color: foreground.withAlpha(170)),
      ),
      sliderTheme: SliderThemeData(trackHeight: 6, activeTrackColor: colors.primary, inactiveTrackColor: line),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      }),
    );
  }

  static const vGap4 = SizedBox(
    height: 4,
  );
  static const vGap8 = SizedBox(
    height: 8,
  );
  static const vGap12 = SizedBox(
    height: 12,
  );
  static const vGap24 = SizedBox(
    height: 24,
  );
  static const vGap32 = SizedBox(
    height: 32,
  );
  static const vGap48 = SizedBox(
    height: 48,
  );

  static const hGap4 = SizedBox(
    width: 4,
  );
  static const hGap8 = SizedBox(
    width: 8,
  );
  static const hGap12 = SizedBox(
    width: 12,
  );
  static const hGap16 = SizedBox(
    width: 16,
  );

  static const hGap24 = SizedBox(
    width: 24,
  );
  static const hGap32 = SizedBox(
    width: 32,
  );
  static const hGap48 = SizedBox(
    width: 48,
  );

  static const edgeInsetsH4 = EdgeInsets.symmetric(horizontal: 4);
  static const edgeInsetsH8 = EdgeInsets.symmetric(horizontal: 8);
  static const edgeInsetsH12 = EdgeInsets.symmetric(horizontal: 12);
  static const edgeInsetsH16 = EdgeInsets.symmetric(horizontal: 16);
  static const edgeInsetsH20 = EdgeInsets.symmetric(horizontal: 20);
  static const edgeInsetsH24 = EdgeInsets.symmetric(horizontal: 24);

  static const edgeInsetsV4 = EdgeInsets.symmetric(vertical: 4);
  static const edgeInsetsV8 = EdgeInsets.symmetric(vertical: 8);
  static const edgeInsetsV12 = EdgeInsets.symmetric(vertical: 12);
  static const edgeInsetsV24 = EdgeInsets.symmetric(vertical: 24);

  static const edgeInsetsA4 = EdgeInsets.all(4);
  static const edgeInsetsA8 = EdgeInsets.all(8);
  static const edgeInsetsA12 = EdgeInsets.all(12);
  static const edgeInsetsA16 = EdgeInsets.all(16);
  static const edgeInsetsA20 = EdgeInsets.all(20);
  static const edgeInsetsA24 = EdgeInsets.all(24);

  static const edgeInsetsR4 = EdgeInsets.only(right: 4);
  static const edgeInsetsR8 = EdgeInsets.only(right: 8);
  static const edgeInsetsR12 = EdgeInsets.only(right: 12);
  static const edgeInsetsR16 = EdgeInsets.only(right: 16);
  static const edgeInsetsR20 = EdgeInsets.only(right: 20);
  static const edgeInsetsR24 = EdgeInsets.only(right: 24);

  static const edgeInsetsL4 = EdgeInsets.only(left: 4);
  static const edgeInsetsL8 = EdgeInsets.only(left: 8);
  static const edgeInsetsL12 = EdgeInsets.only(left: 12);
  static const edgeInsetsL16 = EdgeInsets.only(left: 16);
  static const edgeInsetsL20 = EdgeInsets.only(left: 20);
  static const edgeInsetsL24 = EdgeInsets.only(left: 24);

  static const edgeInsetsT4 = EdgeInsets.only(top: 4);
  static const edgeInsetsT8 = EdgeInsets.only(top: 8);
  static const edgeInsetsT12 = EdgeInsets.only(top: 12);
  static const edgeInsetsT24 = EdgeInsets.only(top: 24);

  static const edgeInsetsB4 = EdgeInsets.only(bottom: 4);
  static const edgeInsetsB8 = EdgeInsets.only(bottom: 8);
  static const edgeInsetsB12 = EdgeInsets.only(bottom: 12);
  static const edgeInsetsB24 = EdgeInsets.only(bottom: 24);

  static BorderRadius radius4 = BorderRadius.circular(4);
  static BorderRadius radius8 = BorderRadius.circular(8);
  static BorderRadius radius12 = BorderRadius.circular(12);
  static BorderRadius radius24 = BorderRadius.circular(24);
  static BorderRadius radius32 = BorderRadius.circular(32);
  static BorderRadius radius48 = BorderRadius.circular(48);

  /// 顶部状态栏的高度
  static double get statusBarHeight => MediaQuery.of(Get.context!).padding.top;

  /// 底部导航条的高度
  static double get bottomBarHeight => MediaQuery.of(Get.context!).padding.bottom;

  static Divider get divider => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: Colors.grey.withAlpha(25),
      );
}
