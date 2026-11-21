import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'motion.dart';

/// Main call-to-action: turquoise → lapis gradient, white bold label,
/// soft glow and a spring when pressed. Use one per screen, for the most
/// important action (save, book, start). Secondary actions —
/// `OutlinedButton` / `TextButton`.
///
/// ```dart
/// PrimaryButton(
///   label: context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save'),
///   icon: Icons.check_rounded,
///   loading: saving,
///   onPressed: save,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.gradient,
    this.height = 56,
  });

  final String label;

  /// null — disabled.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Full width (default) or as wide as the content.
  final bool expand;

  /// Defaults to the brand gradient; e.g. `AppColors.saffronGradient`.
  final Gradient? gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null && !loading;
    final g = gradient ?? AppColors.brand(theme.brightness);
    final radius = BorderRadius.circular(AppRadius.button);
    final fg = onPressed == null
        ? scheme.onSurface.withValues(alpha: 0.38)
        : Colors.white;

    final content = loading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

    final button = Semantics(
      button: true,
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: onPressed == null ? null : g,
          color: onPressed == null
              ? scheme.onSurface.withValues(alpha: 0.1)
              : null,
          boxShadow: enabled ? AppShadows.glow(AppColors.secondary) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: SizedBox(
              height: height,
              width: expand ? double.infinity : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
    return Pressable(enabled: enabled, scale: 0.96, child: button);
  }
}
