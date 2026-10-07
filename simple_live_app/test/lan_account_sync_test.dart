import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:shelf/shelf.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/platform_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

class MemoryStorage extends LocalStorageService {
  final values = <dynamic, dynamic>{};
  @override
  Future<void> setValue<T>(dynamic key, T value) async {
    values[key] = value;
  }

  @override
  T getValue<T>(dynamic key, T defaultValue) => values[key] as T? ?? defaultValue;
}

class QuietPlatformService extends PlatformService {
  // Skip production account/network initialization in this router test.
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStorage storage;
  late PlatformService platform;
  late KuaishouAccountService kuaishou;
  late SyncService sync;
  setUp(() {
    Get.testMode = true;
    storage = MemoryStorage();
    Get.put<LocalStorageService>(storage);
    platform = Get.put<PlatformService>(QuietPlatformService());
    kuaishou = Get.put(KuaishouAccountService());
    sync = SyncService(); // Use the actual router without opening LAN sockets.
  });
  tearDown(() {
    Get.reset();
  });

  Future<Map<String, dynamic>> send(String account, dynamic body) async {
    final response = await sync.createRouter().call(Request('POST', Uri.parse('http://localhost/sync/account/$account'),
        body: jsonEncode(body), headers: {'content-type': 'application/json'}));
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  Future<void> mountDialogs(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(), navigatorObservers: [FlutterSmartDialog.observer], home: const Scaffold()));
  }

  Future<void> finishToasts(WidgetTester tester) async {
    final dismissed = SmartDialog.dismiss(status: SmartStatus.allToast);
    await tester.pumpAndSettle();
    await dismissed;
  }

  testWidgets('June cookie-only Douyu payload replaces stale refresh credentials', (tester) async {
    await mountDialogs(tester);
    await platform.importDouyuAccount('old', did: 'old-device', ltp0: 'old-token');
    expect((await send('douyu', {'cookie': 'dy_did=new-device; token=new'}))['status'], isTrue);
    expect(platform.douyuCookie.value, 'dy_did=new-device; token=new');
    expect(platform.dy_did, isEmpty);
    expect(platform.dyLtp0, isEmpty);
    expect(storage.values[LocalStorageService.kDouyuCookie], platform.douyuCookie.value);
    expect(storage.values[LocalStorageService.kDouyuLTP0], isEmpty);
    await finishToasts(tester);
  });

  testWidgets('fork payload preserves optional Douyu refresh credentials', (tester) async {
    await mountDialogs(tester);
    expect((await send('douyu', {'cookie': 'dy_did=test', 'dy_did': 'test', 'ltp0': 'refresh'}))['status'], isTrue);
    expect(platform.dy_did, 'test');
    expect(platform.dyLtp0, 'refresh');
    await finishToasts(tester);
  });

  testWidgets('phone-to-phone Kuaishou sync persists cookie, kwfv1 and expiry', (tester) async {
    await mountDialogs(tester);
    const expiry = 1900000000000;
    expect(
        (await send(
            'kuaishou', {'cookie': 'session=example', 'kww': 'kwfv1-example', 'cookieExpiresAt': expiry}))['status'],
        isTrue);
    expect(kuaishou.cookie, 'session=example');
    expect(kuaishou.kww, 'kwfv1-example');
    expect(kuaishou.cookieExpiresAtMs.value, expiry);
    expect(storage.values[LocalStorageService.kKuaishouCookieExpiresAt], expiry);
    await finishToasts(tester);
  });

  testWidgets('invalid payloads do not overwrite a configured account', (tester) async {
    await mountDialogs(tester);
    await kuaishou.setCookie('saved', kww: 'saved-kww');
    expect((await send('kuaishou', {'cookie': ''}))['status'], isFalse);
    expect((await send('kuaishou', {'cookie': 'changed', 'cookieExpiresAt': 'invalid'}))['status'], isFalse);
    expect((await send('douyu', []))['status'], isFalse);
    expect(kuaishou.cookie, 'saved');
    expect(kuaishou.kww, 'saved-kww');
  });
}
