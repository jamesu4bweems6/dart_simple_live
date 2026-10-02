import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/widgets/liquid_glass_dock.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final platformCalls = <MethodCall>[];
  final nativeChannels = <MethodChannel>[];
  int? viewId;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    platformCalls.clear();
    nativeChannels.clear();
    viewId = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      platformCalls.add(call);
      if (call.method == 'create') {
        viewId = (call.arguments as Map)['id'] as int;
        final channel = MethodChannel('simple_live/native_dock/$viewId');
        nativeChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });

  tearDown(() {
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });

  bool wasAccepted() => platformCalls.any(
        (call) => call.method == 'acceptGesture' && (call.arguments as Map)['id'] == viewId,
      );

  testWidgets('phone taps reach UIKit through the global mouse back-button handler', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: RawGestureDetector(
        gestures: {
          FourthButtonTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<FourthButtonTapGestureRecognizer>(
            FourthButtonTapGestureRecognizer.new,
            (recognizer) => recognizer.onTapDown = (_) => backCount++,
          ),
        },
        child: const Center(child: SizedBox(
          width: 300,
          height: 100,
          child: UiKitView(viewType: 'test/native-tabs'),
        )),
      ),
    ));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(UiKitView)));
    await tester.pump();
    expect(wasAccepted(), isTrue);
    expect(backCount, 0);

    // The actual mouse side button must still trigger desktop navigation.
    final mouse = await tester.startGesture(
      tester.getCenter(find.byType(UiKitView)),
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.up();
    await tester.pump();
    expect(backCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('dock owns touch gestures and native selections switch every page', (tester) async {
    final items = Constant.allHomePages.values.toList();
    var selected = 0;
    var parentTaps = 0;
    final selections = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) => Scaffold(
        body: Text('page:${items[selected].title}'),
        bottomNavigationBar: GestureDetector(
          onTap: () => parentTaps++,
          child: LiquidGlassDock(
            items: items,
            selectedIndex: selected,
            onSelected: (index) => setState(() {
              selections.add(index);
              selected = index;
            }),
          ),
        ),
      )),
    ));
    await tester.pump();
    final touch = await tester.startGesture(tester.getCenter(find.byType(UiKitView)));
    await tester.pump();
    // Acceptance on pointer-down is needed for UIKit's glass drag interaction.
    expect(wasAccepted(), isTrue);
    await touch.up();
    await tester.pump();
    expect(parentTaps, 0);

    for (final index in [1, 2, 3, 0, 0]) {
      final delivered = Completer<void>();
      messenger.handlePlatformMessage(
        'simple_live/native_dock/$viewId',
        const StandardMethodCodec().encodeMethodCall(MethodCall('onSelected', index)),
        (_) => delivered.complete(),
      );
      await delivered.future;
      await tester.pump();
      expect(find.text('page:${items[index].title}'), findsOneWidget);
    }
    expect(selections, [1, 2, 3, 0, 0]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
