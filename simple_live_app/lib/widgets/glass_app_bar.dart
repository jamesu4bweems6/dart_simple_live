import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

/// Keeps Flutter navigation, search fields and tab controllers while UIKit
/// supplies the actual iOS 26 material underneath them.
class GlassAppBar extends AppBar {
  GlassAppBar({
    super.key,
    super.title,
    super.leading,
    super.actions,
    super.bottom,
    super.automaticallyImplyLeading,
    super.centerTitle,
    super.titleSpacing,
    super.toolbarHeight,
  }) : super(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: const LiquidGlassSurface(radius: 0, child: SizedBox.expand()),
        );
}
