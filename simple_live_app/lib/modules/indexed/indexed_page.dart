import 'indexed_controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/widgets/liquid_glass_dock.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final nativeDock = LiquidGlassDock.usesNativeDock;
        final showDock = nativeDock || orientation == Orientation.portrait;
        final dockInset = showDock
            ? nativeDock
                ? LiquidGlassDock.nativeHeight + MediaQuery.of(context).viewPadding.bottom
                : LiquidGlassDock.height + LiquidGlassDock.verticalMargin * 2 + MediaQuery.of(context).padding.bottom
            : 0.0;
        return Scaffold(
          extendBody: showDock,
          body: Row(
            children: [
              Visibility(
                visible: !showDock,
                child: Obx(
                  () => Padding(
                    padding: const EdgeInsets.all(12),
                    child: LiquidGlassSurface(
                      child: NavigationRail(
                        selectedIndex: controller.index.value,
                        onDestinationSelected: controller.setIndex,
                        labelType: NavigationRailLabelType.none,
                        destinations: controller.items
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.iconData),
                                label: Text(item.title),
                                padding: AppStyle.edgeInsetsV8,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: !showDock
                            ? BorderSide(
                                color: Colors.grey.withAlpha(50),
                                width: 1,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: DockContentInset(
                      bottom: dockInset,
                      child: IndexedStack(
                        index: controller.index.value,
                        children: controller.pages,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: showDock
              ? Obx(
                  () => LiquidGlassDock(
                    items: controller.items.toList(),
                    selectedIndex: controller.index.value,
                    onSelected: controller.setIndex,
                  ),
                )
              : null,
        );
      },
    );
  }
}
