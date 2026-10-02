import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';
import 'package:simple_live_app/widgets/native_ios/native_rows.dart';

/// A Flutter route keeps existing navigation/results, while UIKit owns the
/// presented controller, its dimming, gestures, controls and accessibility.
class NativeModal extends StatefulWidget {
  final String style;
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  const NativeModal({required this.style, this.title, this.content, this.actions = const [], super.key});
  @override
  State<NativeModal> createState() => _NativeModalState();
}

class _NativeModalState extends State<NativeModal> {
  static const _channel = MethodChannel('simple_live/native_presentations');
  static final Map<int, _NativeModalState> _instances = {};
  static int _nextId = 0;
  late final int _id = ++_nextId;
  NativeModalContent? _content;
  bool _disposed = false;
  final _revision = 0.obs;

  @override
  void initState() {
    super.initState();
    _instances[_id] = this;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return;
      final event = Map<String, dynamic>.from(call.arguments as Map);
      _instances[event['id']]?._event(event);
    });
  }

  void _event(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['key'] == 'dismiss') {
      if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
      return;
    }
    final fields = event['fields'] as List?;
    if (fields != null) {
      for (var i = 0; i < fields.length && i < (_content?.fields.length ?? 0); i++) {
        _content!.fields[i].controller?.text = fields[i] as String;
      }
    }
    _content?.callbacks[event['key']]?.call(event['value']);
    // A validator may keep an alert route open. Re-present it with entered text.
    if (widget.style == 'alert') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        // Static forms and reactive settings share the same presentation path.
        _revision.value;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final snapshot = NativeModalContent(context)..collect(widget.content);
        for (final action in widget.actions) {
          snapshot.collectAction(action);
          if (widget.style == 'sheet') snapshot.collect(action);
        }
        _content = snapshot;
        final config = <String, Object?>{
          'id': _id,
          'style': widget.style,
          'title': nativeText(widget.title),
          'dark': dark,
          'tint': Theme.of(context).colorScheme.primary.toARGB32(),
          'rows': snapshot.rows,
          'message': snapshot.messages.join('\n'),
          'actions': snapshot.actions,
          'fields': snapshot.fields
              .map((field) => {
                    'text': field.controller?.text ?? '',
                    'placeholder': field.decoration?.hintText ?? field.decoration?.labelText ?? '',
                    'secure': field.obscureText,
                    'number': field.keyboardType == TextInputType.number,
                    'readOnly': field.readOnly,
                  })
              .toList(),
        };
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_disposed) unawaited(_channel.invokeMethod<void>('present', config));
        });
        return const SizedBox.shrink();
      });

  @override
  void dispose() {
    _disposed = true;
    _instances.remove(_id);
    unawaited(_channel.invokeMethod<void>('dismiss', {'id': _id}));
    super.dispose();
  }
}

/// Converts supported form content to UIKit data, retaining original callbacks.
/// Complex content such as QR images stays in its existing Flutter route.
class NativeModalContent {
  final BuildContext context;
  final List<Map<String, Object?>> rows = [];
  final List<Map<String, Object?>> actions = [];
  final List<String> messages = [];
  final List<TextField> fields = [];
  final Map<String, void Function(dynamic)> callbacks = {};
  bool supported = true;
  NativeModalContent(this.context);

  String _bind(void Function(dynamic) callback) {
    final key = 'control:${callbacks.length}';
    callbacks[key] = callback;
    return key;
  }

  void collectAction(Widget widget) {
    if (widget is ButtonStyleButton) {
      actions.add({
        'key': _bind((_) => widget.onPressed?.call()),
        'title': nativeText(widget.child),
        'enabled': widget.onPressed != null,
        'cancel': nativeText(widget.child) == '取消'
      });
    } else {
      supported = false;
    }
  }

  void collect(Widget? widget, {dynamic radioValue, ValueChanged<dynamic>? radioChanged, int depth = 0}) {
    if (widget == null || depth > 40) return;
    void visit(Widget? child) => collect(child, radioValue: radioValue, radioChanged: radioChanged, depth: depth + 1);
    if (widget is Obx) {
      visit(widget.builder());
      return;
    }
    if (widget is RadioGroup) {
      collect(widget.child,
          radioValue: widget.groupValue,
          radioChanged: (value) => (widget as dynamic).onChanged(value),
          depth: depth + 1);
      return;
    }
    if (widget is NativeSettingsRow) {
      rows.add({
        'kind': widget.kind,
        'title': widget.title,
        'subtitle': widget.subtitle,
        'detail': widget.detail,
        ...widget.configuration,
        'key': _bind((value) {
          if (widget.kind == 'row') {
            widget.onTap?.call();
          } else {
            widget.onChanged?.call(value);
          }
        })
      });
      return;
    }
    if (widget is RadioListTile) {
      rows.add({
        'kind': 'radio',
        'title': nativeText(widget.title),
        'subtitle': nativeText(widget.subtitle),
        'selected': radioValue == widget.value,
        'key': _bind((_) => radioChanged?.call(widget.value))
      });
      return;
    }
    if (widget is CheckboxListTile) {
      rows.add({
        'kind': 'check',
        'title': nativeText(widget.title),
        'value': widget.value,
        'key': _bind((value) => widget.onChanged?.call(value as bool))
      });
      return;
    }
    if (widget is SwitchListTile) {
      rows.add({
        'kind': 'switch',
        'title': nativeText(widget.title),
        'subtitle': nativeText(widget.subtitle),
        'value': widget.value,
        'key': _bind((value) => widget.onChanged?.call(value as bool))
      });
      return;
    }
    if (widget is ListTile) {
      rows.add({
        'kind': 'row',
        'title': nativeText(widget.title),
        'subtitle': nativeText(widget.subtitle),
        'detail': nativeText(widget.trailing),
        'symbol': nativeSymbol(widget.leading),
        'disclosure': widget.onTap != null,
        'key': _bind((_) => widget.onTap?.call())
      });
      return;
    }
    if (widget is Slider) {
      rows.add({
        'kind': 'slider',
        'min': widget.min,
        'max': widget.max,
        'value': widget.value,
        'divisions': widget.divisions,
        'key': _bind((value) => widget.onChanged?.call((value as num).toDouble()))
      });
      return;
    }
    if (widget is TextField) {
      fields.add(widget);
      rows.add({
        'kind': 'textfield',
        'text': widget.controller?.text ?? '',
        'title': widget.decoration?.labelText ?? widget.decoration?.hintText ?? '',
        'secure': widget.obscureText,
        'multiline': widget.maxLines != 1,
        'readOnly': widget.readOnly,
        'enabled': widget.enabled ?? true,
        'key': _bind((value) {
          widget.controller?.text = value as String;
          widget.onChanged?.call(value);
        })
      });
      return;
    }
    if (widget is ButtonStyleButton) {
      rows.add({
        'kind': 'button',
        'title': nativeText(widget.child),
        'enabled': widget.onPressed != null,
        'key': _bind((_) => widget.onPressed?.call())
      });
      return;
    }
    if (widget is IconButton) {
      rows.add({
        'kind': 'button',
        'title': widget.tooltip ?? '关闭',
        'symbol': nativeSymbol(widget.icon),
        'key': _bind((_) => widget.onPressed?.call())
      });
      return;
    }
    if (widget is Text || widget is SelectableText) {
      final text = nativeText(widget);
      if (text.isNotEmpty) {
        messages.add(text);
        rows.add({'kind': 'text', 'title': text});
      }
      return;
    }
    if (widget is Column) {
      widget.children.forEach(visit);
      return;
    }
    if (widget is Row) {
      widget.children.forEach(visit);
      return;
    }
    if (widget is ListBody) {
      widget.children.forEach(visit);
      return;
    }
    if (widget is Padding) {
      visit(widget.child);
      return;
    }
    if (widget is SizedBox) {
      visit(widget.child);
      return;
    }
    if (widget is Container) {
      visit(widget.child);
      return;
    }
    if (widget is Flexible) {
      visit(widget.child);
      return;
    }
    if (widget is SafeArea) {
      visit(widget.child);
      return;
    }
    if (widget is Center) {
      visit(widget.child);
      return;
    }
    if (widget is SingleChildScrollView) {
      visit(widget.child);
      return;
    }
    if (widget is Visibility) {
      if (widget.visible) visit(widget.child);
      return;
    }
    if (widget is Divider || widget is Icon) return;
    if (widget is StatelessWidget) {
      // The descriptor adapter deliberately evaluates pure form widgets here.
      // ignore: invalid_use_of_protected_member
      visit(widget.build(context));
      return;
    }
    supported = false;
  }
}
