import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';

/// Retains Flutter's dialog semantics, focus, overflow and keyboard insets.
/// Only the material behind the dialog content is replaced.
Widget _withGlass(Widget built) {
  if (built is! Dialog) return built;
  return Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: built.insetPadding,
    alignment: built.alignment,
    constraints: built.constraints,
    semanticsRole: built.semanticsRole,
    child: LiquidGlassSurface(radius: 32, child: built.child ?? const SizedBox.shrink()),
  );
}

class GlassAlertDialog extends AlertDialog {
  const GlassAlertDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.contentPadding,
    super.titlePadding,
    super.actionsPadding,
    super.scrollable,
    super.shape,
    super.insetPadding,
  });

  @override
  Widget build(BuildContext context) => _withGlass(super.build(context));
}

class GlassSimpleDialog extends SimpleDialog {
  const GlassSimpleDialog({super.key, super.title, super.children, super.contentPadding});

  @override
  Widget build(BuildContext context) => _withGlass(super.build(context));
}
