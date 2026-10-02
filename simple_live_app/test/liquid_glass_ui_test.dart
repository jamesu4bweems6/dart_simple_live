import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/widgets/glass_app_bar.dart';
import 'package:simple_live_app/widgets/glass_dialog.dart';
import 'package:simple_live_app/widgets/glass_sheet.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native glass passes taps through and updates appearance in place', (tester) async {
    final configurations = <Map<Object?, Object?>>[];
    final channels = <MethodChannel>[];
    var creates = 0;
    var taps = 0;
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') {
        creates++;
        final arguments = call.arguments as Map;
        expect(arguments['viewType'], 'simple_live/native_liquid_glass_surface');
        final channel = MethodChannel('simple_live/native_glass/${arguments['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          configurations.add(Map<Object?, Object?>.from(call.arguments as Map));
          return null;
        });
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    Widget app(ThemeData theme) => MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
              body: Center(
                  child: LiquidGlassSurface(
            child: TextButton(onPressed: () => taps++, child: const Text('Tap')),
          ))),
        );
    await tester.pumpWidget(app(AppStyle.light()));
    await tester.pump();
    await tester.tap(find.text('Tap'));
    expect(taps, 1);
    expect(configurations.last['dark'], false);
    await tester.pumpWidget(app(AppStyle.darkTheme()));
    await tester.pump();
    expect(configurations.last['dark'], true);
    expect(creates, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final dark in [false, true]) {
    testWidgets('navigation, dialogs and sheets fit a small phone (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext pageContext;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppStyle.darkTheme() : AppStyle.light(),
        home: Builder(builder: (context) {
          pageContext = context;
          return Scaffold(
            appBar: GlassAppBar(title: const Text('Settings')),
            body: const GlassCard(child: ListTile(title: Text('Playback'))),
          );
        }),
      ));
      showDialog<void>(
          context: pageContext,
          builder: (context) => GlassAlertDialog(
                title: const Text('Account'),
                content: const TextField(decoration: InputDecoration(labelText: 'Name')),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
              ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      showGlassBottomSheet<void>(
          context: pageContext,
          builder: (context) => SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const ListTile(title: Text('Quality')),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ]),
              ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });
  }

  testWidgets('high contrast disables fallback blur', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(highContrast: true),
      child: const Scaffold(body: LiquidGlassSurface(child: Text('Readable'))),
    )));
    final blur = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(blur.enabled, isFalse);
    expect(find.byType(UiKitView), findsNothing);
  });

  testWidgets('sheet input and confirmation remain above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      theme: AppStyle.light(),
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold();
      }),
    ));
    final result = showGlassBottomSheet<String>(
      context: pageContext,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const TextField(decoration: InputDecoration(labelText: 'Account')),
          TextButton(onPressed: () => Navigator.pop(context, 'saved'), child: const Text('Save')),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.text('Save')).dy, lessThanOrEqualTo(340));
    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await result, 'saved');
  });
}
