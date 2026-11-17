import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/emoji_box.dart';
import '../application/vitals_providers.dart';
import '../data/models.dart';
import 'labels.dart';

/// Home card: the latest pulse and blood pressure; red when out of range.
class VitalsHomeCard extends ConsumerWidget {
  const VitalsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(vitalsWeekAllProvider);
    void open() => context.push(AppRoutes.vitals);
    final title = context.tr(
      uz: 'Ko‘rsatkichlar',
      ru: 'Показатели',
      en: 'Vitals',
    );
    final list = week.value;
    Vital? latest(VitalKind k) {
      for (final v in list ?? const <Vital>[]) {
        if (v.kind == k) return v;
      }
      return null;
    }

    final pulse = latest(VitalKind.pulse);
    final pressure = latest(VitalKind.pressure);
    if (list == null || (pulse == null && pressure == null)) {
      return ShortcutCard(
        key: const Key('vitals-home-card'),
        emoji: '❤️',
        title: title,
        subtitle: week.hasError
            ? context.tr(
                uz: 'Ma’lumot yuklanmadi — ochib qayta urinib ko‘ring',
                ru: 'Не удалось загрузить — откройте и повторите',
                en: 'Couldn’t load — open to retry',
              )
            : list == null
            ? context.tr(uz: 'Yuklanmoqda…', ru: 'Загрузка…', en: 'Loading…')
            : context.tr(
                uz: 'Bosim, puls, qand — birinchi o‘lchovni kiriting',
                ru: 'Давление, пульс, сахар — внесите первое измерение',
                en: 'Pressure, pulse, glucose — add the first measurement',
              ),
        color: AppColors.coral,
        onTap: open,
      );
    }

    final text = Theme.of(context).textTheme;
    final shown = [?pulse, ?pressure];
    final bad = shown.any((v) => v.status != VitalStatus.normal);
    return AppCard(
      key: const Key('vitals-home-card'),
      onTap: open,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const EmojiBox(emoji: '❤️', color: AppColors.coral),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodySmall),
                Text(
                  [
                    for (final v in shown)
                      '${v.kind.emoji} ${vitalValueText(v)}',
                  ].join('   '),
                  key: const Key('vitals-home-values'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  bad
                      ? context.tr(
                          uz: 'Me’yordan tashqarida — kuzatib boring',
                          ru: 'Вне нормы — понаблюдайте',
                          en: 'Out of range — keep an eye on it',
                        )
                      : context.tr(
                          uz: 'Me’yorda · ${whenText(context, shown.first.measuredAt, DateTime.now())}',
                          ru: 'В норме · ${whenText(context, shown.first.measuredAt, DateTime.now())}',
                          en: 'Normal · ${whenText(context, shown.first.measuredAt, DateTime.now())}',
                        ),
                  style: text.bodySmall?.copyWith(
                    color: bad ? AppColors.danger : null,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
