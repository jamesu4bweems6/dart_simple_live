import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:remixicon/remixicon.dart';

bool get usesNativeIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class NativeWidgetState<T extends StatefulWidget> extends State<T> {
  final Widget Function(BuildContext, T) builder;
  NativeWidgetState(this.builder);
  @override
  Widget build(BuildContext context) => builder(context, widget);
}

/// Embeds an actual UIKit control, including its input, accessibility and
/// system animations. Flutter only supplies data and receives business events.
class NativeControl extends StatefulWidget {
  final String kind;
  final Map<String, Object?> configuration;
  final void Function(String event, dynamic value)? onEvent;
  final bool ownsDrag;

  const NativeControl(
      {required this.kind, this.configuration = const {}, this.onEvent, this.ownsDrag = false, super.key});

  @override
  State<NativeControl> createState() => _NativeControlState();
}

class _NativeControlState extends State<NativeControl> {
  MethodChannel? _channel;
  Map<String, Object?>? _sent;

  Map<String, Object?> get _configuration => {
        'kind': widget.kind,
        'dark': Theme.of(context).brightness == Brightness.dark,
        'tint': Theme.of(context).colorScheme.primary.toARGB32(),
        ...widget.configuration,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_configure());
  }

  @override
  void didUpdateWidget(covariant NativeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_configure());
  }

  Future<void> _configure() async {
    final channel = _channel;
    if (channel == null || !mounted) return;
    final config = _configuration;
    if (mapEquals(config, _sent)) return;
    _sent = config;
    try {
      await channel.invokeMethod<void>('configure', config);
    } on PlatformException {
      if (mounted) rethrow;
    } on MissingPluginException {
      if (mounted) rethrow;
    }
  }

  void _created(int id) {
    if (!mounted) return;
    _channel = MethodChannel('simple_live/native_control/$id');
    _channel!.setMethodCallHandler((call) async {
      if (!mounted || call.method != 'event') return;
      final event = Map<String, dynamic>.from(call.arguments as Map);
      widget.onEvent?.call(event['name'] as String, event['value']);
    });
    unawaited(_configure());
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
        viewType: 'simple_live/native_control',
        creationParams: _configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _created,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          if (widget.ownsDrag)
            Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)
          else ...{
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()..onTap = () {}),
            Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()..onLongPress = () {}),
            if (widget.kind == 'switch')
              Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()..onUpdate = (_) {}),
          },
        },
      );
}

/// Unwraps an Obx so its current content can be described to UIKit. Callers
/// rebuild inside their own Obx to keep the native control reactive.
Widget? nativeResolve(Widget? widget) => widget is Obx ? nativeResolve(widget.builder()) : widget;

String nativeText(Widget? widget) {
  if (widget is Text) return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  if (widget is SelectableText) return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  if (widget is Row) return widget.children.map(nativeText).where((s) => s.isNotEmpty).join(' ');
  if (widget is Column) return widget.children.map(nativeText).where((s) => s.isNotEmpty).join('\n');
  if (widget is Padding) return nativeText(widget.child);
  if (widget is Center) return nativeText(widget.child);
  if (widget is Container) return nativeText(widget.child);
  if (widget is Expanded) return nativeText(widget.child);
  if (widget is Flexible) return nativeText(widget.child);
  if (widget is SingleChildScrollView) return nativeText(widget.child);
  return '';
}

String? nativeSymbol(Widget? widget) {
  if (widget is Icon) return sfSymbol(widget.icon);
  if (widget is Row) {
    for (final child in widget.children) {
      final result = nativeSymbol(child);
      if (result != null) return result;
    }
  }
  if (widget is ImageIcon && widget.image is AssetImage) {
    final name = (widget.image as AssetImage).assetName;
    return name.contains('setting')
        ? 'text.bubble'
        : name.contains('close')
            ? 'text.bubble.fill'
            : 'text.bubble';
  }
  return null;
}

String sfSymbol(IconData? icon) {
  final symbols = <IconData, String>{
    Icons.arrow_back: 'chevron.left',
    Icons.search: 'magnifyingglass',
    Icons.add: 'plus',
    Icons.remove: 'minus',
    Icons.refresh: 'arrow.clockwise',
    Remix.refresh_line: 'arrow.clockwise',
    Icons.more_horiz: 'ellipsis',
    Icons.delete: 'trash',
    Icons.delete_outline: 'trash',
    Icons.delete_outline_outlined: 'trash',
    Remix.delete_bin_line: 'trash',
    Icons.save: 'square.and.arrow.down',
    Remix.save_2_line: 'square.and.arrow.down',
    Icons.clear_all: 'trash',
    Icons.cloud_upload_outlined: 'icloud.and.arrow.up',
    Icons.cloud_download_outlined: 'icloud.and.arrow.down',
    Icons.cloud_sync_outlined: 'arrow.triangle.2.circlepath.icloud',
    Icons.devices: 'desktopcomputer',
    Icons.edit_outlined: 'pencil',
    Icons.share: 'square.and.arrow.up',
    Icons.share_sharp: 'square.and.arrow.up',
    Remix.share_line: 'square.and.arrow.up',
    Icons.help_outline: 'questionmark.circle',
    Icons.history: 'clock.arrow.circlepath',
    Remix.history_line: 'clock.arrow.circlepath',
    Icons.login: 'person.crop.circle.badge.plus',
    Icons.logout: 'rectangle.portrait.and.arrow.right',
    Icons.open_in_new: 'arrow.up.right.square',
    Icons.open_in_browser: 'safari',
    Icons.public: 'globe',
    Icons.qr_code: 'qrcode',
    Remix.qr_scan_line: 'qrcode.viewfinder',
    Icons.camera_alt_outlined: 'camera',
    Icons.lock: 'lock',
    Icons.lock_outline_rounded: 'lock',
    Icons.lock_open_outlined: 'lock.open',
    Icons.picture_in_picture: 'pip',
    Icons.play_arrow: 'play.fill',
    Icons.play_circle_outline: 'play.circle',
    Remix.play_circle_line: 'play.circle',
    Icons.volume_down: 'speaker.wave.2',
    Icons.visibility: 'eye',
    Icons.visibility_off: 'eye.slash',
    Icons.settings: 'gearshape',
    Icons.settings_backup_restore_outlined: 'arrow.counterclockwise',
    Icons.check: 'checkmark',
    Icons.check_circle_outline_outlined: 'checkmark.circle',
    Icons.cancel: 'xmark.circle',
    Icons.chevron_right: 'chevron.right',
    Icons.expand_more: 'chevron.down',
    Icons.info_outline_rounded: 'info.circle',
    Remix.close_line: 'xmark',
    Remix.heart_line: 'heart',
    Remix.heart_fill: 'heart.fill',
    Remix.home_2_line: 'house',
    Remix.home_smile_line: 'house',
    Remix.account_circle_line: 'person.crop.circle',
    Remix.user_smile_line: 'person.crop.circle',
    Remix.user_settings_line: 'person.crop.circle.badge.checkmark',
    Remix.apps_line: 'square.grid.2x2',
    Remix.moon_line: 'moon',
    Remix.link: 'link',
    Remix.text: 'textformat',
    Remix.timer_2_line: 'timer',
    Remix.timer_line: 'timer',
    Icons.timer_outlined: 'timer',
    Remix.error_warning_line: 'exclamationmark.circle',
    Remix.information_line: 'info.circle',
    Remix.upload_2_line: 'arrow.up.circle',
    Remix.file_copy_line: 'doc.on.doc',
    Remix.clipboard_line: 'clipboard',
    Remix.folder_open_line: 'folder',
    Icons.drive_folder_upload: 'folder.badge.plus',
    Remix.export_line: 'square.and.arrow.up',
    Remix.import_line: 'square.and.arrow.down',
    Remix.trophy_line: 'trophy',
    Remix.price_tag_3_line: 'tag',
    Remix.sort_asc: 'arrow.up.arrow.down',
    Remix.blender_line: 'square.grid.2x2',
    Remix.play_list_2_line: 'list.bullet',
    Remix.fullscreen_line: 'arrow.up.left.and.arrow.down.right',
    Remix.fullscreen_exit_fill: 'arrow.down.right.and.arrow.up.left',
    Remix.shield_keyhole_line: 'checkmark.shield',
    Remix.restart_line: 'arrow.counterclockwise',
    Remix.device_line: 'desktopcomputer',
    Icons.aspect_ratio_outlined: 'aspectratio',
    Icons.switch_video_outlined: 'video',
    Icons.flash_on: 'bolt',
    Icons.account_circle: 'person.crop.circle',
    Icons.account_circle_outlined: 'person.crop.circle',
    Icons.cloud_circle_outlined: 'icloud',
    Icons.copy: 'doc.on.doc',
    Icons.download_outlined: 'arrow.down.circle',
    Icons.flip_camera_android: 'arrow.triangle.2.circlepath.camera',
    Icons.image: 'photo',
    Remix.arrow_right_line: 'arrow.right',
    Remix.dislike_line: 'hand.thumbsdown',
    Remix.file_text_line: 'doc.text',
    Remix.fire_fill: 'flame.fill',
    Remix.tv_2_line: 'tv',
    Remix.github_line: 'chevron.left.forwardslash.chevron.right',
    Remix.apple_line: 'apple.logo',
    Remix.mac_line: 'desktopcomputer',
    Remix.microsoft_fill: 'desktopcomputer',
    Remix.android_line: 'smartphone',
    Remix.ubuntu_line: 'desktopcomputer',
    Remix.xbox_line: 'gamecontroller',
    Remix.chrome_fill: 'globe',
    Remix.tiktok_line: 'music.note',
  };
  return symbols[icon] ?? 'square';
}
