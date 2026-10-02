import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';

class NativeSettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? detail;
  final Widget? leading;
  final VoidCallback? onTap;
  final String kind;
  final Map<String, Object?> configuration;
  final ValueChanged<dynamic>? onChanged;
  const NativeSettingsRow(
      {required this.title,
      this.subtitle,
      this.detail,
      this.leading,
      this.onTap,
      this.kind = 'row',
      this.configuration = const {},
      this.onChanged,
      super.key});

  @override
  Widget build(BuildContext context) {
    final text = TextPainter(
        text: TextSpan(
            text: [title, subtitle, kind == 'stepper' ? detail : null].whereType<String>().join('\n'),
            style: const TextStyle(fontSize: 16)),
        textDirection: Directionality.of(context))
      ..layout(maxWidth: (MediaQuery.sizeOf(context).width - 160).clamp(120.0, 800.0));
    return SizedBox(
      height: (text.height + 26).clamp(52.0, 180.0),
      child: NativeControl(
          kind: kind,
          configuration: {
            'title': title,
            'subtitle': subtitle,
            'detail': detail,
            'symbol': leading == null ? null : nativeSymbol(leading),
            'displayValue': detail,
            'disclosure': onTap != null,
            ...configuration,
          },
          onEvent: (event, value) {
            if (event == 'tap') {
              onTap?.call();
            } else if (event == 'changed') onChanged?.call(value);
          }),
    );
  }
}

class NativeSlider extends Slider {
  const NativeSlider(
      {super.key,
      required super.value,
      required super.onChanged,
      super.min,
      super.max,
      super.divisions,
      super.label,
      super.onChangeStart,
      super.onChangeEnd,
      super.activeColor,
      super.inactiveColor});
  @override
  State<Slider> createState() => usesNativeIOS
      ? NativeWidgetState<Slider>((context, slider) => (slider as NativeSlider)._buildNative(context))
      : super.createState();

  Widget _buildNative(BuildContext context) => SizedBox(
      height: 44,
      child: NativeControl(
          kind: 'slider',
          ownsDrag: true,
          configuration: {
            'value': value,
            'min': min,
            'max': max,
            'divisions': divisions,
            'enabled': onChanged != null,
          },
          onEvent: (event, value) {
            if (value is! num) return;
            if (event == 'changed') onChanged?.call(value.toDouble());
            if (event == 'started') onChangeStart?.call(value.toDouble());
            if (event == 'ended') onChangeEnd?.call(value.toDouble());
          }));
}

class NativeListTile extends ListTile {
  const NativeListTile(
      {super.key,
      super.title,
      super.subtitle,
      super.leading,
      super.trailing,
      super.onTap,
      super.onLongPress,
      super.visualDensity,
      super.contentPadding,
      super.shape,
      super.dense,
      super.enabled,
      super.selected,
      super.tileColor,
      super.minLeadingWidth,
      super.horizontalTitleGap});
  @override
  Widget build(BuildContext context) {
    bool interactive(Widget? widget) =>
        widget is IconButton || widget is ButtonStyleButton || (widget is Row && widget.children.any(interactive));
    if (!usesNativeIOS ||
        (leading != null && leading is! Icon) ||
        interactive(trailing) ||
        onLongPress != null ||
        nativeText(title).isEmpty) {
      return super.build(context);
    }
    return NativeSettingsRow(
        title: nativeText(title),
        subtitle: nativeText(subtitle),
        detail: nativeText(trailing),
        leading: leading,
        onTap: enabled ? onTap : null);
  }
}

class NativeSwitchListTile extends SwitchListTile {
  const NativeSwitchListTile(
      {super.key,
      required super.value,
      required super.onChanged,
      super.title,
      super.subtitle,
      super.secondary,
      super.contentPadding,
      super.shape,
      super.visualDensity,
      super.dense,
      super.activeColor,
      super.controlAffinity});
  const NativeSwitchListTile.adaptive(
      {super.key,
      required super.value,
      required super.onChanged,
      super.title,
      super.subtitle,
      super.secondary,
      super.contentPadding,
      super.shape,
      super.visualDensity,
      super.dense,
      super.trackOutlineColor})
      : super.adaptive();
  @override
  Widget build(BuildContext context) => usesNativeIOS
      ? NativeSettingsRow(
          title: nativeText(title),
          subtitle: nativeText(subtitle),
          leading: secondary,
          kind: 'switch',
          configuration: {'value': value, 'enabled': onChanged != null},
          onChanged: (value) => onChanged?.call(value as bool))
      : super.build(context);
}

class NativeCheckboxListTile extends CheckboxListTile {
  const NativeCheckboxListTile(
      {super.key,
      required super.value,
      required super.onChanged,
      super.title,
      super.subtitle,
      super.controlAffinity,
      super.contentPadding,
      super.dense,
      super.secondary,
      super.tristate,
      super.visualDensity});
  @override
  Widget build(BuildContext context) => usesNativeIOS
      ? NativeSettingsRow(
          title: nativeText(title),
          subtitle: nativeText(subtitle),
          leading: secondary,
          kind: 'switch',
          configuration: {'value': value ?? false, 'enabled': onChanged != null},
          onChanged: (value) => onChanged?.call(value as bool))
      : super.build(context);
}

class NativeRadioListTile<T> extends RadioListTile<T> {
  const NativeRadioListTile(
      {super.key,
      required super.value,
      super.title,
      super.subtitle,
      super.contentPadding,
      super.dense,
      super.visualDensity,
      super.controlAffinity,
      super.secondary});
  @override
  State<RadioListTile<T>> createState() => usesNativeIOS
      ? NativeWidgetState<RadioListTile<T>>((context, radio) {
          final group = RadioGroup.maybeOf<T>(context);
          return NativeSettingsRow(
              title: nativeText(radio.title),
              subtitle: nativeText(radio.subtitle),
              detail: group?.groupValue == radio.value ? '✓' : null,
              onTap: group == null ? null : () => group.onChanged(radio.value));
        })
      : super.createState();
}
