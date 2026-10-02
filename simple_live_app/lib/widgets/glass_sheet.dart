import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';
import 'package:simple_live_app/widgets/native_ios/native_presentation.dart';

Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  bool useSafeArea = true,
}) {
  if (usesNativeIOS) {
    final body = builder(context);
    final snapshot = NativeModalContent(context)..collect(body);
    if (snapshot.supported) {
      return showGeneralDialog<T>(
          context: context,
          barrierColor: Colors.transparent,
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => NativeModal(style: 'sheet', content: body));
    }
  }
  return showModalBottomSheet<T>(
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
}
