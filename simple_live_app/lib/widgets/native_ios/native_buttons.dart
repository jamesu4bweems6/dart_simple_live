import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';

Widget nativeButton(BuildContext context,
    {required Widget child,
    required VoidCallback? onPressed,
    Widget? icon,
    String? tooltip,
    ButtonStyle? style,
    bool prominent = false,
    VoidCallback? onLongPress}) {
  // A reactive label such as the player's quality button is an Obx. Describe
  // its current content to UIKit and rebuild when the observed value changes.
  if (child is Obx || icon is Obx) {
    return Obx(() => nativeButton(context,
        child: nativeResolve(child) ?? const SizedBox.shrink(),
        onPressed: onPressed,
        icon: nativeResolve(icon),
        tooltip: tooltip,
        style: style,
        prominent: prominent,
        onLongPress: onLongPress));
  }
  final title = nativeText(child);
  final symbol = nativeSymbol(icon ?? child);
  // An explicit button style wins, then the icon or label's own color (e.g.
  // white text on the dark player bar). A prominent button's content color is
  // chosen against a Flutter fill that UIKit does not draw (white on primary
  // would sit on the pale tinted capsule before iOS 26), so it is ignored.
  final foreground = style?.foregroundColor?.resolve({}) ??
      (prominent ? null : (icon is Icon ? icon.color : null) ?? (child is Text ? child.style?.color : null));
  final fontSize = style?.textStyle?.resolve({})?.fontSize ?? 17;
  final textWidth = TextPainter(
      text: TextSpan(text: title, style: TextStyle(fontSize: fontSize)), textDirection: Directionality.of(context))
    ..layout();
  return SizedBox(
    width: (title.isEmpty ? 48 : textWidth.width + (symbol == null ? 32 : 60)).clamp(48.0, 320.0).toDouble(),
    height: 48,
    child: NativeControl(
        kind: 'button',
        configuration: {
          'title': title,
          'symbol': symbol,
          'enabled': onPressed != null,
          'prominent': prominent,
          'accessibilityLabel': tooltip ?? title,
          if (foreground != null) 'foreground': foreground.toARGB32(),
        },
        onEvent: (event, value) {
          if (event == 'tap') onPressed?.call();
          if (event == 'longPress') onLongPress?.call();
        }),
  );
}

class NativeIconButton extends IconButton {
  const NativeIconButton(
      {super.key,
      required super.onPressed,
      required super.icon,
      super.iconSize,
      super.color,
      super.padding,
      super.constraints,
      super.tooltip,
      super.style,
      super.alignment,
      super.visualDensity,
      super.splashRadius,
      super.focusNode});

  @override
  Widget build(BuildContext context) => usesNativeIOS
      ? nativeButton(context,
          child: const SizedBox.shrink(),
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          style: style ?? (color == null ? null : IconButton.styleFrom(foregroundColor: color)))
      : super.build(context);
}

class NativeTextButton extends TextButton {
  final Widget? nativeIcon;
  final Widget nativeLabel;
  const NativeTextButton(
      {super.key,
      required super.onPressed,
      required Widget child,
      super.style,
      super.onLongPress,
      super.focusNode,
      super.autofocus})
      : nativeIcon = null,
        nativeLabel = child,
        super(child: child);

  NativeTextButton.icon(
      {super.key,
      required super.onPressed,
      required Widget icon,
      required Widget label,
      super.style,
      super.onLongPress,
      super.focusNode,
      super.autofocus})
      : nativeIcon = icon,
        nativeLabel = label,
        super(child: Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 8), label]));

  @override
  State<ButtonStyleButton> createState() => usesNativeIOS
      ? NativeWidgetState<ButtonStyleButton>((context, button) {
          final native = button as NativeTextButton;
          return nativeButton(context,
              child: native.nativeLabel,
              icon: native.nativeIcon,
              onPressed: native.onPressed,
              style: native.style,
              onLongPress: native.onLongPress);
        })
      : super.createState();
}

class NativeElevatedButton extends ElevatedButton {
  final Widget? nativeIcon;
  final Widget nativeLabel;
  const NativeElevatedButton({super.key, required super.onPressed, required Widget child, super.style})
      : nativeIcon = null,
        nativeLabel = child,
        super(child: child);
  NativeElevatedButton.icon(
      {super.key, required super.onPressed, required Widget icon, required Widget label, super.style})
      : nativeIcon = icon,
        nativeLabel = label,
        super(child: Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 8), label]));
  @override
  State<ButtonStyleButton> createState() => usesNativeIOS
      ? NativeWidgetState<ButtonStyleButton>((context, button) {
          final native = button as NativeElevatedButton;
          return nativeButton(context,
              child: native.nativeLabel,
              icon: native.nativeIcon,
              onPressed: native.onPressed,
              style: native.style,
              prominent: true);
        })
      : super.createState();
}

class NativeOutlinedButton extends OutlinedButton {
  const NativeOutlinedButton({super.key, required super.onPressed, required super.child, super.style});
  @override
  State<ButtonStyleButton> createState() => usesNativeIOS
      ? NativeWidgetState<ButtonStyleButton>((context, button) =>
          nativeButton(context, child: button.child!, onPressed: button.onPressed, style: button.style))
      : super.createState();
}
