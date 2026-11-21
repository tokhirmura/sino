import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/home_today.dart';

/// «Kun hikmati»: Uzbek proverb of the day + translation for ru/en UI.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.quote, required this.lang});

  final DailyQuote quote;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final translation = quote.translation(lang);
    return AppCard(
      key: const ValueKey('quote-card'),
      color: AppColors.saffron.withValues(alpha: isDark ? 0.14 : 0.10),
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💬',
            style: TextStyle(fontSize: 22, height: 1.1),
            textScaler: TextScaler.noScaling,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    uz: 'Kun hikmati',
                    ru: 'Мудрость дня',
                    en: 'Wisdom of the day',
                  ),
                  style: text.labelLarge?.copyWith(
                    color: AppColors.readable(
                      AppColors.saffron,
                      theme.brightness,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '«${quote.uz}»',
                  key: const ValueKey('quote-uz'),
                  style: text.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (translation != null) ...[
                  const SizedBox(height: 4),
                  Text(translation, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
