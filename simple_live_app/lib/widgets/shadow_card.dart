import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

class ShadowCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const ShadowCard({required this.child, this.radius = 24, this.onTap, this.onLongPress, super.key});

  @override
  Widget build(BuildContext context) => GlassCard(
        radius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      );
}
