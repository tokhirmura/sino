import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small rounded label, e.g. «Retsept», «24/7», «Online».
///
/// The text color is derived from [color] so it stays readable in both
/// themes (bright brand colors are darkened on light backgrounds).
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = AppColors.primary,
    this.icon,
    this.wrap = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Let a long label wrap onto more lines. Only where the width is
  /// bounded (not inside a bare `Row`).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink = AppColors.readable(color, brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 4),
          ],
          if (wrap) Flexible(child: _text(ink)) else _text(ink),
        ],
      ),
    );
  }

  Widget _text(Color ink) => Text(
    label,
    style: TextStyle(
      color: ink,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
  );
}
