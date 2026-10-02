// CI entry point: runs the real app and checks the UIKit bridge on a simulator.
// The release IPA continues to use lib/main.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/main.dart' as app;
import 'package:simple_live_app/modules/indexed/indexed_controller.dart';

const _native = MethodChannel('simple_live/native_dock/0');

Future<Map<Object?, Object?>> _waitForState(bool Function(Map<Object?, Object?>) matches) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      final state = await _native.invokeMapMethod<Object?, Object?>('getState');
      if (state != null && matches(state)) return state;
    } on MissingPluginException {
      // The first platform view is still being created.
    }
  }
  throw StateError('The native tab bar did not reach the expected state.');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final report = File('${(await getApplicationDocumentsDirectory()).path}/native-dock-preview.json');
  try {
    await app.main([]);
    // Avoid the first-run dialog in this preview build only.
    AppSettingsController.instance.firstRun = false;
    final initial = await _waitForState((state) => state['attached'] == true);
    if (initial['nativeController'] != 'UITabBarController' ||
        int.parse((initial['systemVersion'] as String).split('.').first) < 26) {
      throw StateError('Preview requires the system UITabBarController on iOS 26+.');
    }

    final controller = Get.find<IndexedController>();
    final followIndex = controller.items.indexWhere((item) => item.index == 1);
    controller.setIndex(followIndex);
    await _waitForState((state) => state['selectedIndex'] == followIndex);
    controller.setIndex(controller.items.indexWhere((item) => item.index == 0));

    final settings = AppSettingsController.instance;
    settings.themeMode.value = ThemeMode.dark.index;
    await _waitForState((state) => state['darkMode'] == true);
    settings.themeMode.value = ThemeMode.system.index;
    final finalState = await _waitForState(
      (state) => state['selectedIndex'] == controller.index.value && state['darkMode'] == false,
    );
    await report.writeAsString(jsonEncode({'status': 'success', 'nativeState': finalState}));
  } catch (error, stack) {
    await report.writeAsString(jsonEncode({'status': 'failure', 'error': '$error', 'stack': '$stack'}));
    rethrow;
  }
}
