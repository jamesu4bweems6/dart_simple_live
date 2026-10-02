import 'package:simple_live_app/widgets/native_ios/native_buttons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

class DesktopRefreshButton extends StatelessWidget {
  final bool refreshing;
  final Function()? onPressed;
  const DesktopRefreshButton({required this.refreshing, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: refreshing
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            : NativeIconButton(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh),
              ),
      ),
    );
  }
}
