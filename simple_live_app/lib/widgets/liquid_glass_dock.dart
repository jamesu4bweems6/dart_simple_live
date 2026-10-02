import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_live_app/app/constant.dart';

/// Scrollable content reserves this space while painting behind the dock.
class DockContentInset extends InheritedWidget {
  final double bottom;

  const DockContentInset({
    required this.bottom,
    required super.child,
    super.key,
  });

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DockContentInset>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(DockContentInset oldWidget) => bottom != oldWidget.bottom;
}

class LiquidGlassDock extends StatelessWidget {
  static const double height = 68;
  static const double verticalMargin = 12;

  final List<HomePageItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const LiquidGlassDock({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final dark = theme.brightness == Brightness.dark;
    final duration = media.disableAnimations ? Duration.zero : const Duration(milliseconds: 300);
    final radius = BorderRadius.circular(height / 2);
    final tint = dark ? const Color(0xFF20232C) : const Color(0xFFF8FAFF);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: verticalMargin),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(dark ? 70 : 28),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  enabled: !media.highContrast,
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      color: tint.withAlpha(media.highContrast ? 255 : (dark ? 185 : 158)),
                      gradient: media.highContrast
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withAlpha(dark ? 24 : 100),
                                tint.withAlpha(dark ? 180 : 105),
                                Colors.white.withAlpha(dark ? 10 : 45),
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                    ),
                    child: CustomPaint(
                      foregroundPainter: _GlassRimPainter(dark: dark),
                      child: SizedBox(
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final itemWidth = constraints.maxWidth / items.length;
                              return Stack(
                                children: [
                                  AnimatedPositionedDirectional(
                                    duration: duration,
                                    curve: Curves.easeOutCubic,
                                    start: selectedIndex * itemWidth,
                                    top: 0,
                                    bottom: 0,
                                    width: itemWidth,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        color: theme.colorScheme.primary.withAlpha(dark ? 45 : 22),
                                        border: Border.all(
                                          color: Colors.white.withAlpha(dark ? 35 : 120),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    type: MaterialType.transparency,
                                    child: Row(
                                      children: List.generate(items.length, (index) {
                                        final item = items[index];
                                        final selected = selectedIndex == index;
                                        final color = selected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface.withAlpha(dark ? 220 : 195);
                                        return Expanded(
                                          child: Semantics(
                                            label: item.title,
                                            button: true,
                                            selected: selected,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(28),
                                              onTap: () {
                                                if (!selected) HapticFeedback.selectionClick();
                                                onSelected(index);
                                              },
                                              child: ExcludeSemantics(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    AnimatedScale(
                                                      scale: selected ? 1.08 : 1,
                                                      duration: duration,
                                                      curve: Curves.easeOutCubic,
                                                      child: Icon(item.iconData, size: 24, color: color),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      item.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        height: 1.2,
                                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  final bool dark;

  const _GlassRimPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(dark ? 120 : 235),
          Colors.white.withAlpha(dark ? 12 : 45),
          Colors.white.withAlpha(dark ? 55 : 150),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)), paint);
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) => oldDelegate.dark != dark;
}
