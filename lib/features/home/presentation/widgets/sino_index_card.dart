import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/emoji_box.dart';
import '../../../../core/widgets/pill.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../application/home_today.dart';
import '../../application/sino_index.dart';

const disclaimerUz = 'Shifokor maslahatini almashtirmaydi';

Color levelColor(SinoLevel l) => switch (l) {
  SinoLevel.great => AppColors.good,
  SinoLevel.good => AppColors.primary,
  SinoLevel.fair => AppColors.saffron,
  SinoLevel.low => AppColors.coral,
};

String levelLabel(BuildContext context, SinoLevel l) => switch (l) {
  SinoLevel.great => context.tr(uz: 'A’lo', ru: 'Отлично', en: 'Great'),
  SinoLevel.good => context.tr(uz: 'Yaxshi', ru: 'Хорошо', en: 'Good'),
  SinoLevel.fair => context.tr(uz: 'O‘rtacha', ru: 'Средне', en: 'Fair'),
  SinoLevel.low => context.tr(
    uz: 'Yaxshilash mumkin',
    ru: 'Можно лучше',
    en: 'Room to improve',
  ),
};

String partEmoji(SinoPart p) => switch (p) {
  SinoPart.nutrition => '🥗',
  SinoPart.water => '💧',
  SinoPart.medicines => '💊',
  SinoPart.activity => '🏃',
  SinoPart.sleep => '😴',
};

Color partColor(SinoPart p) => switch (p) {
  SinoPart.nutrition => AppColors.good,
  SinoPart.water => AppColors.sky,
  SinoPart.medicines => AppColors.violet,
  SinoPart.activity => AppColors.saffron,
  SinoPart.sleep => AppColors.secondary,
};

String partLabel(BuildContext context, SinoPart p) => switch (p) {
  SinoPart.nutrition => context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Food'),
  SinoPart.water => context.tr(uz: 'Suv', ru: 'Вода', en: 'Water'),
  SinoPart.medicines => context.tr(
    uz: 'Dorilar',
    ru: 'Лекарства',
    en: 'Medicines',
  ),
  SinoPart.activity => context.tr(
    uz: 'Faollik',
    ru: 'Активность',
    en: 'Activity',
  ),
  SinoPart.sleep => context.tr(uz: 'Uyqu', ru: 'Сон', en: 'Sleep'),
};

/// «1 240 / 2 270 kkal», «5 / 8 stakan», «2 / 2 doza», «7.2 soat».
String partValue(BuildContext context, SinoPartResult r, SinoDayInput input) {
  String n(num v) => groupThousands(v);
  return switch (r.part) {
    SinoPart.nutrition =>
      '${n(r.value)} / ${n(r.target)} ${context.tr(uz: 'kkal', ru: 'ккал', en: 'kcal')}',
    SinoPart.water =>
      '${r.value} / ${r.target} ${context.tr(uz: 'stakan', ru: 'стак.', en: 'glasses')}',
    SinoPart.medicines =>
      '${r.value} / ${r.target} ${context.tr(uz: 'doza', ru: 'доз', en: 'doses')}',
    SinoPart.activity =>
      input.workouts > 0
          ? context.tr(uz: 'Mashg‘ulot ✓', ru: 'Тренировка ✓', en: 'Workout ✓')
          : '${n(r.value)} / ${n(r.target)} ${context.tr(uz: 'qadam', ru: 'шагов', en: 'steps')}',
    SinoPart.sleep =>
      '${(r.value as double).toStringAsFixed(1)} ${context.tr(uz: 'soat', ru: 'ч', en: 'h')}',
  };
}

/// Where to add data for a part.
void openPart(GoRouter router, SinoPart p) => switch (p) {
  SinoPart.nutrition || SinoPart.water => router.go(AppRoutes.nutrition),
  SinoPart.medicines => router.push(AppRoutes.reminders),
  SinoPart.activity => router.go(AppRoutes.workouts),
  SinoPart.sleep => router.push(AppRoutes.vitals),
};

/// Big animated ring of today's Sino index; tap → breakdown.
class SinoIndexCard extends StatelessWidget {
  const SinoIndexCard({super.key, required this.today});

  final SinoDay today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final index = today.index;
    final title = context.tr(
      uz: 'Sino indeksi',
      ru: 'Индекс Sino',
      en: 'Sino index',
    );

    if (index == null) {
      return AppCard(
        key: const ValueKey('sino-index-empty'),
        child: Row(
          children: [
            const AnimatedProgressRing(value: 0, size: 96, label: '–'),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      uz: 'Suv, ovqat yoki uyquni qo‘shing — indeks hisoblanadi.',
                      ru: 'Добавьте воду, еду или сон — индекс посчитается.',
                      en: 'Log water, food or sleep to get your index.',
                    ),
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => context.go(AppRoutes.nutrition),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final level = SinoLevel.of(index.score);
    return AppCard(
      key: const ValueKey('sino-index-card'),
      onTap: () => showSinoBreakdown(context, today),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedProgressRing(
                key: const ValueKey('sino-index-score'),
                value: index.score / 100,
                size: 128,
                strokeWidth: 13,
                label: '${index.score}',
                caption: context.tr(uz: '100 dan', ru: 'из 100', en: 'of 100'),
                semanticsLabel: title,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 6),
                    Pill(levelLabel(context, level), color: levelColor(level)),
                    const SizedBox(height: 10),
                    for (final r in index.parts.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _MiniBar(result: r),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  disclaimerUz,
                  style: text.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                context.tr(uz: 'Batafsil', ru: 'Подробнее', en: 'Details'),
                style: text.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.result});

  final SinoPartResult result;

  @override
  Widget build(BuildContext context) {
    final color = partColor(result.part);
    return Row(
      children: [
        Text(
          partEmoji(result.part),
          style: const TextStyle(fontSize: 14),
          textScaler: TextScaler.noScaling,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: result.score),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet: every part with its value, points and a way to add data.
Future<void> showSinoBreakdown(BuildContext context, SinoDay today) {
  final index = today.index;
  if (index == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final text = theme.textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheet.tr(
                  uz: 'Indeks qanday hisoblanadi',
                  ru: 'Как считается индекс',
                  en: 'How the index is calculated',
                ),
                style: text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                sheet.tr(
                  uz:
                      'Bugungi ma’lumotlar bo‘yicha. Kun davomida maqsadlar '
                      'asta-sekin oshadi. Ma’lumoti yo‘q qism hisobga olinmaydi.',
                  ru:
                      'По данным за сегодня. Цели растут в течение дня. Части '
                      'без данных не учитываются.',
                  en:
                      'Based on today. Targets grow during the day. Parts '
                      'without data are not counted.',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final p in SinoPart.values)
                _BreakdownRow(
                  part: p,
                  result: index.part(p),
                  input: today.input,
                ),
              const SizedBox(height: 4),
              Text(
                sheet.tr(
                  uz: disclaimerUz,
                  ru: 'Не заменяет консультацию врача',
                  en: 'Does not replace a doctor’s advice',
                ),
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.part,
    required this.result,
    required this.input,
  });

  final SinoPart part;
  final SinoPartResult? result;
  final SinoDayInput input;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final color = partColor(part);
    final r = result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          EmojiBox(emoji: partEmoji(part), color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partLabel(context, part),
                        style: text.titleSmall,
                      ),
                    ),
                    if (r != null)
                      Text(
                        '${r.points.round()} / ${(r.share * 100).round()}',
                        key: ValueKey('points-${part.name}'),
                        style: text.labelLarge,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (r != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: r.score,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(partValue(context, r, input), style: text.bodySmall),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(
                            uz: 'Ma’lumot yo‘q — hisobga olinmadi',
                            ru: 'Нет данных — не учитывается',
                            en: 'No data — not counted',
                          ),
                          style: text.bodySmall,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          openPart(router, part);
                        },
                        child: Text(
                          context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
