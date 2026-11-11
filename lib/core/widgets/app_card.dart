import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'emoji_box.dart';

/// Rounded (20) card with optional tap.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppColors.cardRadius);
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Standard shortcut card for home: emoji + title + subtitle + chevron.
class ShortcutCard extends StatelessWidget {
  const ShortcutCard({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.color = AppColors.primary,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          EmojiBox(emoji: emoji, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (subtitle != null) Text(subtitle!, style: text.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
