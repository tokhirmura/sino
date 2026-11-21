import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../application/family_care.dart';
import 'family_screen.dart' show familySummaryText;
import 'labels.dart';

/// Home card «Oila»: «3 kishidan 2 nafari dorini ichdi» and, in red, who
/// missed a dose. Tap → `/family`.
class FamilyHomeCard extends ConsumerWidget {
  const FamilyHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(familySummaryProvider).value;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final missed = summary?.missed ?? const [];
    final alarm = missed.isNotEmpty;
    final ink = AppColors.readable(AppColors.garnet, theme.brightness);

    final subtitle = summary == null
        ? null
        : summary.members == 0
        ? context.tr(
            uz: 'Yaqinlaringizni qo‘shing — dorilarini kuzating',
            ru: 'Добавьте близких — следите за их лекарствами',
            en: 'Add your family — keep an eye on their medicines',
          )
        : familySummaryText(context, summary);

    return AppCard(
      key: const ValueKey('family-home-card'),
      onTap: () => context.push(AppRoutes.family),
      child: Row(
        children: [
          EmojiBox(
            emoji: '👨‍👩‍👧',
            color: alarm ? AppColors.garnet : AppColors.violet,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(uz: 'Oila', ru: 'Семья', en: 'Family'),
                  style: text.titleMedium,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    key: const ValueKey('family-summary'),
                    style: text.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                for (final c in missed)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '⚠️ ${missedText(context, c.member)}',
                      style: text.bodyMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
