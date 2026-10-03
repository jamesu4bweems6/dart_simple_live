import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';

class NativeTabBar extends TabBar {
  const NativeTabBar(
      {super.key,
      required super.tabs,
      super.controller,
      super.padding,
      super.isScrollable,
      super.indicatorSize,
      super.labelPadding,
      super.tabAlignment,
      super.indicatorWeight,
      super.onTap,
      super.labelColor,
      super.unselectedLabelColor});

  @override
  State<TabBar> createState() => usesNativeIOS
      ? NativeWidgetState<TabBar>((context, tab) => (tab as NativeTabBar)._buildNative(context))
      : super.createState();

  String _title(Widget tab) =>
      tab is Tab ? tab.text ?? nativeText(nativeResolve(tab.child)) : nativeText(nativeResolve(tab));

  Widget _buildNative(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);
    // Titles such as "SC(n)" are built by an Obx. Resolve them for UIKit and
    // observe them, so the native segment title follows the reactive value.
    final reactive = tabs.any((tab) => (tab is Tab ? tab.child : tab) is Obx);
    Widget segments() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // A UiKitView fills its constraints. Inside a Column (the live room
          // message area) that height is unbounded, and release builds pass
          // the infinite frame to UIKit, which terminates the app.
          child: SizedBox(
            height: 32,
            child: NativeControl(
                kind: 'segments',
                configuration: {
                  'titles': tabs.map(_title).toList(),
                  'selected': tabController.index,
                },
                onEvent: (event, value) {
                  if (event == 'selected' && value is int && value >= 0 && value < tabs.length) {
                    tabController.animateTo(value);
                    onTap?.call(value);
                  }
                }),
          ),
        );
    return AnimatedBuilder(
        animation: tabController, builder: (context, _) => reactive ? Obx(segments) : segments());
  }
}
