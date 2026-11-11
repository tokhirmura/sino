import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Emoji on a soft tinted rounded square.
class EmojiBox extends StatelessWidget {
  const EmojiBox({
    super.key,
    required this.emoji,
    this.color = AppColors.primary,
    this.size = 48,
  });

  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
