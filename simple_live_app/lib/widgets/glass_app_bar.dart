import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/widgets/native_ios/native_control.dart';

/// On iOS this is a real UINavigationBar with UIBarButtonItems. Other platforms
/// continue to use Flutter's AppBar. No full-width glass backdrop is installed.
class GlassAppBar extends AppBar {
  GlassAppBar(
      {super.key,
      super.title,
      super.leading,
      super.actions,
      super.bottom,
      super.automaticallyImplyLeading,
      super.centerTitle,
      super.titleSpacing,
      super.toolbarHeight})
      : super(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent);

  @override
  State<AppBar> createState() => usesNativeIOS
      ? NativeWidgetState<AppBar>((context, bar) => _NativeNavigationBar(bar: bar as GlassAppBar))
      : super.createState();
}

Widget? _resolve(Widget? widget) => widget is Obx ? _resolve(widget.builder()) : widget;
bool _reactive(Widget? widget) {
  if (widget is Obx) return true;
  if (widget is Visibility) return _reactive(widget.child);
  if (widget is TextField) return _reactive(widget.decoration?.prefixIcon);
  if (widget is Row) return widget.children.any(_reactive);
  if (widget is TabBar) return widget.tabs.any((tab) => _reactive(tab is Tab ? tab.child : tab));
  return false;
}

class _NativeNavigationBar extends StatefulWidget {
  final GlassAppBar bar;
  const _NativeNavigationBar({required this.bar});
  @override
  State<_NativeNavigationBar> createState() => _NativeNavigationBarState();
}

class _NativeNavigationBarState extends State<_NativeNavigationBar> {
  final Map<String, VoidCallback> _actions = {};
  final Set<Listenable> _listeners = {};
  TabBar? _tabs;
  TextField? _search;
  DropdownButton<dynamic>? _scope;

  void _changed() {
    if (mounted) setState(() {});
  }

  void _listen(Listenable? value) {
    if (value != null && _listeners.add(value)) value.addListener(_changed);
  }

  Map<String, Object?>? _button(Widget? original) {
    final widget = _resolve(original);
    if (widget is Visibility) return widget.visible ? _button(widget.child) : null;
    if (widget is IconButton) {
      final id = 'action:${_actions.length}';
      if (widget.onPressed != null) _actions[id] = widget.onPressed!;
      return {
        'id': id,
        'symbol': nativeSymbol(widget.icon),
        'enabled': widget.onPressed != null,
        'loading': widget.icon is SizedBox,
        'accessibilityLabel': widget.tooltip
      };
    }
    if (widget is ButtonStyleButton) {
      final id = 'action:${_actions.length}';
      if (widget.onPressed != null) _actions[id] = widget.onPressed!;
      return {
        'id': id,
        'title': nativeText(widget.child),
        'symbol': nativeSymbol(widget.child),
        'enabled': widget.onPressed != null
      };
    }
    if (widget is PopupMenuButton) {
      final entries = widget.itemBuilder(context);
      return {
        'symbol': nativeSymbol(widget.icon) ?? 'ellipsis',
        'menu': [
          for (final entry in entries)
            if (entry is PopupMenuItem) _menuEntry(widget, entry),
        ]
      };
    }
    return null;
  }

  Map<String, Object?> _menuEntry(PopupMenuButton menu, PopupMenuItem entry) {
    final id = 'action:${_actions.length}';
    _actions[id] = () {
      entry.onTap?.call();
      final Function? selected = (menu as dynamic).onSelected;
      selected?.call(entry.value);
    };
    return {'id': id, 'title': nativeText(entry.child), 'symbol': nativeSymbol(entry.child), 'enabled': entry.enabled};
  }

  Map<String, Object?> _tabConfiguration(TabBar tabs) {
    _tabs = tabs;
    final controller = tabs.controller ?? DefaultTabController.of(context);
    _listen(controller);
    return {
      'titles': tabs.tabs
          .map((tab) => tab is Tab ? tab.text ?? nativeText(_resolve(tab.child)) : nativeText(_resolve(tab)))
          .toList(),
      'selected': controller.index
    };
  }

  void _findSearchPrefix(Widget? original) {
    final child = _resolve(original);
    if (child is Row) {
      for (final item in child.children) {
        _findSearchPrefix(item);
      }
    }
    if (child is DropdownButton) _scope = child;
  }

  @override
  Widget build(BuildContext context) {
    final bar = widget.bar;
    return _reactive(bar.title) ||
            _reactive(bar.leading) ||
            _reactive(bar.bottom) ||
            (bar.actions ?? []).any(_reactive)
        ? Obx(() => _render(context))
        : _render(context);
  }

  Widget _render(BuildContext context) {
    // Rebind when a page changes its controller; never retain disposed listeners.
    for (final value in _listeners) {
      value.removeListener(_changed);
    }
    _listeners.clear();
    _actions.clear();
    _tabs = null;
    _search = null;
    _scope = null;
    final bar = widget.bar;
    final title = _resolve(bar.title);
    final config = <String, Object?>{
      'title': nativeText(title),
      'back': bar.automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false),
      'actions': (bar.actions ?? []).map(_button).whereType<Map<String, Object?>>().toList(),
    };
    final leading = _button(bar.leading);
    if (leading != null) {
      config['leading'] = leading;
      config['back'] = false;
    }
    if (title is TabBar) config['titleTabs'] = _tabConfiguration(title);
    if (bar.bottom is TabBar) config['bottomTabs'] = _tabConfiguration(bar.bottom as TabBar);
    if (title is TextField) {
      _search = title;
      _listen(title.controller);
      _findSearchPrefix(title.decoration?.prefixIcon);
      config['back'] = true;
      config['search'] = {
        'text': title.controller?.text ?? '',
        'placeholder': title.decoration?.hintText ?? '',
        'autofocus': title.autofocus,
        if (_scope != null) 'scopes': _scope!.items!.map((item) => nativeText(item.child)).toList(),
        if (_scope != null) 'scope': _scope!.items!.indexWhere((item) => item.value == _scope!.value),
      };
    }
    return SafeArea(
        bottom: false,
        child: SizedBox(
          height: bar.preferredSize.height,
          child: NativeControl(
              kind: 'navigation',
              ownsDrag: true,
              configuration: config,
              onEvent: (event, value) {
                if (event == 'action' && value == 'back') {
                  Navigator.of(context).maybePop();
                  return;
                }
                if (event == 'action' && value is String && value.startsWith('scope:')) {
                  final index = int.tryParse(value.substring(6));
                  if (index != null && _scope != null && index >= 0 && index < _scope!.items!.length) {
                    final Function? changed = (_scope as dynamic).onChanged;
                    changed?.call(_scope!.items![index].value);
                  }
                } else if (event == 'action') {
                  _actions[value]?.call();
                }
                if (event == 'selected' && value is int && _tabs != null) {
                  final controller = _tabs!.controller ?? DefaultTabController.of(context);
                  if (value >= 0 && value < controller.length) {
                    controller.animateTo(value);
                    _tabs!.onTap?.call(value);
                  }
                }
                if (event == 'searchChanged' && value is String) {
                  _search?.controller?.text = value;
                  _search?.onChanged?.call(value);
                }
                if (event == 'searchSubmitted' && value is String) _search?.onSubmitted?.call(value);
              }),
        ));
  }

  @override
  void dispose() {
    for (final value in _listeners) {
      value.removeListener(_changed);
    }
    super.dispose();
  }
}
