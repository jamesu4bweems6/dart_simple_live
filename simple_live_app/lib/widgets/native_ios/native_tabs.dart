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

  Widget _buildNative(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);
    return AnimatedBuilder(
        animation: tabController,
        builder: (context, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: NativeControl(
                  kind: 'segments',
                  configuration: {
                    'titles':
                        tabs.map((tab) => tab is Tab ? tab.text ?? nativeText(tab.child) : nativeText(tab)).toList(),
                    'selected': tabController.index,
                  },
                  onEvent: (event, value) {
                    if (event == 'selected' && value is int && value >= 0 && value < tabs.length) {
                      tabController.animateTo(value);
                      onTap?.call(value);
                    }
                  }),
            ));
  }
}
