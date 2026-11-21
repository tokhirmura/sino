import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'primary_button.dart';

/// Empty list / nothing-yet state: big emoji in a soft halo, title,
/// optional message and action.
///
/// Action: either your own [action] widget, or [actionLabel] + [onAction]
/// for a ready gradient [PrimaryButton]:
///
/// ```dart
/// EmptyState(
///   emoji: '💊',
///   title: 'Eslatmalar yo‘q',
///   message: 'Dori ichish vaqtini qo‘shing',
///   actionLabel: 'Qo‘shish',
///   actionIcon: Icons.add_rounded,
///   onAction: () => context.push(…),
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.emoji = '🌿',
    this.message,
    this.action,
    this.color = AppColors.primary,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final String title;
  final String emoji;
  final String? message;
  final Widget? action;
  final Color color;

  /// Label of the built-in [PrimaryButton] (used with [onAction]).
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget halo = Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.30 : 0.20),
            color.withValues(alpha: isDark ? 0.10 : 0.05),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.30 : 0.18),
          width: 1.5,
        ),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 52, height: 1.1),
        textScaler: TextScaler.noScaling,
      ),
    );
    if (!reduceMotion) {
      final inner = halo;
      halo = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(
          scale: 0.7 + 0.3 * v,
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        ),
        child: inner,
      );
    }

    final button =
        action ??
        (actionLabel != null && onAction != null
            ? PrimaryButton(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
                expand: false,
              )
            : null);

    Widget texts = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: text.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (button != null) ...[const SizedBox(height: 24), button],
      ],
    );
    if (!reduceMotion) {
      final inner = texts;
      texts = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - v)),
            child: child,
          ),
        ),
        child: inner,
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [halo, const SizedBox(height: 20), texts],
          ),
        ),
      ),
    );
  }
}
