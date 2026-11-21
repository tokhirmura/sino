import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'girih_pattern.dart';

/// Turquoise → lapis background with the girih ornament and rounded
/// bottom corners. Base of [GradientHeader] and the [AppScaffold] app bar.
class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({
    super.key,
    this.child,
    this.gradient,
    this.bottomRadius = 28,
    this.ornament = true,
  });

  final Widget? child;

  /// Defaults to [AppColors.brand] for the current theme.
  final Gradient? gradient;
  final double bottomRadius;
  final bool ornament;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(bottomRadius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.brand(brightness),
        ),
        child: Stack(
          children: [
            if (ornament) const Positioned.fill(child: GirihPattern()),
            // Soft light from the top-right corner.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, -1),
                    radius: 1.1,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

/// Hero header: gradient + girih ornament, big white title, optional
/// subtitle, trailing widget (avatar, button) and bottom content.
///
/// ```dart
/// GradientHeader(
///   title: 'Salom, Aziz',
///   subtitle: 'Payshanba, 20-noyabr',
///   trailing: CircleAvatar(…),
///   child: Row(children: [StatTile(…), StatTile(…)]),
/// )
/// ```
///
/// Put it at the top of a scrolling page; it adds the status-bar inset
/// itself when [safeTop] is true.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.child,
    this.gradient,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.safeTop = true,
    this.bottomRadius = 28,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Extra content under the title (stats, search field, chips).
  final Widget? child;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final bool safeTop;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = safeTop ? MediaQuery.paddingOf(context).top : 0.0;
    return GradientBackdrop(
      gradient: gradient,
      bottomRadius: bottomRadius,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Padding(
          padding: padding,
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: text.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: text.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                  if (child != null) ...[const SizedBox(height: 18), child!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
