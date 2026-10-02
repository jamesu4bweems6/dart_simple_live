import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  bool useSafeArea = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      constraints: constraints ?? const BoxConstraints(maxWidth: 640),
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, MediaQuery.viewInsetsOf(context).bottom),
        child: LiquidGlassSurface(
          radius: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(65),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      ),
    );
