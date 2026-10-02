import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/glass_app_bar.dart';
import 'package:simple_live_app/widgets/glass_dialog.dart';
import 'package:simple_live_app/widgets/glass_sheet.dart';
import 'package:simple_live_app/widgets/native_ios/native_buttons.dart';
import 'package:simple_live_app/widgets/native_ios/native_rows.dart';
import 'package:simple_live_app/widgets/native_ios/native_text_field.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final views = <int, Map<dynamic, dynamic>>{};
  final channels = <MethodChannel>[];
  final presentations = <MethodCall>[];
  const modalChannel = MethodChannel('simple_live/native_presentations');

  Future<void> event(int id, String name, dynamic value) async {
    final delivered = Completer<void>();
    messenger.handlePlatformMessage('simple_live/native_control/$id',
        const StandardMethodCodec().encodeMethodCall(MethodCall('event', {'name': name, 'value': value})), (response) {
      if (response != null) const StandardMethodCodec().decodeEnvelope(response);
      delivered.complete();
    });
    await delivered.future;
  }

  Future<void> modalEvent(Map<String, dynamic> event) async {
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
        modalChannel.name, const StandardMethodCodec().encodeMethodCall(MethodCall('event', event)), (response) {
      if (response != null) const StandardMethodCodec().decodeEnvelope(response);
      delivered.complete();
    });
    await delivered.future;
  }

  setUp(() {
    views.clear();
    channels.clear();
    presentations.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        expect(args['viewType'], 'simple_live/native_control');
        final id = args['id'] as int;
        views[id] =
            const StandardMessageCodec().decodeMessage(ByteData.sublistView(args['params'] as Uint8List)) as Map;
        final channel = MethodChannel('simple_live/native_control/$id');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'configure') views[id] = call.arguments as Map;
          return null;
        });
      }
      return null;
    });
    messenger.setMockMethodCallHandler(modalChannel, (call) async {
      presentations.add(call);
      return null;
    });
  });
  tearDown(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(modalChannel, null);
    Get.reset();
  });

  testWidgets('button and switch use UIKit views and preserve callbacks', (tester) async {
    var taps = 0;
    var selected = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => Column(children: [
                      NativeIconButton(onPressed: () => taps++, icon: const Icon(Icons.search)),
                      NativeSwitchListTile(
                          title: const Text('通知'),
                          value: selected,
                          onChanged: (value) => setState(() => selected = value)),
                    ])))));
    await tester.pump();
    final button = views.entries.singleWhere((entry) => entry.value['kind'] == 'button');
    final toggle = views.entries.singleWhere((entry) => entry.value['kind'] == 'switch');
    expect(button.value['symbol'], 'magnifyingglass');
    await event(button.key, 'tap', null);
    await event(toggle.key, 'changed', true);
    await tester.pump();
    expect(taps, 1);
    expect(selected, isTrue);
    expect(views[toggle.key]!['value'], isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native navigation updates reactive title and dispatches menu actions', (tester) async {
    final title = '关注'.obs;
    var action = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: GlassAppBar(title: Obx(() => Text(title.value)), actions: [
      PopupMenuButton<int>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) => action = value,
          itemBuilder: (_) => [const PopupMenuItem(value: 7, child: Text('刷新'))]),
    ]))));
    await tester.pump();
    final id = views.keys.single;
    expect(views[id]!['kind'], 'navigation');
    expect(views[id]!['title'], '关注');
    title.value = '直播';
    await tester.pump();
    expect(views[id]!['title'], '直播');
    final item = ((views[id]!['actions'] as List).single['menu'] as List).single;
    expect(item['id'], 'action:0');
    await tester.pump();
    await event(id, 'action', item['id']);
    expect(action, 7);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native text input synchronizes external controller and submission', (tester) async {
    final controller = TextEditingController(text: '旧值');
    String? submitted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NativeTextField(controller: controller, onSubmitted: (value) => submitted = value))));
    await tester.pump();
    final id = views.keys.single;
    await event(id, 'changed', '新值');
    await tester.pump();
    expect(controller.text, '新值');
    expect(views[id]!['text'], '新值');
    controller.text = '外部更新';
    await tester.pump();
    expect(views[id]!['text'], '外部更新');
    await event(id, 'submitted', '外部更新');
    expect(submitted, '外部更新');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native sheet retains original route results and reactive switches', (tester) async {
    late BuildContext page;
    final enabled = false.obs;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      page = context;
      return const Scaffold();
    })));
    final result = showGlassBottomSheet<String>(
        context: page,
        builder: (context) => Column(children: [
              Obx(() => NativeSwitchListTile(
                  title: const Text('弹幕'), value: enabled.value, onChanged: (value) => enabled.value = value)),
              NativeTextButton(onPressed: () => Navigator.of(page).pop('saved'), child: const Text('确定')),
            ]));
    await tester.pumpAndSettle();
    var config = presentations.lastWhere((call) => call.method == 'present').arguments as Map;
    expect(config['style'], 'sheet');
    expect(find.byType(UiKitView), findsNothing);
    var rows = config['rows'] as List;
    await modalEvent({'id': config['id'], 'key': rows.first['key'], 'value': true});
    await tester.pump();
    expect(enabled.value, isTrue);
    config = presentations.lastWhere((call) => call.method == 'present').arguments as Map;
    rows = config['rows'] as List;
    expect(rows.first['value'], isTrue);
    await modalEvent({'id': config['id'], 'key': rows.last['key']});
    await tester.pumpAndSettle();
    expect(await result, 'saved');
    expect(presentations.last.method, 'dismiss');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native alert writes fields before calling confirmation', (tester) async {
    final controller = TextEditingController();
    late BuildContext page;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      page = context;
      return const Scaffold();
    })));
    final result = showDialog<String>(
        context: page,
        builder: (context) => GlassAlertDialog(
                title: const Text('备注'),
                content: NativeTextField(controller: controller),
                actions: [
                  NativeTextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('确定'))
                ]));
    await tester.pumpAndSettle();
    final config = presentations.lastWhere((call) => call.method == 'present').arguments as Map;
    expect(config['style'], 'alert');
    await modalEvent({
      'id': config['id'],
      'key': (config['actions'] as List).single['key'],
      'fields': ['备注内容']
    });
    await tester.pumpAndSettle();
    expect(await result, '备注内容');
    expect(tester.takeException(), isNull);
    controller.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('search scope observes typed dropdown values and submits UIKit text', (tester) async {
    final scope = 0.obs;
    final controller = TextEditingController();
    String? submitted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: GlassAppBar(
                title: NativeTextField(
      controller: controller,
      onSubmitted: (value) => submitted = value,
      decoration: InputDecoration(
          prefixIcon: Row(children: [
        Obx(() => DropdownButton<int>(
              value: scope.value,
              onChanged: (value) => scope.value = value!,
              items: const [
                DropdownMenuItem(value: 0, child: Text('房间')),
                DropdownMenuItem(value: 1, child: Text('主播'))
              ],
            ))
      ])),
    )))));
    await tester.pump();
    final id = views.keys.single;
    expect(views[id]!['search']['scope'], 0);
    await event(id, 'action', 'scope:1');
    await tester.pump();
    expect(scope.value, 1);
    expect(views[id]!['search']['scope'], 1);
    await event(id, 'searchChanged', '直播');
    await tester.pump();
    expect(controller.text, '直播');
    await event(id, 'searchSubmitted', '直播');
    expect(submitted, '直播');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native option sheet handles a typed radio group and cancellation', (tester) async {
    late BuildContext page;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      page = context;
      return const Scaffold();
    })));
    final result = showGlassBottomSheet<int>(
        context: page,
        builder: (_) => RadioGroup<int>(
            groupValue: 1,
            onChanged: (value) => Navigator.of(page).pop(value),
            child: const Column(children: [
              NativeRadioListTile<int>(value: 1, title: Text('默认')),
              NativeRadioListTile<int>(value: 2, title: Text('高清')),
            ])));
    await tester.pumpAndSettle();
    final config = presentations.lastWhere((call) => call.method == 'present').arguments as Map;
    final rows = config['rows'] as List;
    expect(rows.first['selected'], isTrue);
    await modalEvent({'id': config['id'], 'key': rows.last['key']});
    await tester.pumpAndSettle();
    expect(await result, 2);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
