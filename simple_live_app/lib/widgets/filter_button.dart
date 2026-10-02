import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class FilterButton extends StatelessWidget {
  final bool selected;
  final String text;
  final VoidCallback? onTap;
  const FilterButton({this.selected = false, required this.text, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? colors.primary.withAlpha(28) : colors.onSurface.withAlpha(10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? colors.primary.withAlpha(40) : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(text,
                style: TextStyle(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
          ),
        ),
      ),
    );
  }
}
