import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Glass belongs to the control layer. Scrolling content uses [GlassCard]
/// instead, avoiding a platform view and a blur pass for every list item.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool dark;

  const LiquidGlassSurface({
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.dark = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = dark || Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final tint = isDark ? const Color(0xFF242428) : const Color(0xFFF9F9FC);
    final borderRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                    ? _NativeGlass(dark: isDark, radius: radius, highContrast: highContrast)
                    : BackdropFilter(
                        enabled: !highContrast,
                        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tint.withAlpha(highContrast ? 255 : (isDark ? 210 : 195)),
                            borderRadius: borderRadius,
                            border: Border.all(color: Colors.white.withAlpha(isDark ? 30 : 160), width: 0.75),
                            gradient: highContrast
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white.withAlpha(isDark ? 24 : 100), tint.withAlpha(130)],
                                  ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class _NativeGlass extends StatefulWidget {
  final bool dark;
  final double radius;
  final bool highContrast;

  const _NativeGlass({required this.dark, required this.radius, required this.highContrast});

  @override
  State<_NativeGlass> createState() => _NativeGlassState();
}

class _NativeGlassState extends State<_NativeGlass> {
  MethodChannel? _channel;

  Map<String, Object> get _configuration => {
        'dark': widget.dark,
        'radius': widget.radius,
        'highContrast': widget.highContrast,
      };

  @override
  void didUpdateWidget(covariant _NativeGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark ||
        oldWidget.radius != widget.radius ||
        oldWidget.highContrast != widget.highContrast) {
      _configure();
    }
  }

  Future<void> _configure() async {
    try {
      await _channel?.invokeMethod<void>('configure', _configuration);
    } on PlatformException catch (error) {
      // A route can dispose its platform view while an appearance update is in flight.
      if (mounted) FlutterError.reportError(FlutterErrorDetails(exception: error));
    }
  }

  @override
  Widget build(BuildContext context) => UiKitView(
        viewType: 'simple_live/native_liquid_glass_surface',
        creationParams: _configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          if (!mounted) return;
          _channel = MethodChannel('simple_live/native_glass/$id');
          _configure();
        },
      );
}

/// Quiet, legible content material for grouped settings and image cards.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({required this.child, this.radius = 24, this.onTap, this.onLongPress, super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(10), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
    );
  }
}
