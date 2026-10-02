import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';

class NativeTextField extends TextField {
  const NativeTextField(
      {super.key,
      super.controller,
      super.focusNode,
      super.decoration,
      super.keyboardType,
      super.textInputAction,
      super.textAlign,
      super.style,
      super.autofocus,
      super.obscureText,
      super.maxLines,
      super.minLines,
      super.enabled,
      super.readOnly,
      super.onChanged,
      super.onSubmitted,
      super.onEditingComplete,
      super.onTap,
      super.inputFormatters,
      super.maxLength,
      super.autocorrect,
      super.enableSuggestions});
  @override
  State<TextField> createState() => usesNativeIOS ? _NativeTextFieldState() : super.createState();
}

class _NativeTextFieldState extends State<TextField> {
  TextEditingController? _owned;
  TextEditingController get _controller => widget.controller ?? (_owned ??= TextEditingController());
  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    widget.focusNode?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _owned)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_changed);
      widget.focusNode?.addListener(_changed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration;
    final suffix = decoration?.suffixIcon ?? decoration?.suffix;
    final accessories = (suffix is Row ? suffix.children : [if (suffix != null) suffix])
        .where((widget) => widget is IconButton || widget is InkWell)
        .toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (decoration?.labelText != null) Text(decoration!.labelText!, style: Theme.of(context).textTheme.bodySmall),
      SizedBox(
          height: widget.maxLines == 1 ? 48 : 112,
          child: NativeControl(
              kind: 'textfield',
              ownsDrag: true,
              configuration: {
                'text': _controller.text,
                'placeholder': decoration?.hintText ?? '',
                'secure': widget.obscureText,
                'number': widget.keyboardType == TextInputType.number,
                'email': widget.keyboardType == TextInputType.emailAddress,
                'url': widget.keyboardType == TextInputType.url,
                'enabled': widget.enabled ?? true,
                'readOnly': widget.readOnly,
                'multiline': widget.maxLines != 1,
                'autofocus': widget.autofocus,
                'focus': widget.focusNode?.hasFocus,
                'autocorrect': widget.autocorrect,
                'prefixSymbol': nativeSymbol(decoration?.prefixIcon),
                'accessories': [
                  for (var index = 0; index < accessories.length; index++)
                    {
                      'index': index,
                      'symbol': nativeSymbol(accessories[index] is InkWell
                          ? (accessories[index] as InkWell).child
                          : (accessories[index] as IconButton).icon),
                    }
                ],
              },
              onEvent: (event, value) {
                if (event == 'changed' && value is String) {
                  var editing = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
                  for (final formatter in widget.inputFormatters ?? []) {
                    editing = formatter.formatEditUpdate(_controller.value, editing);
                  }
                  if (widget.maxLength != null && widget.maxLength! > 0 && editing.text.length > widget.maxLength!) {
                    final text = editing.text.substring(0, widget.maxLength!);
                    editing = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
                  }
                  _controller.value = editing;
                  widget.onChanged?.call(editing.text);
                }
                if (event == 'submitted' && value is String) {
                  widget.onEditingComplete?.call();
                  widget.onSubmitted?.call(value);
                }
                if (event == 'focus') {
                  if (value == true) {
                    widget.focusNode?.requestFocus();
                    widget.onTap?.call();
                  } else {
                    widget.focusNode?.unfocus();
                  }
                }
                if (event == 'tap') widget.onTap?.call();
                if (event == 'accessory' && value is int && value >= 0 && value < accessories.length) {
                  final accessory = accessories[value];
                  if (accessory is InkWell) accessory.onTap?.call();
                  if (accessory is IconButton) accessory.onPressed?.call();
                }
              })),
      if (decoration?.errorText != null)
        Text(decoration!.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (decoration?.helperText != null) Text(decoration!.helperText!, style: Theme.of(context).textTheme.bodySmall),
      if (suffix != null && accessories.isEmpty) suffix,
    ]);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    widget.focusNode?.removeListener(_changed);
    _owned?.dispose();
    super.dispose();
  }
}
