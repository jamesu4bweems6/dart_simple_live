import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/widgets/liquid_glass_surface.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';
import 'package:simple_live_app/widgets/native_ios/native_presentation.dart';

Future<T?> showGlassDialog<T>(Widget dialog) {
  var native = false;
  if (usesNativeIOS && Get.context != null) {
    final snapshot = NativeModalContent(Get.context!);
    if (dialog is GlassAlertDialog) {
      snapshot.collect(dialog.content);
      for (final action in dialog.actions ?? <Widget>[]) {
        snapshot.collectAction(action);
      }
      native = snapshot.supported;
    } else if (dialog is GlassSimpleDialog) {
      snapshot.collect(Column(children: dialog.children ?? []));
      native = snapshot.supported;
    }
  }
  return Get.dialog<T>(dialog,
      barrierColor: native ? Colors.transparent : null,
      barrierDismissible: !native,
      transitionDuration: native ? Duration.zero : null);
}

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
  Widget build(BuildContext context) {
    if (usesNativeIOS) {
      final snapshot = NativeModalContent(context)..collect(content);
      for (final action in actions ?? <Widget>[]) {
        snapshot.collectAction(action);
      }
      if (snapshot.supported)
        return NativeModal(style: 'alert', title: title, content: content, actions: actions ?? []);
    }
    return _withGlass(super.build(context));
  }
}

class GlassSimpleDialog extends SimpleDialog {
  const GlassSimpleDialog({super.key, super.title, super.children, super.contentPadding});

  @override
  Widget build(BuildContext context) {
    final body = Column(mainAxisSize: MainAxisSize.min, children: children ?? []);
    if (usesNativeIOS) {
      final snapshot = NativeModalContent(context)..collect(body);
      if (snapshot.supported) return NativeModal(style: 'sheet', title: title, content: body);
    }
    return _withGlass(super.build(context));
  }
}
