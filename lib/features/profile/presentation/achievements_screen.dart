import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data/achievements.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// `/profile/achievements`: all 8 badges — unlocked ones with the date,
/// locked ones grey; tap → how to earn it.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(achievementsProvider);
    final count = value.value?.length;
    return AppScaffold(
      title: context.tr(uz: 'Yutuqlar', ru: 'Достижения', en: 'Badges'),
      subtitle: count == null
          ? null
          : context.tr(
              uz: '$count / ${Achievement.values.length} ochildi',
              ru: 'Открыто $count из ${Achievement.values.length}',
              en: '$count of ${Achievement.values.length} unlocked',
            ),
      body: AsyncValueView(
        value: value,
        onRetry: () => ref.invalidate(achievementsProvider),
        loading: () => const SkeletonLoader(count: 6, kind: SkeletonKind.grid),
        data: (unlocked) => ListView(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 24),
          children: [
            _ProgressCard(unlocked: unlocked.length),
            const SizedBox(height: AppSpacing.cardGap),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                runSpacing: 8,
                children: [
                  for (final a in _ordered(unlocked))
                    AchievementBadge(
                      key: ValueKey('badge-${a.code}'),
                      emoji: a.emoji,
                      title: a.title(context.lang),
                      subtitle: unlocked[a] == null
                          ? null
                          : _date(context, unlocked[a]!),
                      unlocked: unlocked.containsKey(a),
                      onTap: () => _showBadge(context, a, unlocked[a]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unlocked first (newest first), then locked in their natural order.
  static List<Achievement> _ordered(Map<Achievement, DateTime> unlocked) => [
    ...unlocked.keys.toList()
      ..sort((a, b) => unlocked[b]!.compareTo(unlocked[a]!)),
    for (final a in Achievement.values)
      if (!unlocked.containsKey(a)) a,
  ];
}

String _date(BuildContext context, DateTime d) =>
    DateFormat('d MMM', Localizations.localeOf(context).toString()).format(d);

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.unlocked});

  final int unlocked;

  @override
  Widget build(BuildContext context) {
    final total = Achievement.values.length;
    final text = Theme.of(context).textTheme;
    final left = total - unlocked;
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            value: unlocked / total,
            size: 72,
            strokeWidth: 9,
            color: AppColors.saffron,
            child: Text(
              '$unlocked/$total',
              key: const ValueKey('badges-count'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left == 0
                      ? context.tr(
                          uz: 'Hammasi ochildi! 🏆',
                          ru: 'Открыто всё! 🏆',
                          en: 'All unlocked! 🏆',
                        )
                      : context.tr(
                          uz: 'Yana $left ta yutuq qoldi',
                          ru: 'Осталось достижений: $left',
                          en: '$left more to go',
                        ),
                  style: text.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    uz:
                        'Yutuqlar har kuni Sino indeksi bilan birga '
                        'tekshiriladi. Yopiq yutuqqa bosing — qanday '
                        'olishni ko‘rasiz.',
                    ru:
                        'Достижения проверяются каждый день вместе с индексом '
                        'Sino. Нажмите на закрытое — увидите, как его получить.',
                    en:
                        'Badges are checked every day along with the Sino '
                        'index. Tap a locked one to see how to earn it.',
                  ),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showBadge(BuildContext context, Achievement a, DateTime? at) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AchievementBadge(
                emoji: a.emoji,
                title: a.title(context.lang),
                unlocked: at != null,
                size: 96,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                a.hint(context.lang),
                key: const ValueKey('badge-hint'),
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                at == null
                    ? context.tr(
                        uz: 'Hali ochilmagan',
                        ru: 'Ещё не открыто',
                        en: 'Not unlocked yet',
                      )
                    : context.tr(
                        uz: 'Ochilgan: ${_date(context, at)}',
                        ru: 'Открыто: ${_date(context, at)}',
                        en: 'Unlocked: ${_date(context, at)}',
                      ),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
