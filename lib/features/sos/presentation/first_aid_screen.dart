import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../data/first_aid.dart';
import 'sos_screen.dart';

/// One first-aid guide: when, numbered steps, a 103 button on top.
class FirstAidScreen extends ConsumerWidget {
  const FirstAidScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(firstAidProvider);
    final fallbackTitle = context.tr(
      uz: 'Birinchi yordam',
      ru: 'Первая помощь',
      en: 'First aid',
    );
    return guides.when(
      loading: () => AppScaffold(
        title: fallbackTitle,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: fallbackTitle,
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(firstAidProvider),
        ),
      ),
      data: (list) {
        final g = list.where((g) => g.id == id).firstOrNull;
        if (g == null) {
          return AppScaffold(
            title: fallbackTitle,
            body: EmptyState(
              emoji: '🔍',
              title: context.tr(
                uz: 'Topilmadi',
                ru: 'Не найдено',
                en: 'Not found',
              ),
            ),
          );
        }
        final text = Theme.of(context).textTheme;
        final steps = g.stepsFor(context.lang.name);
        return AppScaffold(
          title: context.trMap(g.title),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              AppCard(
                color: AppColors.danger.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Text(g.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.trMap(g.when),
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => callNumber(context, ref, '103'),
                icon: const Icon(Icons.call),
                label: Text(
                  context.tr(
                    uz: '103 — Tez yordam',
                    ru: '103 — Скорая помощь',
                    en: '103 — Ambulance',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final (i, step) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(step, style: text.bodyLarge),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  uz: 'Shifokor maslahatini almashtirmaydi.',
                  ru: 'Не заменяет консультацию врача.',
                  en: 'Does not replace a doctor’s advice.',
                ),
                style: text.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
