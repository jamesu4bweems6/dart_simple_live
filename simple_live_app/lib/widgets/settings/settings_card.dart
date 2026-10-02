import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) => GlassCard(child: child);
}
